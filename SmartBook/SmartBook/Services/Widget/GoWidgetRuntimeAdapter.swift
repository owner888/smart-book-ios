import Foundation

protocol WidgetRuntime {
    func create(path: String, onEvent: ((String, String) -> Void)?) throws
    func start(initialScript: String?) throws
    func run(_ script: String) throws -> String
    func on(event: String, payload: String?) throws
    func stop()
    func destroy()
}

enum GoWidgetRuntimeError: LocalizedError {
    case createFailed
    case invalidHandle
    case initFailed(code: Int32)
    case startFailed(code: Int32)
    case stopFailed(code: Int32)
    case onFailed(code: Int32)
    case runReturnedNil

    var errorDescription: String? {
        switch self {
        case .createFailed:
            return "Failed to create Go widget runtime handle"
        case .invalidHandle:
            return "Invalid Go widget runtime handle"
        case .initFailed(let code):
            return "wr_init failed: \(code)"
        case .startFailed(let code):
            return "wr_start failed: \(code)"
        case .stopFailed(let code):
            return "wr_stop failed: \(code)"
        case .onFailed(let code):
            return "wr_on failed: \(code)"
        case .runReturnedNil:
            return "wr_run returned nil"
        }
    }
}

final class GoWidgetRuntimeAdapter: WidgetRuntime {
    private final class EventBox {
        let callback: (String, String) -> Void

        init(callback: @escaping (String, String) -> Void) {
            self.callback = callback
        }
    }

    private static let eventTrampoline: @convention(c) (Int64, UnsafePointer<CChar>?, UnsafePointer<CChar>?, UnsafeMutableRawPointer?) -> Void = {
        _, eventC, messageC, userData in
        guard let userData else { return }
        let box = Unmanaged<EventBox>.fromOpaque(userData).takeUnretainedValue()
        let event = eventC.map { String(cString: $0) } ?? ""
        let message = messageC.map { String(cString: $0) } ?? ""
        box.callback(event, message)
    }

    private static var didInit = false
    private static let initLock = NSLock()

    private var handle: Int64 = 0
    private var eventUserData: UnsafeMutableRawPointer?

    init(widgetDir: String? = nil, dataDir: String? = nil) {
        do {
            try Self.initializeRuntime(widgetDir: widgetDir, dataDir: dataDir)
        } catch {
            Logger.error("GoWidgetRuntime init failed: \(error.localizedDescription)")
        }
    }

    deinit {
        destroy()
    }

    static func initializeRuntime(widgetDir: String? = nil, dataDir: String? = nil) throws {
        initLock.lock()
        defer { initLock.unlock() }

        if didInit {
            return
        }

        let code: Int32 = (widgetDir ?? "").withCString { widgetDirC in
            (dataDir ?? "").withCString { dataDirC in
                wr_init(widgetDirC, dataDirC)
            }
        }

        guard code == 0 else {
            throw GoWidgetRuntimeError.initFailed(code: code)
        }

        didInit = true
    }

    func create(path: String, onEvent: ((String, String) -> Void)? = nil) throws {
        destroy()

        let cb: widget_event_cb? = onEvent == nil ? nil : Self.eventTrampoline
        if let onEvent {
            eventUserData = Unmanaged.passRetained(EventBox(callback: onEvent)).toOpaque()
        }

        let runtimeHandle: Int64 = path.withCString { cPath in
            wr_create(cPath, cb, eventUserData)
        }

        guard runtimeHandle != 0 else {
            releaseEventUserDataIfNeeded()
            throw GoWidgetRuntimeError.createFailed
        }

        handle = runtimeHandle
    }

    func start(initialScript: String? = nil) throws {
        guard handle != 0 else { throw GoWidgetRuntimeError.invalidHandle }

        let code: Int32 = (initialScript ?? "").withCString { scriptC in
            wr_start(handle, scriptC)
        }

        guard code == 0 else {
            throw GoWidgetRuntimeError.startFailed(code: code)
        }
    }

    func run(_ script: String) throws -> String {
        guard handle != 0 else { throw GoWidgetRuntimeError.invalidHandle }

        let ptr: UnsafeMutablePointer<CChar>? = script.withCString { scriptC in
            wr_run(handle, scriptC)
        }

        guard let ptr else {
            throw GoWidgetRuntimeError.runReturnedNil
        }
        defer { wr_string_free(ptr) }

        return String(cString: ptr)
    }

    func on(event: String, payload: String? = nil) throws {
        guard handle != 0 else { throw GoWidgetRuntimeError.invalidHandle }

        let code: Int32 = event.withCString { eventC in
            (payload ?? "").withCString { payloadC in
                wr_on(handle, eventC, payloadC)
            }
        }

        guard code == 0 else {
            throw GoWidgetRuntimeError.onFailed(code: code)
        }
    }

    func stop() {
        guard handle != 0 else { return }
        let code = wr_stop(handle)
        if code != 0 {
            Logger.warning("wr_stop returned non-zero: \(code)")
        }
    }

    func destroy() {
        if handle != 0 {
            wr_destroy(handle)
            handle = 0
        }
        releaseEventUserDataIfNeeded()
    }

    private func releaseEventUserDataIfNeeded() {
        guard let eventUserData else { return }
        Unmanaged<EventBox>.fromOpaque(eventUserData).release()
        self.eventUserData = nil
    }
}
