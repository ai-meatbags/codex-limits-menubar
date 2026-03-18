import Foundation

final class SnapshotLoader {
    private static let standardExecutablePaths = [
        "/opt/homebrew/bin",
        "/usr/local/bin",
        "/usr/bin",
        "/bin",
        "/opt/homebrew/sbin",
        "/usr/local/sbin"
    ]

    private let decoder = JSONDecoder()
    private let rootURL: URL
    private let runtimeConfig: RuntimeConfig
    private let logger: AppLogger
    private let resolvedLogFilePath: String

    init(rootURL: URL = Bundle.main.resourceURL!.appendingPathComponent("runtime", isDirectory: true)) throws {
        self.rootURL = rootURL
        let configURL = rootURL.appendingPathComponent("config.json")
        let data = try Data(contentsOf: configURL)
        runtimeConfig = try decoder.decode(RuntimeConfig.self, from: data)
        resolvedLogFilePath = Self.resolveLogFilePath(
            override: ProcessInfo.processInfo.environment["CODEX_LIMITS_LOG_FILE"],
            configValue: runtimeConfig.logFilePath
        )
        logger = AppLogger(logFilePath: resolvedLogFilePath)
        logger.log("SnapshotLoader initialized")
    }

    var pollSeconds: TimeInterval {
        runtimeConfig.pollSeconds
    }

    var logFilePath: String {
        resolvedLogFilePath
    }

    func load() -> MenubarSnapshot {
        let scriptURL = rootURL.appendingPathComponent("src/cli/codex-limits-menubar-snapshot.mjs")
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        logger.log("Starting snapshot refresh script=\(scriptURL.path)")
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["node", scriptURL.path]
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        process.environment = childEnvironment()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            logger.log("Snapshot process failed to start: \(error.localizedDescription)")
            return fallbackSnapshot(message: "Failed to run snapshot loader: \(error.localizedDescription)")
        }

        let stdoutData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let stdout = String(decoding: stdoutData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        let stderr = String(decoding: stderrData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        logger.log("Snapshot refresh completed exit=\(process.terminationStatus) stdoutBytes=\(stdoutData.count) stderrBytes=\(stderrData.count)")
        if !stderr.isEmpty {
            logger.log("Snapshot stderr: \(stderr)")
        }

        guard !stdout.isEmpty else {
            logger.log("Snapshot loader produced no stdout")
            return fallbackSnapshot(message: stderr.isEmpty ? "Snapshot loader produced no output" : stderr)
        }

        do {
            let snapshot = try decoder.decode(MenubarSnapshot.self, from: Data(stdout.utf8))
            logger.log("Snapshot decoded ok=\(snapshot.ok) title=\(snapshot.title)")
            return snapshot
        } catch {
            logger.log("Snapshot JSON parse failed: \(error.localizedDescription)")
            return fallbackSnapshot(message: "Snapshot JSON parse failed: \(stderr.isEmpty ? stdout : stderr)")
        }
    }

    private func childEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["CODEX_LIMITS_LOG_FILE"] = resolvedLogFilePath
        environment["PATH"] = runtimePath(baseEnvironment: environment)
        return environment
    }

    private func runtimePath(baseEnvironment: [String: String]) -> String {
        var pathEntries = [String]()

        if let nodeOverride = executableOverrideDirectory(for: "CODEX_LIMITS_NODE_BIN") {
            pathEntries.append(nodeOverride)
        }
        if let codexOverride = executableOverrideDirectory(for: "CODEX_LIMITS_CODEX_BIN") {
            pathEntries.append(codexOverride)
        }

        pathEntries.append(contentsOf: Self.standardExecutablePaths)

        if let existingPath = baseEnvironment["PATH"], !existingPath.isEmpty {
            pathEntries.append(existingPath)
        }

        return Array(NSOrderedSet(array: pathEntries)).compactMap { $0 as? String }.joined(separator: ":")
    }

    private func executableOverrideDirectory(for key: String) -> String? {
        guard let value = ProcessInfo.processInfo.environment[key], !value.isEmpty else {
            return nil
        }

        return URL(fileURLWithPath: value).deletingLastPathComponent().path
    }

    private static func resolveLogFilePath(override: String?, configValue: String?) -> String {
        if let override, !override.isEmpty {
            return NSString(string: override).expandingTildeInPath
        }
        if let configValue, !configValue.isEmpty {
            return NSString(string: configValue).expandingTildeInPath
        }

        return NSString(string: "~/Library/Logs/CodexLimitsMenuBar/app.log").expandingTildeInPath
    }

    private func fallbackSnapshot(message: String) -> MenubarSnapshot {
        MenubarSnapshot(
            ok: false,
            title: "—",
            subtitle: "Codex limits unavailable",
            errorMessage: message,
            accountLabel: "Open logs to inspect local Codex CLI state",
            buckets: [],
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )
    }
}
