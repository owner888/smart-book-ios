import Foundation

/// Swift Logger - 控制台日志工具
/// 支持 info、warn、debug、error 四个日志级别
final class Logger {
    
    // MARK: - 日志级别
    
    enum Level: String {
        case info = "INFO"
        case warn = "WARN"
        case debug = "DEBUG"
        case error = "ERROR"
        
        var emoji: String {
            switch self {
            case .info: return "ℹ️"
            case .warn: return "⚠️"
            case .debug: return "🔍"
            case .error: return "❌"
            }
        }
    }
    
    // MARK: - 配置
    
    /// 是否启用日志
    static var enabled: Bool = true
    
    /// 是否显示时间戳
    static var showTimestamp: Bool = true
    
    // MARK: - 日志方法
    
    /// INFO 级别 - 绿色
    static func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.info, message, file: file, function: function, line: line)
    }
    
    /// WARN 级别 - 黄色
    static func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.warn, message, file: file, function: function, line: line)
    }
    
    /// DEBUG 级别 - 青色
    static func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.debug, message, file: file, function: function, line: line)
    }
    
    /// ERROR 级别 - 红色
    static func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.error, message, file: file, function: function, line: line)
    }
    
    /// 记录错误
    static func error(_ error: Error, file: String = #file, function: String = #function, line: Int = #line) {
        log(.error, "\(error.localizedDescription)", file: file, function: function, line: line)
    }
    
    /// 分割线
    static func separator(_ char: String = "-", length: Int = 50) {
        guard enabled else { return }
        let line = String(repeating: char, count: length)
        print("[\(DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium))] \(line)")
    }
    
    /// 标题样式
    static func title(_ title: String) {
        guard enabled else { return }
        let border = String(repeating: "=", count: 50)
        print("")
        print("[\(DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium))] \(border)")
        print("[\(DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium))]   \(title)")
        print("[\(DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium))] \(border)")
        print("")
    }
    
    /// 性能计时开始
    private static var startTimes: [String: CFAbsoluteTime] = [:]
    
    static func time(_ label: String) {
        guard enabled else { return }
        startTimes[label] = CFAbsoluteTimeGetCurrent()
        debug("Timer '\(label)' started")
    }
    
    /// 性能计时结束并输出
    static func timeEnd(_ label: String) -> CFAbsoluteTime {
        guard enabled, let start = startTimes[label] else { return 0 }
        let duration = CFAbsoluteTimeGetCurrent() - start
        startTimes.removeValue(forKey: label)
        info("Timer '\(label)': \(String(format: "%.2f", duration * 1000))ms")
        return duration
    }
    
    // MARK: - 私有方法
    
    private static func log(_ level: Level, _ message: String, file: String, function: String, line: Int) {
        guard enabled else { return }
        
        let timestamp = showTimestamp ? "[\(DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium))] " : ""
        let fileName = (file as NSString).lastPathComponent
        let location = "\(fileName):\(line) \(function)"
        
        print("\(timestamp)\(level.emoji) [\(level.rawValue)] \(message)")
        print("  at \(location)")
    }
}
