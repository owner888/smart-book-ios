import Foundation

final class WidgetRuntimeService {
    private let runtime: WidgetRuntime

    init(runtime: WidgetRuntime) {
        self.runtime = runtime
    }

    func installBundledSmokeSampleIfNeeded() {
        let relativePath = "widget-samples/smoke"

        guard let appSupportURL = applicationSupportDirectoryURL() else {
            Logger.warning("[WidgetFFI] app support directory unavailable")
            return
        }

        let destinationURL = appSupportURL.appendingPathComponent(relativePath, isDirectory: true)
        let fileManager = FileManager.default

        if isValidWidgetDirectory(destinationURL.path) {
            return
        }

        do {
            guard let bundledFiles = bundledSmokeFiles() else {
                Logger.error("[WidgetFFI] bundled smoke sample missing from app resources")
                return
            }

            try fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true)
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
                try fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true)
            }

            try Data(contentsOf: bundledFiles.widget).write(
                to: destinationURL.appendingPathComponent("widget.js"),
                options: .atomic
            )
            try Data(contentsOf: bundledFiles.index).write(
                to: destinationURL.appendingPathComponent("index.js"),
                options: .atomic
            )

            Logger.info("[WidgetFFI] installed bundled smoke sample to: \(destinationURL.path)")
        } catch {
            Logger.error("[WidgetFFI] copy smoke sample failed: \(error.localizedDescription)")
        }
    }

    @discardableResult
    func runSmoke(
        widgetPath: String,
        initialScript: String? = nil,
        runScript: String = "1+1",
        eventName: String? = nil,
        eventPayload: String? = nil
    ) -> Bool {
        do {
            try runtime.create(path: widgetPath) { event, payload in
                Logger.info("[WidgetFFI] event=\(event), payload=\(payload)")
            }
            try runtime.start(initialScript: initialScript)
            let result = try runtime.run(runScript)
            Logger.info("[WidgetFFI] run result: \(result)")

            if let eventName {
                try runtime.on(event: eventName, payload: eventPayload)
                Logger.info("[WidgetFFI] on sent: \(eventName)")
            }

            runtime.stop()
            runtime.destroy()
            Logger.info("[WidgetFFI] smoke completed")
            return true
        } catch {
            Logger.error("[WidgetFFI] smoke failed: \(error.localizedDescription)")
            runtime.stop()
            runtime.destroy()
            return false
        }
    }

    func runTool(
        widget: String,
        script: String? = nil,
        eventName: String? = nil,
        eventPayloadObject: Any? = nil
    ) throws -> [String: Any] {
        guard let widgetPath = resolveWidgetPath(widget) else {
            throw NSError(domain: "WidgetRuntimeService", code: 1, userInfo: [NSLocalizedDescriptionKey: "invalid widget path: \(widget)"])
        }

        let payloadString: String?
        if let eventPayloadObject {
            if JSONSerialization.isValidJSONObject(eventPayloadObject),
                let data = try? JSONSerialization.data(withJSONObject: eventPayloadObject, options: []),
                let str = String(data: data, encoding: .utf8)
            {
                payloadString = str
            } else if let str = eventPayloadObject as? String {
                payloadString = str
            } else {
                payloadString = nil
            }
        } else {
            payloadString = nil
        }

        do {
            try runtime.create(path: widgetPath) { event, payload in
                Logger.info("[WidgetFFI] tool event=\(event), payload=\(payload)")
            }
            try runtime.start(initialScript: nil)
            let result = try runtime.run(script ?? "1+1")

            if let eventName {
                try runtime.on(event: eventName, payload: payloadString)
            }

            runtime.stop()
            runtime.destroy()

            return [
                "widget_path": widgetPath,
                "run_result": result,
                "event_sent": eventName != nil,
            ]
        } catch {
            runtime.stop()
            runtime.destroy()
            throw error
        }
    }

    func runSmokeFromLaunchArguments(arguments: [String] = ProcessInfo.processInfo.arguments) {
        Logger.info("[WidgetFFI] launch args: \(arguments.joined(separator: " "))")

        guard let widgetPathInput = value(of: "--widget-path", in: arguments), !widgetPathInput.isEmpty else {
            Logger.info("[WidgetFFI] skip smoke: missing --widget-path")
            return
        }

        guard let widgetPath = resolveWidgetPath(widgetPathInput) else {
            Logger.warning("[WidgetFFI] invalid widget path: \(widgetPathInput)")
            return
        }

        Logger.info("[WidgetFFI] widget path resolved: \(widgetPath)")

        let runScript = value(of: "--widget-script", in: arguments) ?? "1+1"
        let initialScript = value(of: "--widget-start-json", in: arguments)
        let eventName = value(of: "--widget-event", in: arguments)
        let eventPayload = value(of: "--widget-payload", in: arguments)

        Logger.info("[WidgetFFI] smoke start, script=\(runScript), event=\(eventName ?? "<none>")")

        _ = runSmoke(
            widgetPath: widgetPath,
            initialScript: initialScript,
            runScript: runScript,
            eventName: eventName,
            eventPayload: eventPayload
        )
    }

    private func value(of key: String, in arguments: [String]) -> String? {
        if let equalStyle = arguments.first(where: { $0.hasPrefix("\(key)=") }) {
            Logger.debug("[WidgetFFI] arg hit (equal style): \(key)")
            return String(equalStyle.dropFirst(key.count + 1))
        }

        guard let index = arguments.firstIndex(of: key), arguments.indices.contains(index + 1) else {
            return nil
        }
        Logger.debug("[WidgetFFI] arg hit (pair style): \(key)")
        return arguments[index + 1]
    }

    private func resolveWidgetPath(_ input: String) -> String? {
        let fileManager = FileManager.default

        if input.hasPrefix("/") || input.hasPrefix("~") {
            let expanded = (input as NSString).expandingTildeInPath
            if isValidWidgetDirectory(expanded) {
                return expanded
            }
            return nil
        }

        var candidates: [URL] = []

        if let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            candidates.append(documents.appendingPathComponent(input, isDirectory: true))
        }
        if let appSupport = applicationSupportDirectoryURL() {
            candidates.append(appSupport.appendingPathComponent(input, isDirectory: true))
        }
        if let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            candidates.append(caches.appendingPathComponent(input, isDirectory: true))
        }
        if let resourceURL = Bundle.main.resourceURL {
            candidates.append(resourceURL.appendingPathComponent(input, isDirectory: true))
        }

        for candidate in candidates {
            let path = candidate.path
            if isValidWidgetDirectory(path) {
                Logger.debug("[WidgetFFI] resolved candidate: \(path)")
                return path
            }
            Logger.debug("[WidgetFFI] candidate miss: \(path)")
        }

        return nil
    }

    private func isValidWidgetDirectory(_ directoryPath: String) -> Bool {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directoryPath, isDirectory: &isDirectory), isDirectory.boolValue else {
            return false
        }
        let widgetJS = (directoryPath as NSString).appendingPathComponent("widget.js")
        return FileManager.default.fileExists(atPath: widgetJS)
    }

    private func applicationSupportDirectoryURL() -> URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    }

    private func bundledSmokeFiles() -> (widget: URL, index: URL)? {
        guard
            let widget = Bundle.main.url(forResource: "widget_runtime_smoke_widget", withExtension: "js"),
            let index = Bundle.main.url(forResource: "widget_runtime_smoke_index", withExtension: "js")
        else {
            return nil
        }
        return (widget, index)
    }
}
