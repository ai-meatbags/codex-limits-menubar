import Foundation

final class AppLogger {
    private let logURL: URL
    private let formatter = ISO8601DateFormatter()
    private let queue = DispatchQueue(label: "local.codex.limits.logger", qos: .utility)

    init(logFilePath: String) {
        logURL = URL(fileURLWithPath: logFilePath)
        ensureParentDirectory()
    }

    var path: String {
        logURL.path
    }

    func log(_ message: String) {
        let line = "[\(formatter.string(from: Date()))] \(message)\n"
        queue.async {
            guard let data = line.data(using: .utf8) else {
                return
            }

            if FileManager.default.fileExists(atPath: self.logURL.path) {
                if let handle = try? FileHandle(forWritingTo: self.logURL) {
                    defer { try? handle.close() }
                    _ = try? handle.seekToEnd()
                    try? handle.write(contentsOf: data)
                    return
                }
            }

            try? data.write(to: self.logURL, options: .atomic)
        }
    }

    private func ensureParentDirectory() {
        try? FileManager.default.createDirectory(
            at: logURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
    }
}
