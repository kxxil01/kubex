import AppKit
import Darwin
import Foundation

protocol KubectlExecuting: Sendable {
    func run(
        arguments: [String],
        kubeconfigPath: String?,
        configuration overrideConfiguration: KubectlRunner.Configuration?
    ) async throws -> String

    func runJSON<T: Decodable>(
        arguments: [String],
        kubeconfigPath: String?,
        decoder: JSONDecoder,
        configuration overrideConfiguration: KubectlRunner.Configuration?
    ) async throws -> T
}

extension KubectlExecuting {
    func run(
        arguments: [String],
        kubeconfigPath: String?
    ) async throws -> String {
        try await run(arguments: arguments, kubeconfigPath: kubeconfigPath, configuration: nil)
    }

    func runJSON<T: Decodable>(
        arguments: [String],
        kubeconfigPath: String?
    ) async throws -> T {
        try await runJSON(
            arguments: arguments,
            kubeconfigPath: kubeconfigPath,
            decoder: JSONDecoder(),
            configuration: nil
        )
    }
}

struct KubectlError: LocalizedError {
    let message: String
    let output: String?
    let exitCode: Int32?

    init(message: String, output: String? = nil, exitCode: Int32? = nil) {
        self.message = message
        self.output = output
        self.exitCode = exitCode
    }

    var errorDescription: String? { message }
}

@preconcurrency enum KubectlDefaults {
    private static let defaultSearchDirectories = [
        "/usr/local/bin",
        "/opt/homebrew/bin",
        "/opt/homebrew/sbin",
        "/usr/local/google-cloud-sdk/bin",
        "/usr/local/share/google-cloud-sdk/bin",
        "/usr/local/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/bin",
        "/opt/homebrew/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/bin",
        "~/google-cloud-sdk/bin",
        "~/Developer/google-cloud-sdk/bin",
        "/usr/bin",
        "/usr/sbin"
    ]

    private static let cacheLock = NSLock()
    nonisolated(unsafe) private static var cachedShellPaths: [String: String] = [:]
    nonisolated(unsafe) private static var cachedExecutables: [String: String] = [:]
    nonisolated(unsafe) private static var cachedGCloudSDKRoot: String?

    private static let logURL: URL = {
        let base = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/Kubex", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("kubectl-runner.log")
    }()

    static func defaultKubeconfigPath() -> String? {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        let kubeconfigURL = homeDirectory.appendingPathComponent(".kube/config")
        if FileManager.default.fileExists(atPath: kubeconfigURL.path) {
            return kubeconfigURL.path
        }
        return nil
    }

    static func enhancedPATH(from path: String?) -> String {
        var directories: [String] = []
        var seen = Set<String>()

        appendDirectories(from: path, to: &directories, seen: &seen)
        appendDirectories(from: loadLoginShellPATH(), to: &directories, seen: &seen)

        for directory in defaultSearchDirectories {
            appendDirectory(directory, to: &directories, seen: &seen)
        }

        var gcloudPath = cachedExecutable(named: "gcloud")
        if gcloudPath == nil {
            gcloudPath = locateExecutable("gcloud", using: directories)
        }
        if gcloudPath == nil {
            gcloudPath = locateExecutableViaShell("gcloud")
        }
        if let gcloudPath {
            storeExecutable("gcloud", path: gcloudPath)
            let dir = (gcloudPath as NSString).deletingLastPathComponent
            appendDirectory(dir, to: &directories, seen: &seen)
            debug("gcloud -> \(gcloudPath)")
        }

        var pluginPath = cachedExecutable(named: "gke-gcloud-auth-plugin")
        if pluginPath == nil {
            pluginPath = locateExecutable("gke-gcloud-auth-plugin", using: directories)
        }
        if pluginPath == nil {
            pluginPath = locateExecutableViaShell("gke-gcloud-auth-plugin")
            if let pluginPath {
                let directory = (pluginPath as NSString).deletingLastPathComponent
                appendDirectory(directory, to: &directories, seen: &seen)
            }
        }

        if pluginPath == nil, let sdkRoot = detectGCloudSDKRoot() {
            let candidate = (sdkRoot as NSString).appendingPathComponent("bin")
            appendDirectory(candidate, to: &directories, seen: &seen)
            pluginPath = locateExecutable("gke-gcloud-auth-plugin", using: directories)
        }

        if let pluginPath {
            storeExecutable("gke-gcloud-auth-plugin", path: pluginPath)
            debug("gke-gcloud-auth-plugin -> \(pluginPath)")
        } else {
            debug("gke-gcloud-auth-plugin not found in PATH")
        }

        let value = directories.joined(separator: ":")
        debug("Resolved PATH: \(value)")
        return value
    }

    static func resolveKubectlExecutable(preferred: [String?], searchPATH: String?) -> (command: String, found: Bool) {
        var candidates: [String] = []
        var seen = Set<String>()

        for value in preferred {
            guard let value, !value.isEmpty else { continue }
            let standardized = standardize(value)
            if seen.insert(standardized).inserted {
                candidates.append(standardized)
            }
        }

        for candidate in candidates where candidate.contains("/") {
            let expanded = standardize(candidate)
            if FileManager.default.isExecutableFile(atPath: expanded) {
                return (expanded, true)
            }
        }

        let directories = searchDirectories(from: searchPATH)
        for directory in directories {
            let path = (directory as NSString).appendingPathComponent("kubectl")
            if seen.contains(path) { continue }
            if FileManager.default.isExecutableFile(atPath: path) {
                return (path, true)
            }
            seen.insert(path)
        }

        if let first = candidates.first {
            return (first, false)
        }
        return ("kubectl", false)
    }

    static func prepareEnvironmentForKubectl(_ environment: inout [String: String], preferredExecutable: String? = nil) -> (command: String, found: Bool) {
        let enhancedPath = enhancedPATH(from: environment["PATH"])
        environment["PATH"] = enhancedPath
        let resolution = resolveKubectlExecutable(
            preferred: [preferredExecutable, environment["KUBECTL_EXE"], "kubectl"],
            searchPATH: enhancedPath
        )
        environment["KUBECTL_EXE"] = resolution.command
        return resolution
    }

    static func buildTerminalCommand(environment: [String: String], arguments: [String]) -> String {
        let exports = environment.compactMap { key, value -> String? in
            guard !value.isEmpty else { return nil }
            return "export \(key)=\(escapeForShell(value));"
        }
        let command = arguments.map { escapeForShell($0) }.joined(separator: " ")
        return (exports + [command]).joined(separator: " ")
    }

    private static func cachedExecutable(named name: String) -> String? {
        cacheLock.lock()
        let value = cachedExecutables[name]
        cacheLock.unlock()
        return value
    }

    private static func storeExecutable(_ name: String, path: String) {
        cacheLock.lock()
        cachedExecutables[name] = standardize(path)
        cacheLock.unlock()
    }

    private static func escapeForShell(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func cachedShellPath(for shell: String) -> String? {
        cacheLock.lock()
        let value = cachedShellPaths[shell]
        cacheLock.unlock()
        return value
    }

    private static func storeShellPath(_ path: String, for shell: String) {
        cacheLock.lock()
        cachedShellPaths[shell] = path
        cacheLock.unlock()
    }

    static func launchInTerminal(
        kubeconfigPath: String?,
        arguments: [String],
        extraEnv: [String: String] = [:]
    ) throws {
        var environment = ProcessInfo.processInfo.environment
        if let kubeconfigPath, !kubeconfigPath.isEmpty {
            environment["KUBECONFIG"] = kubeconfigPath
        }
        environment.merge(extraEnv) { _, new in new }

        var preparedEnvironment = environment
        let resolution = prepareEnvironmentForKubectl(&preparedEnvironment, preferredExecutable: arguments.first)
        guard resolution.found else {
            throw KubectlError(message: "kubectl executable not found. Install kubectl or update PATH.", output: nil)
        }

        var finalArguments = arguments
        if finalArguments.isEmpty {
            finalArguments = ["kubectl"]
        }
        if finalArguments[0] == "kubectl" {
            finalArguments[0] = resolution.command
        } else if finalArguments[0] != resolution.command {
            finalArguments.insert(resolution.command, at: 0)
        }

        var commandEnv: [String: String] = [
            "PATH": preparedEnvironment["PATH"] ?? "",
            "KUBECTL_EXE": resolution.command
        ]
        if let kubeconfig = preparedEnvironment["KUBECONFIG"] {
            commandEnv["KUBECONFIG"] = kubeconfig
        }
        commandEnv.merge(extraEnv) { _, new in new }

        let terminalCommand = buildTerminalCommand(environment: commandEnv, arguments: finalArguments)
        let scriptCommand = terminalCommand.replacingOccurrences(of: "\"", with: "\\\"")
        let script = "tell application \"Terminal\" to do script \"\(scriptCommand)\""

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["osascript", "-e", script]
        process.environment = preparedEnvironment
        try process.run()
    }

    private static func searchDirectories(from path: String?) -> [String] {
        var directories: [String] = []
        var seen = Set<String>()
        appendDirectories(from: path, to: &directories, seen: &seen)
        for directory in defaultSearchDirectories {
            appendDirectory(directory, to: &directories, seen: &seen)
        }
        return directories
    }

    private static func appendDirectories(from path: String?, to directories: inout [String], seen: inout Set<String>) {
        guard let path, !path.isEmpty else { return }
        for component in path.split(separator: ":") {
            appendDirectory(String(component), to: &directories, seen: &seen)
        }
    }

    private static func appendDirectory(_ directory: String, to directories: inout [String], seen: inout Set<String>) {
        let standardized = standardize(directory)
        guard !standardized.isEmpty, seen.insert(standardized).inserted else { return }
        directories.append(standardized)
    }

    fileprivate static func standardize(_ path: String) -> String {
        (path as NSString).expandingTildeInPath
    }

    private static func loadLoginShellPATH() -> String? {
        guard let shellPath = ProcessInfo.processInfo.environment["SHELL"], !shellPath.isEmpty else { return nil }

        if let cached = cachedShellPath(for: shellPath) {
            return cached
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [shellPath, "-lc", "echo -n $PATH"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    storeShellPath(trimmed, for: shellPath)
                }
                return trimmed
            }
        } catch {
            return nil
        }
        return nil
    }

    private static func locateExecutable(_ name: String, using directories: [String]) -> String? {
        for directory in directories {
            let path = (directory as NSString).appendingPathComponent(name)
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        return nil
    }

    private static func locateExecutableViaShell(_ name: String) -> String? {
        if let cached = cachedExecutable(named: name) {
            return cached
        }
        let shellPath = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [shellPath, "-lc", "command -v \(name)"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    return nil
                }
                storeExecutable(name, path: trimmed)
                return trimmed
            }
        } catch {
            return nil
        }
        return nil
    }

    private static func detectGCloudSDKRoot() -> String? {
        cacheLock.lock()
        if let cached = cachedGCloudSDKRoot {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["gcloud", "info", "--format=value(config.paths.sdk_root)"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                if let output, !output.isEmpty {
                    cacheLock.lock()
                    cachedGCloudSDKRoot = output
                    cacheLock.unlock()
                    return output
                }
                return nil
            }
        } catch {
            return nil
        }
        return nil
    }

    static func debug(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "\(timestamp) - \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        if let handle = try? FileHandle(forWritingTo: logURL) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            try? data.write(to: logURL)
        }
    }
}

private extension Array where Element == String {
    func reducingDuplicates() -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for element in self {
            let standardized = KubectlDefaults.standardize(element)
            if seen.insert(standardized).inserted {
                result.append(standardized)
            }
        }
        return result
    }
}

private final class PipeDataBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func append(_ chunk: Data) {
        guard !chunk.isEmpty else { return }
        lock.lock()
        data.append(chunk)
        lock.unlock()
    }

    func appendRemaining(from handle: FileHandle) {
        let remaining = handle.readDataToEndOfFile()
        append(remaining)
    }

    func string(encoding: String.Encoding = .utf8) -> String {
        lock.lock()
        let value = String(data: data, encoding: encoding) ?? ""
        lock.unlock()
        return value
    }
}

private final class ContinuationResumeGuard: @unchecked Sendable {
    private let lock = NSLock()
    private var isResumed = false

    func resume(_ block: () -> Void) {
        lock.lock()
        let shouldRun = !isResumed
        if shouldRun {
            isResumed = true
        }
        lock.unlock()

        if shouldRun {
            block()
        }
    }
}

final class KubectlRunner: @unchecked Sendable {
    struct Configuration: Sendable {
        var timeout: TimeInterval?
        var maxRetries: Int
        var retryDelay: TimeInterval
        var retryableExitCodes: Set<Int32>
        var retryableErrorSubstrings: [String]

        static let `default` = Configuration(
            timeout: 30,
            maxRetries: 2,
            retryDelay: 1.0,
            retryableExitCodes: [1, 2, 137],
            retryableErrorSubstrings: [
                "i/o timeout",
                "timed out",
                "connection refused",
                "connection reset",
                "no such host",
                "temporarily unavailable",
                "EOF",
                "context deadline exceeded",
                "server is currently unable"
            ]
        )

        func shouldRetry(_ error: KubectlError, attempt: Int) -> Bool {
            guard attempt + 1 < maxRetries else { return false }
            if let code = error.exitCode, retryableExitCodes.contains(code) {
                return true
            }
            let haystack = [error.message, error.output ?? ""].joined(separator: " ")
            return retryableErrorSubstrings.contains { haystack.localizedCaseInsensitiveContains($0) }
        }

        func backoffDelay(for attempt: Int) -> TimeInterval {
            retryDelay * pow(2, Double(attempt))
        }
    }

    private struct RunResult {
        let stdout: String
        let stderr: String
        let exitCode: Int32
        let terminationReason: Process.TerminationReason
    }

    private final class ExecutionState: @unchecked Sendable {
        private let forcedErrorLock = NSLock()
        private let taskLock = NSLock()
        private var forcedError: KubectlError?
        private var timeoutTask: Task<Void, Never>?
        private var cancelClosure: (@Sendable () -> Void)?

        func setForcedErrorIfNeeded(_ error: KubectlError) {
            forcedErrorLock.lock()
            if forcedError == nil {
                forcedError = error
            }
            forcedErrorLock.unlock()
        }

        func takeForcedError() -> KubectlError? {
            forcedErrorLock.lock()
            let value = forcedError
            forcedError = nil
            forcedErrorLock.unlock()
            return value
        }

        func storeTimeoutTask(_ task: Task<Void, Never>) {
            taskLock.lock()
            timeoutTask = task
            taskLock.unlock()
        }

        func cancelTimeoutTask() {
            taskLock.lock()
            timeoutTask?.cancel()
            timeoutTask = nil
            taskLock.unlock()
        }

        func storeCancelClosure(_ closure: @escaping @Sendable () -> Void) {
            taskLock.lock()
            cancelClosure = closure
            taskLock.unlock()
        }

        func executeCancelClosure() {
            taskLock.lock()
            let closure = cancelClosure
            cancelClosure = nil
            taskLock.unlock()
            closure?()
        }

        func clearCancelClosure() {
            taskLock.lock()
            cancelClosure = nil
            taskLock.unlock()
        }
    }

    private let configuration: Configuration
    private let executableURL: URL
    private let environment: [String: String]
    private let kubectlExecutable: String
    private let executableFound: Bool

    init(
        executablePath: String? = nil,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        configuration: Configuration = .default
    ) {
        self.configuration = configuration
        self.executableURL = URL(fileURLWithPath: "/usr/bin/env")

        let envExecutable = environment["KUBECTL_EXE"]
        let enhancedPath = KubectlDefaults.enhancedPATH(from: environment["PATH"])
        let resolution = KubectlDefaults.resolveKubectlExecutable(
            preferred: [executablePath, envExecutable, "kubectl"],
            searchPATH: enhancedPath
        )

        var env = environment
        env["PATH"] = enhancedPath
        env["KUBECTL_EXE"] = resolution.command

        self.environment = env
        self.kubectlExecutable = resolution.command
        self.executableFound = resolution.found
    }

    func run(
        arguments: [String],
        kubeconfigPath: String? = nil,
        configuration overrideConfiguration: Configuration? = nil
    ) async throws -> String {
        guard executableFound else {
            let message: String
            if kubectlExecutable.contains("/") {
                message = "kubectl executable not found at \(kubectlExecutable). Install kubectl or update preferences."
            } else {
                message = "kubectl executable not found in PATH. Install kubectl or add it to your PATH."
            }
            throw KubectlError(message: message, output: nil, exitCode: nil)
        }

        let config = overrideConfiguration ?? configuration
        var attempt = 0

        while true {
            do {
                let result = try await execute(arguments: arguments, kubeconfigPath: kubeconfigPath, configuration: config)
                if result.exitCode == 0 && result.terminationReason == .exit {
                    KubectlDefaults.debug("Exit 0")
                    return result.stdout
                }

                let trimmedStderr = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
                let trimmedStdout = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                let messageSource = trimmedStderr.isEmpty ? trimmedStdout : trimmedStderr
                let message = messageSource.isEmpty ? "kubectl command failed" : messageSource
                KubectlDefaults.debug("Exit \(result.exitCode): \(message)")
                let outputPayload = result.stdout.isEmpty ? (result.stderr.isEmpty ? nil : result.stderr) : result.stdout
                throw KubectlError(message: message, output: outputPayload, exitCode: result.exitCode)
            } catch let error as KubectlError {
                if config.shouldRetry(error, attempt: attempt) {
                    let delay = max(0, config.backoffDelay(for: attempt))
                    KubectlDefaults.debug("Retrying kubectl (attempt \(attempt + 2) of \(config.maxRetries)) after \(String(format: "%.1f", delay))s: \(error.message)")
                    let nanoseconds = UInt64(delay * 1_000_000_000)
                    try await Task.sleep(nanoseconds: nanoseconds)
                    attempt += 1
                    continue
                }
                throw error
            }
        }
    }

    func runJSON<T: Decodable>(
        arguments: [String],
        kubeconfigPath: String? = nil,
        decoder: JSONDecoder = JSONDecoder(),
        configuration overrideConfiguration: Configuration? = nil
    ) async throws -> T {
        let output = try await run(arguments: arguments, kubeconfigPath: kubeconfigPath, configuration: overrideConfiguration)
        let data = Data(output.utf8)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw KubectlError(message: "Failed to decode kubectl response", output: output, exitCode: nil)
        }
    }

    private func execute(
        arguments: [String],
        kubeconfigPath: String?,
        configuration: Configuration
    ) async throws -> RunResult {
        let processArguments = ([kubectlExecutable] + arguments)
        KubectlDefaults.debug("Run: \(processArguments.joined(separator: " "))")
        let state = ExecutionState()

        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                let process = Process()
                process.executableURL = executableURL
                process.arguments = processArguments

                var env = environment
                if let kubeconfigPath {
                    env["KUBECONFIG"] = kubeconfigPath
                }
                process.environment = env

                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()
                let stdoutHandle = stdoutPipe.fileHandleForReading
                let stderrHandle = stderrPipe.fileHandleForReading
                let stdoutBuffer = PipeDataBuffer()
                let stderrBuffer = PipeDataBuffer()

                stdoutHandle.readabilityHandler = { handle in
                    let data = handle.availableData
                    guard !data.isEmpty else {
                        handle.readabilityHandler = nil
                        return
                    }
                    stdoutBuffer.append(data)
                }

                stderrHandle.readabilityHandler = { handle in
                    let data = handle.availableData
                    guard !data.isEmpty else {
                        handle.readabilityHandler = nil
                        return
                    }
                    stderrBuffer.append(data)
                }

                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe

                let resumeGuard = ContinuationResumeGuard()

                state.storeCancelClosure { [weak process] in
                    guard let process, process.isRunning else { return }
                    state.setForcedErrorIfNeeded(KubectlError(message: "kubectl command cancelled", output: nil, exitCode: nil))
                    process.terminate()
                }

                if let timeout = configuration.timeout, timeout > 0 {
                    let timeoutTask = Task { [weak process] in
                        let nanoseconds = UInt64(timeout * 1_000_000_000)
                        try? await Task.sleep(nanoseconds: nanoseconds)
                        guard !Task.isCancelled else { return }
                        if let process, process.isRunning {
                            state.setForcedErrorIfNeeded(KubectlError(message: "kubectl command timed out after \(Int(ceil(timeout)))s", output: nil, exitCode: nil))
                            process.terminate()
                        }
                    }
                    state.storeTimeoutTask(timeoutTask)
                }

                @Sendable
                func finalize(status: Int32, reason: Process.TerminationReason, launchError: Error? = nil) {
                    resumeGuard.resume {
                        state.cancelTimeoutTask()
                        state.clearCancelClosure()

                        try? stdoutPipe.fileHandleForWriting.close()
                        try? stderrPipe.fileHandleForWriting.close()
                        stdoutHandle.readabilityHandler = nil
                        stderrHandle.readabilityHandler = nil

                        stdoutBuffer.appendRemaining(from: stdoutHandle)
                        stderrBuffer.appendRemaining(from: stderrHandle)

                        let stdoutString = stdoutBuffer.string()
                        let stderrString = stderrBuffer.string()

                        if let launchError {
                            let error = KubectlError(message: launchError.localizedDescription, output: stderrString.isEmpty ? stdoutString : stderrString, exitCode: status)
                            continuation.resume(throwing: error)
                            KubectlDefaults.debug("kubectl launch failure: \(launchError.localizedDescription)")
                        } else if let forced = state.takeForcedError() {
                            let payload = forced.output ?? (stderrString.isEmpty ? stdoutString : stderrString)
                            let enriched = KubectlError(message: forced.message, output: payload.isEmpty ? nil : payload, exitCode: forced.exitCode ?? status)
                            continuation.resume(throwing: enriched)
                            KubectlDefaults.debug("kubectl terminated early: \(forced.message)")
                        } else {
                            let result = RunResult(stdout: stdoutString, stderr: stderrString, exitCode: status, terminationReason: reason)
                            continuation.resume(returning: result)
                        }

                        try? stdoutHandle.close()
                        try? stderrHandle.close()
                    }
                }

                process.terminationHandler = { process in
                    finalize(status: process.terminationStatus, reason: process.terminationReason)
                }

                do {
                    try process.run()
                } catch {
                    finalize(status: -1, reason: .exit, launchError: error)
                }
            }
        }, onCancel: {
            state.executeCancelClosure()
        })
    }
}

extension KubectlRunner: KubectlExecuting {}

// MARK: - Cluster Service

@MainActor
final class KubectlClusterService: ClusterService {
    private let runner: any KubectlExecuting
    private let kubeconfigPath: String?
    private var contextIdentifiers: [String: UUID] = [:]
    private struct NodeMetrics {
        let cpuCores: Double?
        let memoryBytes: Double?
    }
    private struct NodeStatsCacheEntry {
        var timestamp: Date
        var summaries: [String: NodeStatsSummary]
    }

    private var nodeStatsCache: [String: NodeStatsCacheEntry] = [:]
    private let nodeStatsCacheTTL: TimeInterval = 15
    private struct SecretPermissionCacheKey: Hashable {
        let context: String
        let namespace: String
    }

    private struct SecretPermissionCacheEntry {
        var timestamp: Date
        var permissions: [String: ConfigResourcePermissions]
    }

    private var secretPermissionCache: [SecretPermissionCacheKey: SecretPermissionCacheEntry] = [:]
    private let secretPermissionCacheTTL: TimeInterval = 60
    private struct PodMetrics {
        let cpuCores: Double?
        let memoryBytes: Double?
    }

    private static let latencyRegex: NSRegularExpression = {
        let pattern = "(\\d+(?:\\.\\d+)?)\\s*(ms|milliseconds|msec|s|sec|secs|seconds)"
        // Pattern validated at initialization; failure is unrecoverable in practice.
        return try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }()

    init(runner: any KubectlExecuting = KubectlRunner(), kubeconfigPath: String? = KubectlDefaults.defaultKubeconfigPath()) {
        self.runner = runner
        self.kubeconfigPath = kubeconfigPath
    }

    func loadClusters() async throws -> [Cluster] {
        let config: KubectlConfig = try await runner.runJSON(arguments: ["config", "view", "-o", "json"], kubeconfigPath: kubeconfigPath)
        let contexts = config.contexts

        guard !contexts.isEmpty else { return [] }

        let clusterMap = Dictionary(uniqueKeysWithValues: config.clusters.map { ($0.name, $0) })
        var results: [Cluster] = []

        for namedContext in contexts {
            guard let namedCluster = clusterMap[namedContext.context.cluster] else { continue }
            let contextName = namedContext.name
            let clusterID = identifier(for: contextName)

            let cluster = Cluster(
                id: clusterID,
                name: namedCluster.name,
                contextName: contextName,
                server: namedCluster.cluster.server ?? "",
                health: .healthy,
                kubernetesVersion: namedCluster.cluster.serverVersion ?? "",
                nodeSummary: NodeSummary(total: 0, ready: 0, cpuUsage: nil, memoryUsage: nil, diskUsage: nil, networkReceiveBytes: nil, networkTransmitBytes: nil),
                namespaces: [],
                lastSynced: Date(),
                notes: nil,
                isConnected: false
            )
            results.append(cluster)
        }
        return results.sorted { $0.name < $1.name }
    }

    func loadClusterDetails(contextName: String, focusNamespace: String?) async throws -> Cluster {
        let config: KubectlConfig = try await runner.runJSON(arguments: ["config", "view", "-o", "json"], kubeconfigPath: kubeconfigPath)
        let clusterMap = Dictionary(uniqueKeysWithValues: config.clusters.map { ($0.name, $0) })

        guard let namedContext = config.contexts.first(where: { $0.name == contextName }) else {
            throw KubectlError(message: "Context \(contextName) not found in kubeconfig", output: nil)
        }

        guard let namedCluster = clusterMap[namedContext.context.cluster] else {
            throw KubectlError(message: "Cluster information missing for context \(contextName)", output: nil)
        }

        let clusterID = identifier(for: contextName)

        async let customResourcesTask = fetchCustomResourceDefinitions(contextName: contextName)

        let namespaceList: KubectlNamespaceList = try await runner.runJSON(arguments: ["get", "namespaces", "-o", "json", "--context", contextName], kubeconfigPath: kubeconfigPath)
        var namespaces: [Namespace] = namespaceList.items.map { item in
            Namespace(
                id: UUID(),
                name: item.metadata.name,
                workloads: [],
                pods: [],
                events: [],
                alerts: [],
                isLoaded: false
            )
        }

        var health: ClusterHealth = .healthy
        var notes: [String] = []

        let preferredNamespace = focusNamespace ?? namespaces.first?.name
        if let preferredNamespace,
           let detailed = try? await loadNamespaceDetails(contextName: contextName, namespace: preferredNamespace) {
            namespaces = namespaces.map { $0.name == detailed.name ? detailed : $0 }
            if detailed.workloads.contains(where: { $0.status != .healthy }) {
                health = .degraded
            }
        }

        let nodeData: (summary: NodeSummary, nodes: [NodeInfo])
        do {
            nodeData = try await loadNodeData(contextName: contextName)
        } catch {
            health = .degraded
            notes.append("Nodes: \(error.localizedDescription)")
            nodeData = (NodeSummary(total: 0, ready: 0, cpuUsage: nil, memoryUsage: nil, diskUsage: nil, networkReceiveBytes: nil, networkTransmitBytes: nil), [])
        }

        var cluster = Cluster(
            id: clusterID,
            name: namedCluster.name,
            contextName: contextName,
            server: namedCluster.cluster.server ?? "",
            health: health,
            kubernetesVersion: namedCluster.cluster.serverVersion ?? "",
            nodeSummary: nodeData.summary,
            nodes: nodeData.nodes,
            namespaces: namespaces,
            lastSynced: Date(),
            notes: notes.isEmpty ? nil : notes.joined(separator: "\n"),
            isConnected: true
        )
        cluster.customResources = await customResourcesTask
        return cluster
    }

    func loadNamespaceDetails(contextName: String, namespace: String) async throws -> Namespace {
        async let workloadsTask = loadWorkloads(contextName: contextName, namespace: namespace)
        async let podsTask = loadPods(contextName: contextName, namespace: namespace)
        async let eventsTask = loadEvents(contextName: contextName, namespace: namespace)
        async let configResourcesTask = loadConfigResources(contextName: contextName, namespace: namespace)
        async let servicesTask = fetchServices(contextName: contextName, namespace: namespace)
        async let ingressesTask = fetchIngresses(contextName: contextName, namespace: namespace)
        async let pvcTask = fetchPersistentVolumeClaims(contextName: contextName, namespace: namespace)
        async let serviceAccountsTask = fetchServiceAccounts(contextName: contextName, namespace: namespace)
        async let rolesTask = fetchRoles(contextName: contextName, namespace: namespace)
        async let roleBindingsTask = fetchRoleBindings(contextName: contextName, namespace: namespace)
        let workloads = try await workloadsTask
        let pods = try await podsTask
        let events = try await eventsTask
        let configResources = try await configResourcesTask
        var services = await servicesTask
        services = enrichServices(services, pods: pods, events: events)
        let ingresses = await ingressesTask
        let pvcs = await pvcTask
        let serviceAccounts = await serviceAccountsTask
        let roles = await rolesTask
        let roleBindings = await roleBindingsTask
        return Namespace(
            id: UUID(),
            name: namespace,
            workloads: workloads,
            pods: pods,
            events: events,
            alerts: workloads.compactMap { $0.alertMessage },
            configResources: configResources,
            services: services,
            ingresses: ingresses,
            persistentVolumeClaims: pvcs,
            serviceAccounts: serviceAccounts,
            roles: roles,
            roleBindings: roleBindings,
            isLoaded: true
        )
    }

    func loadPodDetail(contextName: String, namespace: String, pod: String) async throws -> PodDetailData {
        let detail: KubectlPodDetailObject = try await runner.runJSON(
            arguments: ["-n", namespace, "--context", contextName, "get", "pod", pod, "-o", "json", "--request-timeout=20s"],
            kubeconfigPath: kubeconfigPath
        )
        return detail.toPodDetailData()
    }

    private func enrichServices(_ services: [ServiceSummary], pods: [PodSummary], events: [EventSummary]) -> [ServiceSummary] {
        guard !services.isEmpty else { return services }
        let podsByName = Dictionary(uniqueKeysWithValues: pods.map { ($0.name, $0) })
        let lowercasedEvents = events.map { ($0, $0.message.lowercased()) }

        return services.map { summary in
            var enriched = summary
            enriched.endpointCount = Set(summary.targetPods).count

            let podLatencies: [TimeInterval] = summary.targetPods.compactMap { podName in
                guard let pod = podsByName[podName] else { return nil }
                return estimateLatency(for: pod)
            }

            let serviceName = summary.name.lowercased()
            let eventLatencies: [TimeInterval] = lowercasedEvents.compactMap { tuple in
                let (event, lowercasedMessage) = tuple
                guard lowercasedMessage.contains(serviceName) else { return nil }
                return parseLatency(from: event.message)
            }

            let combined = (podLatencies + eventLatencies).sorted()
            if !combined.isEmpty {
                enriched.latencyP50 = percentile(combined, quantile: 0.5)
                enriched.latencyP95 = percentile(combined, quantile: 0.95)
            } else {
                enriched.latencyP50 = nil
                enriched.latencyP95 = nil
            }
            return enriched
        }
    }

    private func estimateLatency(for pod: PodSummary) -> TimeInterval? {
        var samples: [Double] = []
        if let cpu = pod.cpuUsageRatio { samples.append(cpu) }
        if let memory = pod.memoryUsageRatio { samples.append(memory) }
        if let disk = pod.diskUsageRatio { samples.append(disk) }
        guard !samples.isEmpty else { return nil }

        let average = samples.reduce(0, +) / Double(samples.count)
        let warningPenalty = Double(min(pod.warningCount, 12)) * 0.01
        let restartPenalty = Double(min(pod.restarts, 20)) * 0.004
        let base: TimeInterval = 0.045
        let scaled = average * 0.25
        let estimate = base + scaled + warningPenalty + restartPenalty
        return min(max(estimate, base), 1.5)
    }

    private func parseLatency(from message: String) -> TimeInterval? {
        let range = NSRange(location: 0, length: message.utf16.count)
        guard let match = KubectlClusterService.latencyRegex.firstMatch(in: message, options: [], range: range) else {
            return nil
        }

        guard
            let valueRange = Range(match.range(at: 1), in: message),
            let unitRange = Range(match.range(at: 2), in: message),
            let value = Double(message[valueRange])
        else {
            return nil
        }

        let unit = message[unitRange].lowercased()
        if unit.hasPrefix("ms") || unit.contains("millisecond") {
            return value / 1_000
        } else {
            return value
        }
    }

    private func percentile(_ values: [Double], quantile: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        let clampedQuantile = min(max(quantile, 0), 1)
        if values.count == 1 { return values[0] }

        let position = clampedQuantile * Double(values.count - 1)
        let lowerIndex = Int(floor(position))
        let upperIndex = Int(ceil(position))
        if lowerIndex == upperIndex { return values[lowerIndex] }

        let lowerValue = values[lowerIndex]
        let upperValue = values[upperIndex]
        let fraction = position - Double(lowerIndex)
        return lowerValue + (upperValue - lowerValue) * fraction
    }

    func loadResourceYAML(contextName: String, namespace: String?, resourceType: String, name: String) async throws -> String {
        var arguments: [String] = ["--context", contextName, "get", resourceType, name, "-o", "yaml", "--request-timeout=20s"]
        if let namespace, !namespace.isEmpty {
            arguments.insert(contentsOf: ["-n", namespace], at: 2)
        }
        let output = try await runner.run(arguments: arguments, kubeconfigPath: kubeconfigPath)
        return output
    }

    private func identifier(for contextName: String) -> UUID {
        if let existing = contextIdentifiers[contextName] {
            return existing
        }
        let generated = UUID()
        contextIdentifiers[contextName] = generated
        return generated
    }

    private func loadWorkloads(contextName: String, namespace: String) async throws -> [WorkloadSummary] {
        async let deployments: [WorkloadSummary] = fetchDeployments(contextName: contextName, namespace: namespace)
        async let statefulSets: [WorkloadSummary] = fetchStatefulSets(contextName: contextName, namespace: namespace)
        async let daemonSets: [WorkloadSummary] = fetchDaemonSets(contextName: contextName, namespace: namespace)
        async let cronJobs: [WorkloadSummary] = fetchCronJobs(contextName: contextName, namespace: namespace)
        async let replicaSets: [WorkloadSummary] = fetchReplicaSets(contextName: contextName, namespace: namespace)
        async let replicationControllers: [WorkloadSummary] = fetchReplicationControllers(contextName: contextName, namespace: namespace)
        async let jobs: [WorkloadSummary] = fetchJobs(contextName: contextName, namespace: namespace)

        let merged = try await deployments
            + statefulSets
            + daemonSets
            + cronJobs
            + replicaSets
            + replicationControllers
            + jobs
        return merged.sorted { $0.name < $1.name }
    }

    private func fetchDeployments(contextName: String, namespace: String) async throws -> [WorkloadSummary] {
        let list: KubectlDeploymentList = try await runner.runJSON(arguments: ["-n", namespace, "--context", contextName, "get", "deployments", "-o", "json", "--request-timeout=20s"], kubeconfigPath: kubeconfigPath)
        let isoFormatter = ISO8601DateFormatter()
        return list.items.map { item in
            let desired = item.spec?.replicas ?? item.status?.replicas ?? 0
            let ready = item.status?.readyReplicas ?? 0
            let creationDate = item.metadata.creationTimestamp.flatMap { isoFormatter.date(from: $0) }
            return WorkloadSummary(
                id: UUID(),
                name: item.metadata.name,
                kind: .deployment,
                replicas: desired,
                readyReplicas: ready,
                status: WorkloadStatus.fromReady(total: desired, ready: ready),
                updatedReplicas: item.status?.updatedReplicas,
                availableReplicas: item.status?.availableReplicas,
                age: creationDate.map(EventAge.from)
            )
        }
    }

    private func fetchStatefulSets(contextName: String, namespace: String) async throws -> [WorkloadSummary] {
        let list: KubectlStatefulSetList = try await runner.runJSON(arguments: ["-n", namespace, "--context", contextName, "get", "statefulsets", "-o", "json", "--request-timeout=20s"], kubeconfigPath: kubeconfigPath)
        let isoFormatter = ISO8601DateFormatter()
        return list.items.map { item in
            let desired = item.spec?.replicas ?? item.status?.replicas ?? 0
            let ready = item.status?.readyReplicas ?? 0
            let creationDate = item.metadata.creationTimestamp.flatMap { isoFormatter.date(from: $0) }
            return WorkloadSummary(
                id: UUID(),
                name: item.metadata.name,
                kind: .statefulSet,
                replicas: desired,
                readyReplicas: ready,
                status: WorkloadStatus.fromReady(total: desired, ready: ready),
                updatedReplicas: item.status?.updatedReplicas,
                availableReplicas: item.status?.availableReplicas,
                age: creationDate.map(EventAge.from)
            )
        }
    }

    private func fetchDaemonSets(contextName: String, namespace: String) async throws -> [WorkloadSummary] {
        let list: KubectlDaemonSetList = try await runner.runJSON(arguments: ["-n", namespace, "--context", contextName, "get", "daemonsets", "-o", "json", "--request-timeout=20s"], kubeconfigPath: kubeconfigPath)
        let isoFormatter = ISO8601DateFormatter()
        return list.items.map { item in
            let desired = item.status?.desiredNumberScheduled ?? 0
            let ready = item.status?.numberReady ?? 0
            let creationDate = item.metadata.creationTimestamp.flatMap { isoFormatter.date(from: $0) }
            return WorkloadSummary(
                id: UUID(),
                name: item.metadata.name,
                kind: .daemonSet,
                replicas: desired,
                readyReplicas: ready,
                status: WorkloadStatus.fromReady(total: desired, ready: ready),
                updatedReplicas: item.status?.updatedNumberScheduled,
                availableReplicas: item.status?.numberAvailable,
                age: creationDate.map(EventAge.from)
            )
        }
    }

    private func fetchCronJobs(contextName: String, namespace: String) async throws -> [WorkloadSummary] {
        let list: KubectlCronJobList = try await runner.runJSON(arguments: ["-n", namespace, "--context", contextName, "get", "cronjobs", "-o", "json", "--request-timeout=20s"], kubeconfigPath: kubeconfigPath)
        let isoFormatter = ISO8601DateFormatter()
        return list.items.map { item in
            let creationDate = item.metadata.creationTimestamp.flatMap { isoFormatter.date(from: $0) }
            let suspended = item.spec?.suspend ?? false
            return WorkloadSummary(
                id: UUID(),
                name: item.metadata.name,
                kind: .cronJob,
                replicas: 0,
                readyReplicas: 0,
                status: suspended ? .degraded : .healthy,
                age: creationDate.map(EventAge.from),
                schedule: item.spec?.schedule,
                isSuspended: item.spec?.suspend
            )
        }
    }

    private func fetchReplicaSets(contextName: String, namespace: String) async throws -> [WorkloadSummary] {
        let list: KubectlReplicaSetList = try await runner.runJSON(arguments: ["-n", namespace, "--context", contextName, "get", "replicasets", "-o", "json", "--request-timeout=20s"], kubeconfigPath: kubeconfigPath)
        let isoFormatter = ISO8601DateFormatter()
        return list.items.map { item in
            let desired = item.spec?.replicas ?? item.status?.replicas ?? 0
            let ready = item.status?.readyReplicas ?? 0
            let creationDate = item.metadata.creationTimestamp.flatMap { isoFormatter.date(from: $0) }
            return WorkloadSummary(
                id: UUID(),
                name: item.metadata.name,
                kind: .replicaSet,
                replicas: desired,
                readyReplicas: ready,
                status: WorkloadStatus.fromReady(total: desired, ready: ready),
                updatedReplicas: item.status?.fullyLabeledReplicas,
                availableReplicas: item.status?.availableReplicas,
                age: creationDate.map(EventAge.from)
            )
        }
    }

    private func fetchReplicationControllers(contextName: String, namespace: String) async throws -> [WorkloadSummary] {
        let list: KubectlReplicationControllerList = try await runner.runJSON(arguments: ["-n", namespace, "--context", contextName, "get", "replicationcontrollers", "-o", "json", "--request-timeout=20s"], kubeconfigPath: kubeconfigPath)
        let isoFormatter = ISO8601DateFormatter()
        return list.items.map { item in
            let desired = item.spec?.replicas ?? item.status?.replicas ?? 0
            let ready = item.status?.readyReplicas ?? 0
            let creationDate = item.metadata.creationTimestamp.flatMap { isoFormatter.date(from: $0) }
            return WorkloadSummary(
                id: UUID(),
                name: item.metadata.name,
                kind: .replicationController,
                replicas: desired,
                readyReplicas: ready,
                status: WorkloadStatus.fromReady(total: desired, ready: ready),
                availableReplicas: item.status?.availableReplicas,
                age: creationDate.map(EventAge.from)
            )
        }
    }

    private func fetchJobs(contextName: String, namespace: String) async throws -> [WorkloadSummary] {
        let list: KubectlJobList = try await runner.runJSON(arguments: ["-n", namespace, "--context", contextName, "get", "jobs", "-o", "json", "--request-timeout=20s"], kubeconfigPath: kubeconfigPath)
        let isoFormatter = ISO8601DateFormatter()
        return list.items.map { item in
            let active = item.status?.active ?? 0
            let succeeded = item.status?.succeeded ?? 0
            let failed = item.status?.failed ?? 0
            let creationDate = item.metadata.creationTimestamp.flatMap { isoFormatter.date(from: $0) }

            let status: WorkloadStatus
            if failed > 0 {
                status = .failed
            } else if active > 0 {
                status = .progressing
            } else if succeeded > 0 {
                status = .healthy
            } else {
                status = .degraded
            }

            return WorkloadSummary(
                id: UUID(),
                name: item.metadata.name,
                kind: .job,
                replicas: succeeded + active,
                readyReplicas: succeeded,
                status: status,
                age: creationDate.map(EventAge.from),
                activeCount: active,
                succeededCount: succeeded,
                failedCount: failed
            )
        }
    }

    private func fetchServices(contextName: String, namespace: String) async -> [ServiceSummary] {
        do {
            let list: KubectlServiceList = try await runner.runJSON(
                arguments: ["-n", namespace, "--context", contextName, "get", "services", "-o", "json", "--request-timeout=20s"],
                kubeconfigPath: kubeconfigPath
            )
            let endpointMap = await fetchServiceEndpoints(contextName: contextName, namespace: namespace)
            let isoFormatter = ISO8601DateFormatter()
            return list.items.map { item in
                let creationDate = item.metadata.creationTimestamp.flatMap { isoFormatter.date(from: $0) }
                let ports = item.spec.ports.map { port in
                    let portNum = port.port.map { String($0) } ?? ""
                    let protocolString = port.protocol ?? ""
                    return protocolString.isEmpty ? portNum : "\(portNum)/\(protocolString)"
                }.joined(separator: ", ")
                let clusterIP = item.spec.clusterIP ?? "—"
                let targetPods = endpointMap[item.metadata.name] ?? []
                var summary = ServiceSummary(
                    name: item.metadata.name,
                    type: item.spec.type ?? "ClusterIP",
                    clusterIP: clusterIP,
                    ports: ports.isEmpty ? "—" : ports,
                    age: creationDate.map(EventAge.from),
                    selector: item.spec.selector ?? [:],
                    targetPods: targetPods
                )
                summary.endpointCount = Set(targetPods).count
                return summary
            }
        } catch {
            KubectlDefaults.debug("Failed to load services for namespace \(namespace): \(error)")
            return []
        }
    }

    private func fetchServiceEndpoints(contextName: String, namespace: String) async -> [String: [String]] {
        do {
            let list: KubectlEndpointList = try await runner.runJSON(
                arguments: ["-n", namespace, "--context", contextName, "get", "endpoints", "-o", "json", "--request-timeout=15s"],
                kubeconfigPath: kubeconfigPath
            )
            var mapping: [String: [String]] = [:]
            for item in list.items {
                let podNames = item.subsets?.flatMap { subset -> [String] in
                    subset.addresses?.compactMap { address in
                        guard address.targetRef?.kind?.lowercased() == "pod" else { return nil }
                        return address.targetRef?.name
                    } ?? []
                } ?? []
                if !podNames.isEmpty {
                    mapping[item.metadata.name, default: []] = Array(Set(podNames)).sorted()
                }
            }
            return mapping
        } catch {
            KubectlDefaults.debug("Failed to load endpoints for namespace \(namespace): \(error)")
            return [:]
        }
    }

    private func fetchIngresses(contextName: String, namespace: String) async -> [IngressSummary] {
        do {
            let list: KubectlIngressList = try await runner.runJSON(
                arguments: ["-n", namespace, "--context", contextName, "get", "ingresses", "-o", "json", "--request-timeout=20s"],
                kubeconfigPath: kubeconfigPath
            )
            let isoFormatter = ISO8601DateFormatter()
            return list.items.map { item in
                let creationDate = item.metadata.creationTimestamp.flatMap { isoFormatter.date(from: $0) }
                let hostRules = item.spec.rules.map { rule -> String in
                    let host = rule.host ?? "*"
                    let paths = rule.http?.paths.map { $0.path ?? "/" } ?? ["/"]
                    return "\(host) → \(paths.joined(separator: ", "))"
                }.joined(separator: " | ")
                let backends = item.spec.rules.flatMap { rule -> [String] in
                    rule.http?.paths.compactMap { path in
                        guard let service = path.backend.service else { return nil }
                        if let portNumber = service.port?.number {
                            return "\(service.name):\(portNumber)"
                        }
                        if let portName = service.port?.name {
                            return "\(service.name):\(portName)"
                        }
                        return service.name
                    } ?? []
                }.joined(separator: ", ")
                return IngressSummary(
                    name: item.metadata.name,
                    className: item.spec.ingressClassName,
                    hostRules: hostRules.isEmpty ? "—" : hostRules,
                    serviceTargets: backends.isEmpty ? "—" : backends,
                    tls: !(item.spec.tls?.isEmpty ?? true),
                    age: creationDate.map(EventAge.from)
                )
            }
        } catch {
            KubectlDefaults.debug("Failed to load ingresses for namespace \(namespace): \(error)")
            return []
        }
    }

    private func fetchPersistentVolumeClaims(contextName: String, namespace: String) async -> [PersistentVolumeClaimSummary] {
        do {
            let list: KubectlPVCList = try await runner.runJSON(
                arguments: ["-n", namespace, "--context", contextName, "get", "pvc", "-o", "json", "--request-timeout=20s"],
                kubeconfigPath: kubeconfigPath
            )
            let isoFormatter = ISO8601DateFormatter()
            return list.items.map { item in
                let creationDate = item.metadata.creationTimestamp.flatMap { isoFormatter.date(from: $0) }
                let capacity = item.status?.capacity?["storage"]
                let capacityDisplay = capacity.flatMap(parseMemoryQuantity).map(formatByteQuantity)
                return PersistentVolumeClaimSummary(
                    name: item.metadata.name,
                    status: item.status?.phase ?? "Unknown",
                    capacity: capacityDisplay,
                    storageClass: item.spec.storageClassName,
                    volumeName: item.spec.volumeName,
                    age: creationDate.map(EventAge.from)
                )
            }
        } catch {
            KubectlDefaults.debug("Failed to load PVCs for namespace \(namespace): \(error)")
            return []
        }
    }

    private func fetchServiceAccounts(contextName: String, namespace: String) async -> [ServiceAccountSummary] {
        do {
            let list: KubectlServiceAccountList = try await runner.runJSON(
                arguments: ["-n", namespace, "--context", contextName, "get", "serviceaccounts", "-o", "json", "--request-timeout=20s"],
                kubeconfigPath: kubeconfigPath
            )
            let isoFormatter = ISO8601DateFormatter()
            return list.items.map { item in
                let creationDate = item.metadata.creationTimestamp.flatMap { isoFormatter.date(from: $0) }
                return ServiceAccountSummary(
                    name: item.metadata.name,
                    secretCount: item.secrets?.count ?? 0,
                    age: creationDate.map(EventAge.from)
                )
            }
        } catch {
            KubectlDefaults.debug("Failed to load service accounts for namespace \(namespace): \(error)")
            return []
        }
    }

    private func fetchRoles(contextName: String, namespace: String) async -> [RoleSummary] {
        do {
            let list: KubectlRoleList = try await runner.runJSON(
                arguments: ["-n", namespace, "--context", contextName, "get", "roles", "-o", "json", "--request-timeout=20s"],
                kubeconfigPath: kubeconfigPath
            )
            let isoFormatter = ISO8601DateFormatter()
            return list.items.map { item in
                let creationDate = item.metadata.creationTimestamp.flatMap { isoFormatter.date(from: $0) }
                return RoleSummary(
                    name: item.metadata.name,
                    ruleCount: item.rules?.count ?? 0,
                    age: creationDate.map(EventAge.from)
                )
            }
        } catch {
            KubectlDefaults.debug("Failed to load roles for namespace \(namespace): \(error)")
            return []
        }
    }

    private func fetchRoleBindings(contextName: String, namespace: String) async -> [RoleBindingSummary] {
        do {
            let list: KubectlRoleBindingList = try await runner.runJSON(
                arguments: ["-n", namespace, "--context", contextName, "get", "rolebindings", "-o", "json", "--request-timeout=20s"],
                kubeconfigPath: kubeconfigPath
            )
            let isoFormatter = ISO8601DateFormatter()
            return list.items.map { item in
                let creationDate = item.metadata.creationTimestamp.flatMap { isoFormatter.date(from: $0) }
                let roleRef = "\(item.roleRef.kind)/\(item.roleRef.name)"
                return RoleBindingSummary(
                    name: item.metadata.name,
                    subjectCount: item.subjects?.count ?? 0,
                    roleRef: roleRef,
                    age: creationDate.map(EventAge.from)
                )
            }
        } catch {
            KubectlDefaults.debug("Failed to load role bindings for namespace \(namespace): \(error)")
            return []
        }
    }

    private func fetchCustomResourceDefinitions(contextName: String) async -> [CustomResourceDefinitionSummary] {
        do {
            let list: KubectlCRDList = try await runner.runJSON(
                arguments: ["--context", contextName, "get", "customresourcedefinitions", "-o", "json", "--request-timeout=20s"],
                kubeconfigPath: kubeconfigPath
            )
            let isoFormatter = ISO8601DateFormatter()
            return list.items.map { item in
                let creationDate = item.metadata.creationTimestamp.flatMap { isoFormatter.date(from: $0) }
                return CustomResourceDefinitionSummary(
                    name: item.metadata.name,
                    group: item.spec.group,
                    version: item.spec.versions.first?.name ?? item.spec.version ?? "",
                    kind: item.spec.names.kind,
                    scope: item.spec.scope,
                    shortNames: item.spec.names.shortNames ?? [],
                    age: creationDate.map(EventAge.from)
                )
            }
        } catch {
            KubectlDefaults.debug("Failed to load CRDs: \(error)")
            return []
        }
    }

    private func loadPods(contextName: String, namespace: String) async throws -> [PodSummary] {
        let list: KubectlPodList = try await runner.runJSON(arguments: ["-n", namespace, "--context", contextName, "get", "pods", "-o", "json", "--request-timeout=20s"], kubeconfigPath: kubeconfigPath)
        let metricsByPod = (try? await loadPodMetrics(contextName: contextName, namespace: namespace)) ?? [:]
        let diskUsageByPod = await loadPodFilesystemUsage(contextName: contextName, namespace: namespace, pods: list.items)
        let isoFormatter = ISO8601DateFormatter()
        return list.items.map { item in
            let namespaceName = item.metadata.namespace ?? namespace
            let containerNames = item.spec?.containers.map { $0.name } ?? []
            let totalContainers = containerNames.count
            let containerStatuses = item.status?.containerStatuses ?? []
            let readyCount = containerStatuses.filter { $0.ready }.count
            let restarts = containerStatuses.reduce(0) { $0 + ($1.restartCount ?? 0) }
            let warningCount = containerStatuses.filter { !$0.ready || ($0.restartCount ?? 0) > 0 }.count
            let owner = item.metadata.ownerReferences?.first
            let controlledBy: String? = {
                guard let kind = owner?.kind, !kind.isEmpty else { return owner?.name }
                guard let name = owner?.name, !name.isEmpty else { return kind }
                return "\(kind)/\(name)"
            }()
            let creationDate = item.metadata.creationTimestamp.flatMap { isoFormatter.date(from: $0) }
            let age = creationDate.map { EventAge.from(date: $0) }

            let containerResources = item.spec?.containers ?? []
            let resourceTotals = aggregateResources(for: containerResources)
            let metrics = metricsByPod[item.metadata.name]
            let cpuUsageDisplay = formatPodCPUDisplay(usage: metrics?.cpuCores, request: resourceTotals.cpuRequest, limit: resourceTotals.cpuLimit)
            let cpuRatio = computeUsageRatio(usage: metrics?.cpuCores, request: resourceTotals.cpuRequest, limit: resourceTotals.cpuLimit)
            let memoryUsageDisplay = formatPodMemoryDisplay(usage: metrics?.memoryBytes, request: resourceTotals.memoryRequest, limit: resourceTotals.memoryLimit)
            let memoryRatio = computeUsageRatio(usage: metrics?.memoryBytes, request: resourceTotals.memoryRequest, limit: resourceTotals.memoryLimit)
            let diskUsageBytes = diskUsageByPod["\(namespaceName)/\(item.metadata.name)"]
            let diskUsageDisplay = formatPodDiskDisplay(usage: diskUsageBytes, request: resourceTotals.storageRequest, limit: resourceTotals.storageLimit)
            let diskRatio = computeUsageRatio(usage: diskUsageBytes, request: resourceTotals.storageRequest, limit: resourceTotals.storageLimit)

            return PodSummary(
                id: UUID(),
                name: item.metadata.name,
                namespace: namespaceName,
                phase: PodPhase(rawValue: item.status?.phase?.lowercased() ?? "unknown") ?? .unknown,
                readyContainers: readyCount,
                totalContainers: totalContainers,
                restarts: restarts,
                nodeName: item.spec?.nodeName ?? "",
                containerNames: containerNames,
                warningCount: warningCount,
                controlledBy: controlledBy,
                qosClass: item.status?.qosClass,
                age: age,
                cpuUsage: cpuUsageDisplay,
                memoryUsage: memoryUsageDisplay,
                diskUsage: diskUsageDisplay,
                cpuUsageRatio: cpuRatio,
                memoryUsageRatio: memoryRatio,
                diskUsageRatio: diskRatio
            )
        }
    }

    private func loadEvents(contextName: String, namespace: String) async throws -> [EventSummary] {
        let list: KubectlEventList = try await runner.runJSON(arguments: ["-n", namespace, "--context", contextName, "get", "events", "-o", "json", "--request-timeout=20s"], kubeconfigPath: kubeconfigPath)
        let isoFormatter = ISO8601DateFormatter()
        let now = Date()
        return list.items.map { item in
            let eventDate = item.parsedTimestamp(using: isoFormatter)
            return EventSummary(
                id: UUID(),
                message: item.message,
                type: EventType(rawValue: item.type?.lowercased() ?? "normal") ?? .normal,
                count: item.count ?? 1,
                age: eventDate.map(EventAge.from) ?? item.relativeAge(now: now, formatter: isoFormatter),
                timestamp: eventDate
            )
        }.sorted { $0.count > $1.count }
    }

    private func loadConfigResources(contextName: String, namespace: String) async throws -> [ConfigResourceSummary] {
        async let configMapsTask = fetchConfigMaps(contextName: contextName, namespace: namespace)
        async let secretsTask = fetchSecrets(contextName: contextName, namespace: namespace)
        async let quotasTask = fetchResourceQuotas(contextName: contextName, namespace: namespace)
        async let limitsTask = fetchLimitRanges(contextName: contextName, namespace: namespace)

        let configMaps = try await configMapsTask
        let secrets = try await secretsTask
        let quotas = try await quotasTask
        let limitRanges = try await limitsTask

        return (configMaps + secrets + quotas + limitRanges).sorted { $0.name < $1.name }
    }

    private func fetchConfigMaps(contextName: String, namespace: String) async throws -> [ConfigResourceSummary] {
        let list: KubectlConfigMapList = try await runner.runJSON(
            arguments: ["-n", namespace, "--context", contextName, "get", "configmaps", "-o", "json", "--request-timeout=20s"],
            kubeconfigPath: kubeconfigPath
        )
        let isoFormatter = ISO8601DateFormatter()
        return list.items.map { item in
            let immutableFlag = item.immutable == true
            let binaryCount = item.binaryData?.count ?? 0
            let totalDataCount = (item.data?.count ?? 0) + binaryCount
            var summaryParts: [String] = []
            if immutableFlag { summaryParts.append("Immutable") }
            if binaryCount > 0 { summaryParts.append("Binary: \(binaryCount)") }
            let creationDate = item.metadata.creationTimestamp.flatMap { isoFormatter.date(from: $0) }
            return ConfigResourceSummary(
                id: UUID(),
                name: item.metadata.name,
                kind: .configMap,
                typeDescription: "ConfigMap",
                dataCount: totalDataCount > 0 ? totalDataCount : nil,
                summary: summaryParts.isEmpty ? nil : summaryParts.joined(separator: " · "),
                age: creationDate.map(EventAge.from),
                permissions: .fullAccess
            )
        }
    }

    private func fetchSecrets(contextName: String, namespace: String) async throws -> [ConfigResourceSummary] {
        let list: KubectlSecretList = try await runner.runJSON(
            arguments: ["-n", namespace, "--context", contextName, "get", "secrets", "-o", "json", "--request-timeout=20s"],
            kubeconfigPath: kubeconfigPath
        )
        let isoFormatter = ISO8601DateFormatter()
        let secretNames = list.items.map { $0.metadata.name }
        let permissions = await fetchSecretPermissions(contextName: contextName, namespace: namespace, names: secretNames)
        return list.items.map { item in
            let immutableFlag = item.immutable == true
            let dataCount = item.data?.count ?? 0
            var summaryParts: [String] = []
            if immutableFlag { summaryParts.append("Immutable") }
            let creationDate = item.metadata.creationTimestamp.flatMap { isoFormatter.date(from: $0) }
            let secretEntries: [SecretDataEntry]? = item.data.map { data in
                data.sorted { $0.key < $1.key }.map { key, value in
                    SecretDataEntry(key: key, encodedValue: value)
                }
            }
            let permission = permissions[item.metadata.name] ?? .fullAccess
            return ConfigResourceSummary(
                id: UUID(),
                name: item.metadata.name,
                kind: .secret,
                typeDescription: item.type ?? "Opaque",
                dataCount: dataCount > 0 ? dataCount : nil,
                summary: summaryParts.isEmpty ? nil : summaryParts.joined(separator: " · "),
                age: creationDate.map(EventAge.from),
                secretEntries: secretEntries,
                permissions: permission
            )
        }
    }

    private func fetchResourceQuotas(contextName: String, namespace: String) async throws -> [ConfigResourceSummary] {
        let list: KubectlResourceQuotaList = try await runner.runJSON(
            arguments: ["-n", namespace, "--context", contextName, "get", "resourcequotas", "-o", "json", "--request-timeout=20s"],
            kubeconfigPath: kubeconfigPath
        )
        let isoFormatter = ISO8601DateFormatter()
        return list.items.map { item in
            let hard = item.status?.hard ?? [:]
            let creationDate = item.metadata.creationTimestamp.flatMap { isoFormatter.date(from: $0) }
            let details = formatKeyValueSummary(hard)
            return ConfigResourceSummary(
                id: UUID(),
                name: item.metadata.name,
                kind: .resourceQuota,
                typeDescription: "ResourceQuota",
                dataCount: hard.isEmpty ? nil : hard.count,
                summary: details,
                age: creationDate.map(EventAge.from),
                permissions: .fullAccess
            )
        }
    }

    private func fetchLimitRanges(contextName: String, namespace: String) async throws -> [ConfigResourceSummary] {
        let list: KubectlLimitRangeList = try await runner.runJSON(
            arguments: ["-n", namespace, "--context", contextName, "get", "limitranges", "-o", "json", "--request-timeout=20s"],
            kubeconfigPath: kubeconfigPath
        )
        let isoFormatter = ISO8601DateFormatter()
        return list.items.map { item in
            let limits = item.spec?.limits ?? []
            let creationDate = item.metadata.creationTimestamp.flatMap { isoFormatter.date(from: $0) }
            let types = limits.compactMap { $0.type }.joined(separator: ", ")
            var details: String? = nil
            if let first = limits.first {
                let defaults = first.default?.map { "\($0.key)=\($0.value)" } ?? []
                if !defaults.isEmpty {
                    let prefix = first.type.map { "\($0): " } ?? ""
                    details = prefix + defaults.joined(separator: ", ")
                }
            }
            return ConfigResourceSummary(
                id: UUID(),
                name: item.metadata.name,
                kind: .limitRange,
                typeDescription: types.isEmpty ? "LimitRange" : types,
                dataCount: limits.isEmpty ? nil : limits.count,
                summary: details,
                age: creationDate.map(EventAge.from),
                permissions: .fullAccess
            )
        }
    }

    private func fetchSecretPermissions(contextName: String, namespace: String, names: [String]) async -> [String: ConfigResourcePermissions] {
        guard !names.isEmpty else { return [:] }

        let cacheKey = SecretPermissionCacheKey(context: contextName, namespace: namespace)
        let now = Date()

        var cachedPermissions: [String: ConfigResourcePermissions] = [:]
        if let entry = secretPermissionCache[cacheKey], now.timeIntervalSince(entry.timestamp) < secretPermissionCacheTTL {
            cachedPermissions = entry.permissions
        } else {
            secretPermissionCache.removeValue(forKey: cacheKey)
        }

        var result: [String: ConfigResourcePermissions] = [:]
        let cachedNames = names.filter { cachedPermissions[$0] != nil }
        for name in cachedNames {
            if let permissions = cachedPermissions[name] {
                result[name] = permissions
            }
        }

        let missing = names.filter { cachedPermissions[$0] == nil }
        guard !missing.isEmpty else { return result }

        let runner = self.runner
        let kubeconfigPath = self.kubeconfigPath

        let fetched = await withTaskGroup(of: (String, ConfigResourcePermissions).self) { group -> [String: ConfigResourcePermissions] in
            for name in missing {
                group.addTask {
                    do {
                        let canReveal = try await runner.run(
                            arguments: [
                                "auth",
                                "can-i",
                                "get",
                                "secret/\(name)",
                                "--namespace",
                                namespace,
                                "--context",
                                contextName
                            ],
                            kubeconfigPath: kubeconfigPath
                        ).trimmingCharacters(in: .whitespacesAndNewlines).lowercased().hasPrefix("y")

                        let canEdit = try await runner.run(
                            arguments: [
                                "auth",
                                "can-i",
                                "update",
                                "secret/\(name)",
                                "--namespace",
                                namespace,
                                "--context",
                                contextName
                            ],
                            kubeconfigPath: kubeconfigPath
                        ).trimmingCharacters(in: .whitespacesAndNewlines).lowercased().hasPrefix("y")

                        return (name, ConfigResourcePermissions(canReveal: canReveal, canEdit: canEdit))
                    } catch {
                        return (name, ConfigResourcePermissions(canReveal: false, canEdit: false))
                    }
                }
            }

            var collected: [String: ConfigResourcePermissions] = [:]
            for await item in group {
                collected[item.0] = item.1
            }
            return collected
        }

        if !fetched.isEmpty {
            var entry = secretPermissionCache[cacheKey] ?? SecretPermissionCacheEntry(timestamp: now, permissions: [:])
            entry.timestamp = now
            entry.permissions.merge(fetched) { _, new in new }
            secretPermissionCache[cacheKey] = entry
            result.merge(fetched) { _, new in new }
        }

        return result
    }

    private func formatKeyValueSummary(_ dictionary: [String: String]) -> String? {
        guard !dictionary.isEmpty else { return nil }
        let sorted = dictionary.sorted { $0.key < $1.key }
        let leading = sorted.prefix(3).map { "\($0.key)=\($0.value)" }
        var components = Array(leading)
        if dictionary.count > leading.count {
            components.append("+\(dictionary.count - leading.count) more")
        }
        return components.joined(separator: ", ")
    }

    private func loadNodeData(contextName: String) async throws -> (summary: NodeSummary, nodes: [NodeInfo]) {
        let list: KubectlNodeList = try await runner.runJSON(
            arguments: ["--context", contextName, "get", "nodes", "-o", "json", "--request-timeout=15s"],
            kubeconfigPath: kubeconfigPath
        )

        let metricsByNode = (try? await loadNodeMetrics(contextName: contextName)) ?? [:]
        let nodeNames = list.items.map { $0.metadata.name }
        let statsSummaries = await loadNodeStatsSummaries(contextName: contextName, nodeNames: nodeNames)
        let isoFormatter = ISO8601DateFormatter()

        var nodes: [NodeInfo] = []
        var cpuRatios: [Double] = []
        var memoryRatios: [Double] = []
        var diskRatios: [Double] = []
        var totalNetworkReceive: Double = 0
        var totalNetworkTransmit: Double = 0
        var hasNetworkSample = false

        for item in list.items {
            let metrics = metricsByNode[item.metadata.name]
            let cpuCapacity = item.status.capacity?["cpu"].flatMap(parseCPUQuantity)
            let memoryCapacity = item.status.capacity?["memory"].flatMap(parseMemoryQuantity)
            let diskCapacity = item.status.capacity?["ephemeral-storage"].flatMap(parseMemoryQuantity)
            let stats = statsSummaries[item.metadata.name]

            let cpuUsageResult = formatCPUUsage(usage: metrics?.cpuCores, capacity: cpuCapacity)
            if let ratio = cpuUsageResult.ratio {
                cpuRatios.append(ratio)
            }

            let memoryUsageResult = formatMemoryUsage(usage: metrics?.memoryBytes, capacity: memoryCapacity)
            if let ratio = memoryUsageResult.ratio {
                memoryRatios.append(ratio)
            }

            let creationDate = item.metadata.creationTimestamp.flatMap { isoFormatter.date(from: $0) }
            let conditions = item.status.conditions.map {
                NodeCondition(type: $0.type, status: $0.status, reason: $0.reason, message: $0.message)
            }
            let warnings = conditions.filter { $0.status.lowercased() != "true" }.count
            let taints = item.spec?.taints?.map(formatTaint) ?? []
            let version = item.status.nodeInfo?.kubeletVersion ?? "—"

            var diskDisplay: String?
            var diskRatio: Double?
            if let fs = stats?.node.fs,
               let used = fs.usedBytes,
               let capacity = fs.capacityBytes,
               capacity > 0 {
                diskRatio = min(max(used / capacity, 0), 1)
                diskDisplay = formatDiskUsageDisplay(used: used, capacity: capacity)
                if let ratio = diskRatio {
                    diskRatios.append(ratio)
                }
            } else if let diskCapacity {
                diskDisplay = formatByteQuantity(diskCapacity)
            }

            var networkReceive: Double?
            var networkTransmit: Double?
            if let network = stats?.node.network {
                networkReceive = network.rxBytes
                networkTransmit = network.txBytes
                if let rx = networkReceive {
                    totalNetworkReceive += rx
                    hasNetworkSample = true
                }
                if let tx = networkTransmit {
                    totalNetworkTransmit += tx
                    hasNetworkSample = true
                }
            }

            let node = NodeInfo(
                id: UUID(),
                name: item.metadata.name,
                warningCount: warnings,
                cpuUsage: cpuUsageResult.display,
                cpuUsageRatio: cpuUsageResult.ratio,
                memoryUsage: memoryUsageResult.display,
                memoryUsageRatio: memoryUsageResult.ratio,
                diskUsage: diskDisplay,
                diskRatio: diskRatio,
                networkReceiveBytes: networkReceive,
                networkTransmitBytes: networkTransmit,
                taints: taints,
                kubeletVersion: version,
                age: creationDate.map(EventAge.from),
                conditions: conditions
            )
            nodes.append(node)
        }

        let total = nodes.count
        let ready = list.items.filter { item in
            item.status.conditions.contains { $0.type == "Ready" && $0.status == "True" }
        }.count

        let averageCPU = cpuRatios.isEmpty ? nil : min(max(cpuRatios.reduce(0, +) / Double(cpuRatios.count), 0), 1)
        let averageMemory = memoryRatios.isEmpty ? nil : min(max(memoryRatios.reduce(0, +) / Double(memoryRatios.count), 0), 1)

        let averageDisk = diskRatios.isEmpty ? nil : min(max(diskRatios.reduce(0, +) / Double(diskRatios.count), 0), 1)
        let aggregatedNetworkReceive = hasNetworkSample ? totalNetworkReceive : nil
        let aggregatedNetworkTransmit = hasNetworkSample ? totalNetworkTransmit : nil
        let summary = NodeSummary(
            total: total,
            ready: ready,
            cpuUsage: averageCPU,
            memoryUsage: averageMemory,
            diskUsage: averageDisk,
            networkReceiveBytes: aggregatedNetworkReceive,
            networkTransmitBytes: aggregatedNetworkTransmit
        )
        return (summary, nodes.sorted { $0.name < $1.name })
    }

    func invalidateNodeCache(contextName: String) {
        nodeStatsCache.removeValue(forKey: contextName)
    }
#if DEBUG
    func _test_loadNodeData(contextName: String) async throws -> (summary: NodeSummary, nodes: [NodeInfo]) {
        try await loadNodeData(contextName: contextName)
    }

    func _test_loadPods(contextName: String, namespace: String) async throws -> [PodSummary] {
        try await loadPods(contextName: contextName, namespace: namespace)
    }

    func _test_fetchSecretPermissions(contextName: String, namespace: String, names: [String]) async -> [String: ConfigResourcePermissions] {
        await fetchSecretPermissions(contextName: contextName, namespace: namespace, names: names)
    }
#endif

    func updateSecret(
        contextName: String,
        namespace: String,
        name: String,
        type: String?,
        encodedData: [String: String]
    ) async throws -> String {
        var manifest: [String: Any] = [
            "apiVersion": "v1",
            "kind": "Secret",
            "metadata": [
                "name": name,
                "namespace": namespace
            ],
            "data": encodedData
        ]
        if let type {
            manifest["type"] = type
        }

        let jsonData = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted])
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("kubex-secret-\(UUID().uuidString).json")
        try jsonData.write(to: tempURL, options: .atomic)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let output = try await runner.run(
            arguments: ["apply", "-f", tempURL.path, "--context", contextName],
            kubeconfigPath: kubeconfigPath
        )
        return output
    }

    func applyResourceYAML(contextName: String, manifestYAML: String) async throws -> String {
        let trimmed = manifestYAML.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw KubectlError(message: "Manifest is empty; nothing to apply.")
        }

        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("kubex-manifest-\(UUID().uuidString).yaml")
        do {
            try manifestYAML.write(to: tempURL, atomically: true, encoding: .utf8)
        } catch {
            throw KubectlError(message: "Failed to write manifest: \(error.localizedDescription)")
        }
        defer { try? FileManager.default.removeItem(at: tempURL) }

        return try await runner.run(
            arguments: ["apply", "-f", tempURL.path, "--context", contextName],
            kubeconfigPath: kubeconfigPath
        )
    }

    private func loadNodeMetrics(contextName: String) async throws -> [String: NodeMetrics] {
        let metrics: MetricsNodeList = try await runner.runJSON(
            arguments: ["--context", contextName, "get", "--raw", "/apis/metrics.k8s.io/v1beta1/nodes"],
            kubeconfigPath: kubeconfigPath
        )

        var result: [String: NodeMetrics] = [:]
        for item in metrics.items {
            let cpu = item.usage.cpu.flatMap(parseCPUQuantity)
            let memory = item.usage.memory.flatMap(parseMemoryQuantity)
            result[item.metadata.name] = NodeMetrics(cpuCores: cpu, memoryBytes: memory)
        }
        return result
    }

    private func loadNodeStatsSummaries(contextName: String, nodeNames: [String]) async -> [String: NodeStatsSummary] {
        guard !nodeNames.isEmpty else { return [:] }
        let requested = Set(nodeNames)
        let now = Date()

        if var cache = nodeStatsCache[contextName], now.timeIntervalSince(cache.timestamp) < nodeStatsCacheTTL {
            let cachedKeys = Set(cache.summaries.keys)
            let missing = requested.subtracting(cachedKeys)
            if missing.isEmpty {
                return cache.summaries
            }
            let fetched = await fetchNodeStatsSummaries(contextName: contextName, nodeNames: Array(missing))
            if !fetched.isEmpty {
                cache.summaries.merge(fetched) { _, new in new }
                cache.timestamp = now
                nodeStatsCache[contextName] = cache
            }
            return cache.summaries
        }

        let fetched = await fetchNodeStatsSummaries(contextName: contextName, nodeNames: Array(requested))
        nodeStatsCache[contextName] = NodeStatsCacheEntry(timestamp: now, summaries: fetched)
        return fetched
    }

    private func fetchNodeStatsSummaries(contextName: String, nodeNames: [String]) async -> [String: NodeStatsSummary] {
        guard !nodeNames.isEmpty else { return [:] }
        let runner = self.runner
        let kubeconfigPath = self.kubeconfigPath
        return await withTaskGroup(of: (String, NodeStatsSummary?)?.self) { group -> [String: NodeStatsSummary] in
            for name in nodeNames {
                group.addTask {
                    do {
                        let summary: NodeStatsSummary = try await runner.runJSON(
                            arguments: ["--context", contextName, "get", "--raw", "/api/v1/nodes/\(name)/proxy/stats/summary"],
                            kubeconfigPath: kubeconfigPath
                        )
                        return (name, summary)
                    } catch {
                        return nil
                    }
                }
            }

            var result: [String: NodeStatsSummary] = [:]
            for await entry in group {
                if let (name, summary) = entry, let summary {
                    result[name] = summary
                }
            }
            return result
        }
    }

    private func loadNodeFilesystemUsage(contextName: String, nodeNames: [String]) async -> [String: (used: Double, capacity: Double)] {
        let summaries = await loadNodeStatsSummaries(contextName: contextName, nodeNames: nodeNames)
        var result: [String: (Double, Double)] = [:]
        for (name, summary) in summaries {
            if let used = summary.node.fs?.usedBytes, let capacity = summary.node.fs?.capacityBytes {
                result[name] = (Double(used), Double(capacity))
            }
        }
        return result
    }

    private func loadPodFilesystemUsage(contextName: String, namespace: String, pods: [KubectlPodList.Item]) async -> [String: Double] {
        let nodeNames = Set(pods.compactMap { $0.spec?.nodeName })
        guard !nodeNames.isEmpty else { return [:] }
        let summaries = await loadNodeStatsSummaries(contextName: contextName, nodeNames: Array(nodeNames))
        var usage: [String: Double] = [:]
        let targetKeys: Set<String> = Set(pods.map { item in
            let namespaceName = item.metadata.namespace ?? namespace
            return "\(namespaceName)/\(item.metadata.name)"
        })

        for summary in summaries.values {
            guard let podStats = summary.pods else { continue }
            for pod in podStats {
                let key = "\(pod.podRef.namespace)/\(pod.podRef.name)"
                guard targetKeys.contains(key) else { continue }
                var totalUsed: Double = 0
                if let containers = pod.containers {
                    for container in containers {
                        totalUsed += container.rootfs?.usedBytes ?? 0
                        totalUsed += container.logs?.usedBytes ?? 0
                    }
                }
                if let volumes = pod.volumes {
                    for volume in volumes {
                        totalUsed += volume.usedBytes ?? 0
                    }
                }
                if totalUsed > 0 {
                    usage[key] = totalUsed
                }
            }
        }
        return usage
    }

    private func formatDiskUsageDisplay(used: Double, capacity: Double) -> String {
        guard capacity > 0 else { return "—" }
        let percent = Self.percentFormatter.string(from: NSNumber(value: min(max(used / capacity, 0), 1))) ?? ""
        let usedString = formatByteQuantity(used)
        let capString = formatByteQuantity(capacity)
        return "\(usedString) / \(capString) (\(percent))"
    }

    private func formatCPUUsage(usage: Double?, capacity: Double?) -> (display: String?, ratio: Double?) {
        guard let usage else { return (nil, nil) }
        if let capacity, capacity > 0 {
            let rawRatio = usage / capacity
            let ratio = min(max(rawRatio, 0), 1)
            let percent = Self.percentFormatter.string(from: NSNumber(value: ratio)) ?? ""
            let usageString = Self.cpuNumberFormatter.string(from: NSNumber(value: usage)) ?? String(format: "%.2f", usage)
            return ("\(percent) (\(usageString) cores)", ratio)
        }
        let usageString = Self.cpuNumberFormatter.string(from: NSNumber(value: usage)) ?? String(format: "%.2f", usage)
        return ("\(usageString) cores", nil)
    }

    private func formatMemoryUsage(usage: Double?, capacity: Double?) -> (display: String?, ratio: Double?) {
        guard let usage else { return (nil, nil) }
        let usageString = formatByteQuantity(usage)
        if let capacity, capacity > 0 {
            let rawRatio = usage / capacity
            let ratio = min(max(rawRatio, 0), 1)
            let percent = Self.percentFormatter.string(from: NSNumber(value: ratio)) ?? ""
            return ("\(percent) (\(usageString))", ratio)
        }
        return (usageString, nil)
    }

    private func formatByteQuantity(_ value: Double) -> String {
        Self.byteFormatter.string(fromByteCount: Int64(value))
    }

    private func formatTaint(_ taint: KubectlNodeList.Item.Spec.Taint) -> String {
        var result = taint.key
        if let value = taint.value, !value.isEmpty {
            result += "=\(value)"
        }
        if let effect = taint.effect, !effect.isEmpty {
            result += ":\(effect)"
        }
        return result
    }

    private struct AggregatedResources {
        let cpuRequest: Double?
        let cpuLimit: Double?
        let memoryRequest: Double?
        let memoryLimit: Double?
        let storageRequest: Double?
        let storageLimit: Double?
    }

    private func aggregateResources(for containers: [KubectlPodList.Item.Spec.Container]) -> AggregatedResources {
        var cpuRequest: Double = 0
        var cpuLimit: Double = 0
        var memoryRequest: Double = 0
        var memoryLimit: Double = 0
        var storageRequest: Double = 0
        var storageLimit: Double = 0
        var hasCPURequest = false
        var hasCPULimit = false
        var hasMemoryRequest = false
        var hasMemoryLimit = false
        var hasStorageRequest = false
        var hasStorageLimit = false

        for container in containers {
            if let requestCPU = container.resources?.requests?["cpu"], let value = parseCPUQuantity(requestCPU) {
                cpuRequest += value
                hasCPURequest = true
            }
            if let limitCPU = container.resources?.limits?["cpu"], let value = parseCPUQuantity(limitCPU) {
                cpuLimit += value
                hasCPULimit = true
            }
            if let requestMem = container.resources?.requests?["memory"], let value = parseMemoryQuantity(requestMem) {
                memoryRequest += value
                hasMemoryRequest = true
            }
            if let limitMem = container.resources?.limits?["memory"], let value = parseMemoryQuantity(limitMem) {
                memoryLimit += value
                hasMemoryLimit = true
            }
            if let requestStorage = container.resources?.requests?["ephemeral-storage"], let value = parseMemoryQuantity(requestStorage) {
                storageRequest += value
                hasStorageRequest = true
            }
            if let limitStorage = container.resources?.limits?["ephemeral-storage"], let value = parseMemoryQuantity(limitStorage) {
                storageLimit += value
                hasStorageLimit = true
            }
        }

        return AggregatedResources(
            cpuRequest: hasCPURequest ? cpuRequest : nil,
            cpuLimit: hasCPULimit ? cpuLimit : nil,
            memoryRequest: hasMemoryRequest ? memoryRequest : nil,
            memoryLimit: hasMemoryLimit ? memoryLimit : nil,
            storageRequest: hasStorageRequest ? storageRequest : nil,
            storageLimit: hasStorageLimit ? storageLimit : nil
        )
    }

    private func loadPodMetrics(contextName: String, namespace: String) async throws -> [String: PodMetrics] {
        let metrics: PodMetricsList = try await runner.runJSON(
            arguments: [
                "--context", contextName,
                "get", "--raw",
                "/apis/metrics.k8s.io/v1beta1/namespaces/\(namespace)/pods"
            ],
            kubeconfigPath: kubeconfigPath
        )

        var result: [String: PodMetrics] = [:]
        for item in metrics.items {
            var cpuTotal: Double = 0
            var memTotal: Double = 0
            var hasCPU = false
            var hasMemory = false
            for container in item.containers {
                if let cpu = container.usage["cpu"], let value = parseCPUQuantity(cpu) {
                    cpuTotal += value
                    hasCPU = true
                }
                if let memory = container.usage["memory"], let value = parseMemoryQuantity(memory) {
                    memTotal += value
                    hasMemory = true
                }
            }
            result[item.metadata.name] = PodMetrics(
                cpuCores: hasCPU ? cpuTotal : nil,
                memoryBytes: hasMemory ? memTotal : nil
            )
        }
        return result
    }

    private func formatPodCPUDisplay(usage: Double?, request: Double?, limit: Double?) -> String? {
        guard let usage else { return nil }
        let usageString = Self.cpuDisplayString(for: usage)
        if let limit, limit > 0 {
            let ratio = min(max(usage / limit, 0), 1)
            let percent = Self.percentFormatter.string(from: NSNumber(value: ratio)) ?? ""
            return "\(usageString) (\(percent) of limit)"
        }
        if let request, request > 0 {
            let ratio = min(max(usage / request, 0), 1)
            let percent = Self.percentFormatter.string(from: NSNumber(value: ratio)) ?? ""
            return "\(usageString) (\(percent) of request)"
        }
        return usageString
    }

    private func formatPodMemoryDisplay(usage: Double?, request: Double?, limit: Double?) -> String? {
        guard let usage else { return nil }
        let usageString = formatByteQuantity(usage)
        if let limit, limit > 0 {
            let ratio = min(max(usage / limit, 0), 1)
            let percent = Self.percentFormatter.string(from: NSNumber(value: ratio)) ?? ""
            return "\(usageString) (\(percent) of limit)"
        }
        if let request, request > 0 {
            let ratio = min(max(usage / request, 0), 1)
            let percent = Self.percentFormatter.string(from: NSNumber(value: ratio)) ?? ""
            return "\(usageString) (\(percent) of request)"
        }
        return usageString
    }

    private func formatPodDiskDisplay(usage: Double?, request: Double?, limit: Double?) -> String? {
        if let usage {
            let usageString = formatByteQuantity(usage)
            if let limit, limit > 0 {
                let ratio = min(max(usage / limit, 0), 1)
                let percent = Self.percentFormatter.string(from: NSNumber(value: ratio)) ?? ""
                return "\(usageString) / \(formatByteQuantity(limit)) (\(percent) of limit)"
            }
            if let request, request > 0 {
                let ratio = min(max(usage / request, 0), 1)
                let percent = Self.percentFormatter.string(from: NSNumber(value: ratio)) ?? ""
                return "\(usageString) / \(formatByteQuantity(request)) (\(percent) of request)"
            }
            return usageString
        }
        if let limit, limit > 0 {
            return "limit \(formatByteQuantity(limit))"
        }
        if let request, request > 0 {
            return "request \(formatByteQuantity(request))"
        }
        return nil
    }

    private func computeUsageRatio(usage: Double?, request: Double?, limit: Double?) -> Double? {
        guard let usage else { return nil }
        if let limit, limit > 0, limit.isFinite, limit > 0 {
            return min(max(usage / limit, 0), 1)
        }
        if let request, request > 0, request.isFinite {
            return min(max(usage / request, 0), 1)
        }
        return nil
    }

    private func parseCPUQuantity(_ value: String) -> Double? {
        let lowercased = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if lowercased.hasSuffix("n"), let base = Double(String(lowercased.dropLast())) {
            return base / 1_000_000_000
        }
        if lowercased.hasSuffix("u"), let base = Double(String(lowercased.dropLast())) {
            return base / 1_000_000
        }
        if lowercased.hasSuffix("m"), let base = Double(String(lowercased.dropLast())) {
            return base / 1_000
        }
        return Double(lowercased)
    }

    private func parseMemoryQuantity(_ value: String) -> Double? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let upper = trimmed.uppercased()

        let binaryUnits: [(String, Double)] = [
            ("EI", pow(1024.0, 6)),
            ("PI", pow(1024.0, 5)),
            ("TI", pow(1024.0, 4)),
            ("GI", pow(1024.0, 3)),
            ("MI", pow(1024.0, 2)),
            ("KI", 1024.0)
        ]
        for (suffix, multiplier) in binaryUnits {
            if upper.hasSuffix(suffix) {
                let numberPart = trimmed.dropLast(suffix.count)
                if let base = Double(String(numberPart)) {
                    return base * multiplier
                }
                return nil
            }
        }

        let decimalUnits: [(String, Double)] = [
            ("E", pow(1000.0, 6)),
            ("P", pow(1000.0, 5)),
            ("T", pow(1000.0, 4)),
            ("G", pow(1000.0, 3)),
            ("M", pow(1000.0, 2)),
            ("K", 1000.0)
        ]
        for (suffix, multiplier) in decimalUnits {
            if upper.hasSuffix(suffix) {
                let numberPart = trimmed.dropLast(suffix.count)
                if let base = Double(String(numberPart)) {
                    return base * multiplier
                }
                return nil
            }
        }

        return Double(trimmed)
    }
}

private extension KubectlClusterService {
    static let percentFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .binary
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter
    }()

    static let cpuNumberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    static func cpuDisplayString(for cores: Double) -> String {
        if cores < 1 {
            let millicores = Int(round(cores * 1000))
            return "\(millicores)m"
        }
        let formatted = cpuNumberFormatter.string(from: NSNumber(value: cores)) ?? String(format: "%.2f", cores)
        return "\(formatted) cores"
    }
}

private struct NodeStatsSummary: Decodable {
    struct Node: Decodable {
        struct Filesystem: Decodable {
            let availableBytes: Double?
            let capacityBytes: Double?
            let usedBytes: Double?
        }
        struct Network: Decodable {
            let rxBytes: Double?
            let txBytes: Double?
        }
        let fs: Filesystem?
        let network: Network?
    }

    struct Pod: Decodable {
        struct PodRef: Decodable {
            let name: String
            let namespace: String
        }

        struct Filesystem: Decodable {
            let availableBytes: Double?
            let capacityBytes: Double?
            let usedBytes: Double?
        }

        struct Container: Decodable {
            let name: String
            let rootfs: Filesystem?
            let logs: Filesystem?
        }

        struct Volume: Decodable {
            let name: String
            let availableBytes: Double?
            let capacityBytes: Double?
            let usedBytes: Double?
        }

        let podRef: PodRef
        let containers: [Container]?
        let volumes: [Volume]?

        enum CodingKeys: String, CodingKey {
            case podRef
            case containers
            case volumes = "volumeStats"
        }
    }

    let node: Node
    let pods: [Pod]?
}

// MARK: - Log Streaming

final class KubectlLogStreamingService: LogStreamingService {
    private let runner: KubectlRunner
    private let kubeconfigPath: String?

    init(runner: KubectlRunner = KubectlRunner(), kubeconfigPath: String? = KubectlDefaults.defaultKubeconfigPath()) {
        self.runner = runner
        self.kubeconfigPath = kubeconfigPath
    }

    func streamLogs(for request: LogStreamRequest) -> AsyncThrowingStream<LogStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            var environment = ProcessInfo.processInfo.environment
            environment.merge(kubeconfigPath.map { ["KUBECONFIG": $0] } ?? [:]) { current, _ in current }
            let resolution = KubectlDefaults.prepareEnvironmentForKubectl(&environment)
            guard resolution.found else {
                continuation.finish(throwing: KubectlError(message: "kubectl executable not found. Install kubectl or update PATH.", output: nil))
                return
            }

            var arguments = [resolution.command, "logs", request.podName, "-n", request.namespace, "--context", request.contextName]
            if let container = request.containerName {
                arguments.append(contentsOf: ["-c", container])
            } else {
                arguments.append("--all-containers=true")
            }
            if request.includeTimestamps {
                arguments.append("--timestamps")
            }
            if request.follow {
                arguments.append("-f")
            }
            process.arguments = arguments
            process.environment = environment

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            let stdoutHandle = pipe.fileHandleForReading

            process.terminationHandler = { process in
                if process.terminationStatus != 0 {
                    continuation.finish(throwing: KubectlError(message: "kubectl logs exited with status \(process.terminationStatus)", output: nil))
                } else {
                    continuation.finish()
                }
            }

            continuation.onTermination = { @Sendable _ in
                if process.isRunning {
                    process.terminate()
                }
            }

            do {
                try process.run()
            } catch {
                continuation.finish(throwing: error)
                return
            }

            Task.detached {
                for try await line in stdoutHandle.bytes.lines {
                    continuation.yield(.line(String(line), Date()))
                }
            }
        }
    }
}

// MARK: - Exec Service

final class KubectlExecService: ExecService {
    private let kubeconfigPath: String?

    init(kubeconfigPath: String? = KubectlDefaults.defaultKubeconfigPath()) {
        self.kubeconfigPath = kubeconfigPath
    }

    func openShell(for session: ExecSession) async throws -> ExecSession {
        let arguments = buildShellCommandComponents(for: session)
        try KubectlDefaults.launchInTerminal(kubeconfigPath: kubeconfigPath, arguments: arguments)
        return session
    }

    private func buildShellCommandComponents(for session: ExecSession) -> [String] {
        var components = ["kubectl", "exec", "-it", session.podName, "-n", session.namespace, "--context", session.contextName]
        if let container = session.containerName {
            components.append(contentsOf: ["-c", container])
        }
        components.append("--")
        components.append(contentsOf: session.command)
        return components
    }
}

// MARK: - Edit Service

final class KubectlEditService: EditService {
    private let kubeconfigPath: String?

    init(kubeconfigPath: String? = KubectlDefaults.defaultKubeconfigPath()) {
        self.kubeconfigPath = kubeconfigPath
    }

    func editResource(_ request: ResourceEditRequest) async throws {
        var components = ["kubectl", "edit", request.kind, request.name]
        if let namespace = request.namespace, !namespace.isEmpty {
            components.append(contentsOf: ["-n", namespace])
        }
        components.append(contentsOf: ["--context", request.contextName])
        try KubectlDefaults.launchInTerminal(
            kubeconfigPath: kubeconfigPath,
            arguments: components,
            extraEnv: ["KUBE_EDITOR": "vi"]
        )
    }
}

// MARK: - Port Forward Service

actor KubectlPortForwardService: PortForwardService {
    private typealias EventHandler = @Sendable (PortForwardLifecycleEvent) -> Void

    private struct ForwardState {
        let process: Process
        let pipe: Pipe
        let buffer: PipeDataBuffer
        let request: PortForwardRequest
        let handler: EventHandler
    }

    private let kubeconfigPath: String?
    private var forwards: [UUID: ForwardState] = [:]

    init(kubeconfigPath: String? = KubectlDefaults.defaultKubeconfigPath()) {
        self.kubeconfigPath = kubeconfigPath
    }

    func startForward(
        _ request: PortForwardRequest,
        eventHandler: @escaping @Sendable (PortForwardLifecycleEvent) -> Void
    ) async throws -> ActivePortForward {
        let id = UUID()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")

        var environment = ProcessInfo.processInfo.environment
        if let kubeconfigPath {
            environment["KUBECONFIG"] = kubeconfigPath
        }
        let resolution = KubectlDefaults.prepareEnvironmentForKubectl(&environment)
        guard resolution.found else {
            throw KubectlError(message: "kubectl executable not found. Install kubectl or update PATH.", output: nil)
        }

        process.arguments = [
            resolution.command,
            "port-forward",
            "pod/\(request.podName)",
            "\(request.localPort):\(request.remotePort)",
            "-n",
            request.namespace,
            "--context",
            request.contextName
        ]
        process.environment = environment

        let pipe = Pipe()
        let buffer = PipeDataBuffer()
        let handle = pipe.fileHandleForReading
        handle.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                handle.readabilityHandler = nil
                return
            }
            buffer.append(data)
        }

        process.standardOutput = pipe
        process.standardError = pipe

        process.terminationHandler = { [weak self] _ in
            Task { await self?.handleTermination(forwardID: id) }
        }

        let state = ForwardState(process: process, pipe: pipe, buffer: buffer, request: request, handler: eventHandler)
        forwards[id] = state

        do {
            try process.run()
        } catch {
            handle.readabilityHandler = nil
            forwards.removeValue(forKey: id)
            throw error
        }

        // Wait briefly to ensure the tunnel is active
        try await Task.sleep(nanoseconds: 300_000_000)

        guard process.isRunning else {
            if let (request, handler, kubectlError) = finalizeForward(id: id) {
                handler(.terminated(id: id, request: request, error: kubectlError))
                if let kubectlError {
                    throw kubectlError
                }
            }
            throw KubectlError(message: "kubectl port-forward exited unexpectedly", output: nil)
        }

        return ActivePortForward(
            id: id,
            request: request,
            startedAt: Date(),
            status: .active
        )
    }

    func stopForward(_ forward: ActivePortForward) async throws {
        guard let state = forwards[forward.id] else { return }
        state.process.terminate()
    }

    private func handleTermination(forwardID: UUID) async {
        guard let (request, handler, kubectlError) = finalizeForward(id: forwardID) else {
            return
        }
        handler(.terminated(id: forwardID, request: request, error: kubectlError))
    }

    private func finalizeForward(
        id: UUID
    ) -> (PortForwardRequest, EventHandler, KubectlError?)? {
        guard let state = forwards.removeValue(forKey: id) else { return nil }

        let handle = state.pipe.fileHandleForReading
        handle.readabilityHandler = nil
        state.buffer.appendRemaining(from: handle)
        try? handle.close()

        let rawOutput = state.buffer.string()
        let trimmedOutput = rawOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        let status = state.process.terminationStatus
        let reason = state.process.terminationReason

        let kubectlError: KubectlError?
        if reason == .exit && status == 0 {
            kubectlError = nil
        } else if reason == .uncaughtSignal && status == SIGTERM {
            kubectlError = nil
        } else {
            let message = trimmedOutput.isEmpty ? "kubectl port-forward exited with status \(status)" : trimmedOutput
            kubectlError = KubectlError(message: message, output: rawOutput.isEmpty ? nil : rawOutput)
        }

        return (state.request, state.handler, kubectlError)
    }
}

// MARK: - Codable helpers

private struct KubectlConfig: Decodable {
    struct NamedContext: Decodable {
        struct Context: Decodable {
            let cluster: String
            let namespace: String?
            let user: String?
        }

        let name: String
        let context: Context
    }

    struct NamedCluster: Decodable {
        struct Cluster: Decodable {
            let server: String?
            let certificateAuthorityData: String?
            let insecureSkipTLSVerify: Bool?
            let extensions: [String: String]?
            let serverVersion: String?
        }

        let name: String
        let cluster: Cluster
    }

    let contexts: [NamedContext]
    let clusters: [NamedCluster]
}

private struct KubectlNamespaceList: Decodable {
    struct Item: Decodable {
        struct Metadata: Decodable {
            let name: String
        }
        let metadata: Metadata
    }
    let items: [Item]
}

private struct KubectlDeploymentList: Decodable {
    struct Item: Decodable {
        struct Metadata: Decodable {
            let name: String
            let uid: String?
            let creationTimestamp: String?
        }
        struct Spec: Decodable {
            let replicas: Int?
        }
        struct Status: Decodable {
            let replicas: Int?
            let readyReplicas: Int?
            let updatedReplicas: Int?
            let availableReplicas: Int?
        }
        let metadata: Metadata
        let spec: Spec?
        let status: Status?
    }
    let items: [Item]
}

private struct KubectlStatefulSetList: Decodable {
    struct Item: Decodable {
        struct Metadata: Decodable {
            let name: String
            let uid: String?
            let creationTimestamp: String?
        }
        struct Spec: Decodable {
            let replicas: Int?
        }
        struct Status: Decodable {
            let replicas: Int?
            let readyReplicas: Int?
            let updatedReplicas: Int?
            let availableReplicas: Int?
        }
        let metadata: Metadata
        let spec: Spec?
        let status: Status?
    }
    let items: [Item]
}

private struct KubectlDaemonSetList: Decodable {
    struct Item: Decodable {
        struct Metadata: Decodable {
            let name: String
            let uid: String?
            let creationTimestamp: String?
        }
        struct Status: Decodable {
            let desiredNumberScheduled: Int?
            let numberReady: Int?
            let updatedNumberScheduled: Int?
            let numberAvailable: Int?
        }
        let metadata: Metadata
        let status: Status?
    }
    let items: [Item]
}

private struct KubectlCronJobList: Decodable {
    struct Item: Decodable {
        struct Metadata: Decodable {
            let name: String
            let uid: String?
            let creationTimestamp: String?
        }
        struct Spec: Decodable {
            let successfulJobsHistoryLimit: Int?
            let schedule: String?
            let suspend: Bool?
        }
        struct Status: Decodable {
            let lastScheduleTime: String?
        }
        let metadata: Metadata
        let spec: Spec?
        let status: Status?
    }
    let items: [Item]
}

private struct KubectlPodList: Decodable {
    struct Item: Decodable {
        struct Metadata: Decodable {
            let name: String
            let uid: String?
            let namespace: String?
            let creationTimestamp: String?
            struct OwnerReference: Decodable {
                let kind: String?
                let name: String?
            }
            let ownerReferences: [OwnerReference]?
            let labels: [String: String]?
            let annotations: [String: String]?
        }
        struct Spec: Decodable {
            struct Container: Decodable {
                let name: String
                let image: String?
                let args: [String]?
                let command: [String]?
                struct ContainerPort: Decodable {
                    let name: String?
                    let containerPort: Int?
                    let `protocol`: String?
                }
                let ports: [ContainerPort]?
                struct VolumeMount: Decodable {
                    let name: String
                    let mountPath: String
                    let readOnly: Bool?
                }
                let volumeMounts: [VolumeMount]?
                struct Resources: Decodable {
                    let requests: [String: String]?
                    let limits: [String: String]?
                }
                let resources: Resources?
            }
            let nodeName: String?
            let containers: [Container]
            let initContainers: [Container]?
        }
        struct Status: Decodable {
            struct ContainerStatus: Decodable {
                struct State: Decodable {
                    struct Running: Decodable { let startedAt: String? }
                    struct Waiting: Decodable { let reason: String?; let message: String? }
                    struct Terminated: Decodable { let exitCode: Int?; let reason: String?; let message: String?; let finishedAt: String?; let startedAt: String? }
                    let running: Running?
                    let waiting: Waiting?
                    let terminated: Terminated?
                }
                let name: String
                let ready: Bool
                let restartCount: Int?
                let state: State?
            }
            struct Condition: Decodable {
                let type: String
                let status: String?
            }
            let phase: String?
            let containerStatuses: [ContainerStatus]?
            let qosClass: String?
            let conditions: [Condition]?
            let podIP: String?
            struct PodIP: Decodable { let ip: String }
            let podIPs: [PodIP]?
        }
        let metadata: Metadata
        let spec: Spec?
        let status: Status?
    }
    let items: [Item]
}

private struct PodMetricsList: Decodable {
    struct Item: Decodable {
        struct Metadata: Decodable {
            let name: String
            let namespace: String?
        }
        struct Container: Decodable {
            let name: String
            let usage: [String: String]
        }
        let metadata: Metadata
        let timestamp: String?
        let window: String?
        let containers: [Container]
    }
    let items: [Item]
}

private struct KubernetesIntOrString: Decodable {
    let stringValue: String?
    let intValue: Int?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            self.intValue = intValue
            self.stringValue = nil
        } else if let stringValue = try? container.decode(String.self) {
            self.intValue = nil
            self.stringValue = stringValue
        } else {
            self.intValue = nil
            self.stringValue = nil
        }
    }

    var description: String {
        if let intValue { return String(intValue) }
        if let stringValue { return stringValue }
        return ""
    }
}

private struct KubectlPodDetailObject: Decodable {
    struct Metadata: Decodable {
        let name: String
        let namespace: String?
        let creationTimestamp: String?
        let labels: [String: String]?
        let annotations: [String: String]?
        struct OwnerReference: Decodable {
            let kind: String?
            let name: String?
        }
        let ownerReferences: [OwnerReference]?
        struct ManagedField: Decodable {
            let manager: String?
        }
        let managedFields: [ManagedField]?
    }

    struct Spec: Decodable {
        struct Container: Decodable {
            let name: String
            let image: String?
            let imagePullPolicy: String?
            let args: [String]?
            let command: [String]?
            struct ContainerPort: Decodable {
                let name: String?
                let containerPort: Int?
                let `protocol`: String?
            }
            let ports: [ContainerPort]?
            struct EnvVar: Decodable {
                let name: String
                let value: String?
            }
            let env: [EnvVar]?
            struct VolumeMount: Decodable {
                let name: String
                let mountPath: String
                let readOnly: Bool?
            }
            let volumeMounts: [VolumeMount]?
            struct Resources: Decodable {
                let requests: [String: String]?
                let limits: [String: String]?
            }
            let resources: Resources?
            let livenessProbe: Probe?
            let readinessProbe: Probe?
            let startupProbe: Probe?
        }

        struct Probe: Decodable {
            let httpGet: HTTPGet?
            let exec: Exec?
            let tcpSocket: TCPSocket?
            let initialDelaySeconds: Int?
            let timeoutSeconds: Int?
            let periodSeconds: Int?
            let successThreshold: Int?
            let failureThreshold: Int?

            struct HTTPGet: Decodable {
                let path: String?
                let port: KubernetesIntOrString?
                let scheme: String?
            }

            struct Exec: Decodable {
                let command: [String]?
            }

            struct TCPSocket: Decodable {
                let port: KubernetesIntOrString?
            }
        }

        let nodeName: String?
        let serviceAccountName: String?
        let serviceAccount: String?
        let containers: [Container]
        let initContainers: [Container]?
        struct Toleration: Decodable {
            let key: String?
            let `operator`: String?
            let value: String?
            let effect: String?
            let tolerationSeconds: Int?
        }
        let tolerations: [Toleration]?
        struct Volume: Decodable {
            let name: String
            let projected: [String: AnyDecodable]?
            let emptyDir: [String: AnyDecodable]?
            let configMap: [String: AnyDecodable]?
            let secret: [String: AnyDecodable]?
            let persistentVolumeClaim: [String: AnyDecodable]?
            let downwardAPI: [String: AnyDecodable]?
            let hostPath: [String: AnyDecodable]?
        }
        let volumes: [Volume]?
    }

    struct Status: Decodable {
        struct ContainerStatus: Decodable {
            let name: String
            let ready: Bool
            let restartCount: Int?
            struct State: Decodable {
                struct Running: Decodable { let startedAt: String? }
                struct Waiting: Decodable { let reason: String?; let message: String? }
                struct Terminated: Decodable { let exitCode: Int?; let reason: String?; let message: String?; let finishedAt: String?; let startedAt: String? }
                let running: Running?
                let waiting: Waiting?
                let terminated: Terminated?
            }
            let state: State?
        }

        struct Condition: Decodable {
            let type: String
            let status: String
            let reason: String?
            let message: String?
        }

        struct PodIP: Decodable { let ip: String }

        let phase: String?
        let podIP: String?
        let podIPs: [PodIP]?
        let qosClass: String?
        let conditions: [Condition]?
        let containerStatuses: [ContainerStatus]?
        let initContainerStatuses: [ContainerStatus]?
    }

    struct AnyDecodable: Decodable {}

    let metadata: Metadata
    let spec: Spec?
    let status: Status?

    func toPodDetailData() -> PodDetailData {
        let isoFormatter = ISO8601DateFormatter()
        let creationDate = metadata.creationTimestamp.flatMap { isoFormatter.date(from: $0) }
        let owner = metadata.ownerReferences?.first
        let ownerDescription: String?
        if let owner {
            if let kind = owner.kind, let name = owner.name {
                ownerDescription = "\(kind)/\(name)"
            } else if let kind = owner.kind {
                ownerDescription = kind
            } else {
                ownerDescription = owner.name
            }
        } else {
            ownerDescription = nil
        }

        let podStatus = status?.phase ?? "Unknown"
        let podIPs = status?.podIPs?.map { $0.ip } ?? []
        let conditions = status?.conditions?.map {
            PodCondition(type: $0.type, status: $0.status, reason: $0.reason, message: $0.message)
        } ?? []
        let tolerations = spec?.tolerations?.map {
            PodToleration(key: $0.key, operator: $0.operator, value: $0.value, effect: $0.effect, tolerationSeconds: $0.tolerationSeconds)
        } ?? []
        let volumes = spec?.volumes?.map { volume -> PodVolume in
            let type: String
            switch true {
            case volume.projected != nil: type = "Projected"
            case volume.configMap != nil: type = "ConfigMap"
            case volume.secret != nil: type = "Secret"
            case volume.persistentVolumeClaim != nil: type = "PVC"
            case volume.emptyDir != nil: type = "EmptyDir"
            case volume.downwardAPI != nil: type = "DownwardAPI"
            case volume.hostPath != nil: type = "HostPath"
            default: type = "Volume"
            }
            return PodVolume(name: volume.name, type: type, detail: nil)
        } ?? []

        let containerStatuses = status?.containerStatuses ?? []
        let containerStatusMap = Dictionary(uniqueKeysWithValues: containerStatuses.map { ($0.name, $0) })
        let initContainerStatuses = status?.initContainerStatuses ?? []
        let initStatusMap = Dictionary(uniqueKeysWithValues: initContainerStatuses.map { ($0.name, $0) })

        let initContainers = spec?.initContainers?.map { container in
            ContainerDetail(
                name: container.name,
                image: container.image ?? "",
                status: ContainerDetail.ContainerState(containerStatus: initStatusMap[container.name]),
                ready: initStatusMap[container.name]?.ready ?? false,
                ports: container.ports?.compactMap { port in
                    guard let value = port.containerPort else { return nil }
                    let proto = port.`protocol` ?? "TCP"
                    if let name = port.name, !name.isEmpty {
                        return "\(name): \(value)/\(proto)"
                    }
                    return "\(value)/\(proto)"
                } ?? [],
                envCount: container.env?.count ?? 0,
                mountCount: container.volumeMounts?.count ?? 0,
                args: container.args ?? [],
                command: container.command ?? [],
                requests: container.resources?.requests ?? [:],
                limits: container.resources?.limits ?? [:],
                livenessProbe: container.livenessProbe?.toProbeDetail(),
                readinessProbe: container.readinessProbe?.toProbeDetail(),
                startupProbe: container.startupProbe?.toProbeDetail()
            )
        } ?? []

        let containers = spec?.containers.map { container in
            ContainerDetail(
                name: container.name,
                image: container.image ?? "",
                status: ContainerDetail.ContainerState(containerStatus: containerStatusMap[container.name]),
                ready: containerStatusMap[container.name]?.ready ?? false,
                ports: container.ports?.compactMap { port in
                    guard let value = port.containerPort else { return nil }
                    let proto = port.`protocol` ?? "TCP"
                    if let name = port.name, !name.isEmpty {
                        return "\(name): \(value)/\(proto)"
                    }
                    return "\(value)/\(proto)"
                } ?? [],
                envCount: container.env?.count ?? 0,
                mountCount: container.volumeMounts?.count ?? 0,
                args: container.args ?? [],
                command: container.command ?? [],
                requests: container.resources?.requests ?? [:],
                limits: container.resources?.limits ?? [:],
                livenessProbe: container.livenessProbe?.toProbeDetail(),
                readinessProbe: container.readinessProbe?.toProbeDetail(),
                startupProbe: container.startupProbe?.toProbeDetail()
            )
        } ?? []

        return PodDetailData(
            name: metadata.name,
            namespace: metadata.namespace ?? "",
            createdAt: creationDate,
            labels: metadata.labels ?? [:],
            annotations: metadata.annotations ?? [:],
            controlledBy: ownerDescription,
            status: podStatus,
            nodeName: spec?.nodeName ?? "",
            podIP: status?.podIP,
            podIPs: podIPs,
            serviceAccount: spec?.serviceAccountName ?? spec?.serviceAccount,
            qosClass: status?.qosClass,
            conditions: conditions,
            tolerations: tolerations,
            volumes: volumes,
            initContainers: initContainers,
            containers: containers
        )
    }
}

private extension ContainerDetail.ContainerState {
    init(containerStatus: KubectlPodDetailObject.Status.ContainerStatus?) {
        guard let status = containerStatus else {
            self = .unknown
            return
        }
        if status.state?.running != nil {
            self = .running
        } else if status.state?.waiting != nil {
            self = .waiting
        } else if status.state?.terminated != nil {
            self = .terminated
        } else {
            self = .unknown
        }
    }
}

private extension KubectlPodDetailObject.Spec.Probe {
    func toProbeDetail() -> ProbeDetail {
        if let http = httpGet {
            let port = http.port?.description ?? ""
            let path = http.path ?? "/"
            let scheme = http.scheme ?? "http"
            return ProbeDetail(type: "HTTP GET", detail: "\(scheme.lowercased())://:\(port)\(path)")
        } else if let exec = exec {
            let command = exec.command?.joined(separator: " ") ?? ""
            return ProbeDetail(type: "Exec", detail: command)
        } else if let tcp = tcpSocket {
            let port = tcp.port?.description ?? ""
            return ProbeDetail(type: "TCP", detail: ":\(port)")
        }
        return ProbeDetail(type: "Probe", detail: "Configured")
    }
}

private extension KubectlPodDetailObject.Spec.Container {
    func toContainerDetail(status: KubectlPodDetailObject.Status.ContainerStatus?) -> ContainerDetail {
        ContainerDetail(
            name: name,
            image: image ?? "",
            status: ContainerDetail.ContainerState(containerStatus: status),
            ready: status?.ready ?? false,
            ports: ports?.compactMap { port in
                guard let portNumber = port.containerPort else { return nil }
                let proto = port.`protocol` ?? "TCP"
                if let name = port.name, !name.isEmpty {
                    return "\(name): \(portNumber)/\(proto)"
                }
                return "\(portNumber)/\(proto)"
            } ?? [],
            envCount: env?.count ?? 0,
            mountCount: volumeMounts?.count ?? 0,
            args: args ?? [],
            command: command ?? [],
            requests: resources?.requests ?? [:],
            limits: resources?.limits ?? [:],
            livenessProbe: livenessProbe?.toProbeDetail(),
            readinessProbe: readinessProbe?.toProbeDetail(),
            startupProbe: startupProbe?.toProbeDetail()
        )
    }
}

private struct KubectlEventList: Decodable {
    struct Item: Decodable {
        struct Metadata: Decodable {
            let name: String
            let uid: String?
        }
        let metadata: Metadata
        let message: String
        let type: String?
        let count: Int?
        let eventTime: String?
        let lastTimestamp: String?
        let firstTimestamp: String?
    }
    let items: [Item]
}

private struct KubectlConfigMapList: Decodable {
    struct Item: Decodable {
        struct Metadata: Decodable {
            let name: String
            let uid: String?
            let creationTimestamp: String?
        }
        let metadata: Metadata
        let data: [String: String]?
        let binaryData: [String: String]?
        let immutable: Bool?
    }
    let items: [Item]
}

private struct KubectlSecretList: Decodable {
    struct Item: Decodable {
        struct Metadata: Decodable {
            let name: String
            let uid: String?
            let creationTimestamp: String?
        }
        let metadata: Metadata
        let type: String?
        let data: [String: String]?
        let immutable: Bool?
    }
    let items: [Item]
}

private struct KubectlResourceQuotaList: Decodable {
    struct Item: Decodable {
        struct Metadata: Decodable {
            let name: String
            let uid: String?
            let creationTimestamp: String?
        }
        struct Status: Decodable {
            let hard: [String: String]?
            let used: [String: String]?
        }
        let metadata: Metadata
        let status: Status?
    }
    let items: [Item]
}

private struct KubectlLimitRangeList: Decodable {
    struct Item: Decodable {
        struct Metadata: Decodable {
            let name: String
            let uid: String?
            let creationTimestamp: String?
        }
        struct Spec: Decodable {
            struct Limit: Decodable {
                let type: String?
                let max: [String: String]?
                let min: [String: String]?
                let `default`: [String: String]?
                let defaultRequest: [String: String]?
            }
            let limits: [Limit]?
        }
        let metadata: Metadata
        let spec: Spec?
    }
    let items: [Item]
}

private struct KubectlNodeList: Decodable {
    struct Item: Decodable {
        struct Metadata: Decodable {
            let name: String
            let uid: String?
            let creationTimestamp: String?
        }
        struct Spec: Decodable {
            struct Taint: Decodable {
                let key: String
                let value: String?
                let effect: String?
            }
            let taints: [Taint]?
        }
        struct Status: Decodable {
            struct Condition: Decodable {
                let type: String
                let status: String
                let reason: String?
                let message: String?
            }
            let conditions: [Condition]
            let allocatable: [String: String]?
            let capacity: [String: String]?
            struct NodeInfo: Decodable {
                let kubeletVersion: String?
            }
            let nodeInfo: NodeInfo?
        }
        let metadata: Metadata
        let spec: Spec?
        let status: Status
    }
    let items: [Item]
}

private struct MetricsNodeList: Decodable {
    struct Item: Decodable {
        struct Metadata: Decodable { let name: String }
        struct Usage: Decodable {
            let cpu: String?
            let memory: String?
        }
        let metadata: Metadata
        let usage: Usage
    }
    let items: [Item]
}

private struct KubectlReplicaSetList: Decodable {
    struct Item: Decodable {
        struct Metadata: Decodable {
            let name: String
            let uid: String?
            let creationTimestamp: String?
        }
        struct Spec: Decodable {
            let replicas: Int?
        }
        struct Status: Decodable {
            let replicas: Int?
            let readyReplicas: Int?
            let availableReplicas: Int?
            let fullyLabeledReplicas: Int?
        }
        let metadata: Metadata
        let spec: Spec?
        let status: Status?
    }
    let items: [Item]
}

private struct KubectlReplicationControllerList: Decodable {
    struct Item: Decodable {
        struct Metadata: Decodable {
            let name: String
            let uid: String?
            let creationTimestamp: String?
        }
        struct Spec: Decodable {
            let replicas: Int?
        }
        struct Status: Decodable {
            let replicas: Int?
            let readyReplicas: Int?
            let availableReplicas: Int?
        }
        let metadata: Metadata
        let spec: Spec?
        let status: Status?
    }
    let items: [Item]
}

private struct KubectlJobList: Decodable {
    struct Item: Decodable {
        struct Metadata: Decodable {
            let name: String
            let uid: String?
            let creationTimestamp: String?
        }
        struct Status: Decodable {
            struct Condition: Decodable {
                let type: String
                let status: String?
            }
            let succeeded: Int?
            let active: Int?
            let failed: Int?
            let conditions: [Condition]?
        }
        let metadata: Metadata
        let status: Status?
    }
    let items: [Item]
}

private struct KubectlServiceList: Decodable {
    struct Item: Decodable {
        struct Metadata: Decodable {
            let name: String
            let creationTimestamp: String?
        }
        struct Port: Decodable {
            let port: Int?
            let `protocol`: String?
            let targetPort: KubernetesIntOrString?
        }
        struct Spec: Decodable {
            let type: String?
            let clusterIP: String?
            let ports: [Port]
            let selector: [String: String]?
        }
        let metadata: Metadata
        let spec: Spec
    }
    let items: [Item]
}

private struct KubectlEndpointList: Decodable {
    struct Item: Decodable {
        struct Metadata: Decodable { let name: String }
        struct Subset: Decodable {
            struct Address: Decodable {
                struct TargetRef: Decodable {
                    let kind: String?
                    let name: String?
                }
                let targetRef: TargetRef?
            }
            let addresses: [Address]?
        }
        let metadata: Metadata
        let subsets: [Subset]?
    }
    let items: [Item]
}

private struct KubectlIngressList: Decodable {
    struct Item: Decodable {
        struct Metadata: Decodable {
            let name: String
            let creationTimestamp: String?
        }
        struct Spec: Decodable {
            struct Rule: Decodable {
                struct HTTP: Decodable {
                    struct Path: Decodable {
                        struct Backend: Decodable {
                            struct Service: Decodable {
                                struct Port: Decodable {
                                    let number: Int?
                                    let name: String?
                                }
                                let name: String
                                let port: Port?
                            }
                            let service: Service?
                        }
                        let path: String?
                        let backend: Backend
                    }
                    let paths: [Path]
                }
                let host: String?
                let http: HTTP?
            }
            struct TLSRule: Decodable {
                let hosts: [String]?
            }
            let ingressClassName: String?
            let rules: [Rule]
            let tls: [TLSRule]?
        }
        let metadata: Metadata
        let spec: Spec
    }
    let items: [Item]
}

private struct KubectlPVCList: Decodable {
    struct Item: Decodable {
        struct Metadata: Decodable {
            let name: String
            let creationTimestamp: String?
        }
        struct Spec: Decodable {
            let storageClassName: String?
            let volumeName: String?
            struct Resources: Decodable {
                let requests: [String: String]?
            }
            let resources: Resources?
        }
        struct Status: Decodable {
            let phase: String?
            let capacity: [String: String]?
        }
        let metadata: Metadata
        let spec: Spec
        let status: Status?
    }
    let items: [Item]
}

private struct KubectlServiceAccountList: Decodable {
    struct Item: Decodable {
        struct Metadata: Decodable {
            let name: String
            let creationTimestamp: String?
        }
        let metadata: Metadata
        let secrets: [[String: String]]?
    }
    let items: [Item]
}

private struct KubectlRoleList: Decodable {
    struct Item: Decodable {
        struct Metadata: Decodable {
            let name: String
            let creationTimestamp: String?
        }
        struct Rule: Decodable {
            let apiGroups: [String]?
            let resources: [String]?
            let verbs: [String]?
        }
        let metadata: Metadata
        let rules: [Rule]?
    }
    let items: [Item]
}

private struct KubectlRoleBindingList: Decodable {
    struct Item: Decodable {
        struct Metadata: Decodable {
            let name: String
            let creationTimestamp: String?
        }
        struct Subject: Decodable {
            let kind: String?
            let name: String?
            let namespace: String?
        }
        struct RoleRef: Decodable {
            let kind: String
            let name: String
        }
        let metadata: Metadata
        let subjects: [Subject]?
        let roleRef: RoleRef
    }
    let items: [Item]
}

private struct KubectlCRDList: Decodable {
    struct Item: Decodable {
        struct Metadata: Decodable {
            let name: String
            let creationTimestamp: String?
        }
        struct Spec: Decodable {
            struct Names: Decodable {
                let kind: String
                let shortNames: [String]?
            }
            struct VersionEntry: Decodable {
                let name: String
            }
            let group: String
            let version: String?
            let versions: [VersionEntry]
            let scope: String
            let names: Names
        }
        let metadata: Metadata
        let spec: Spec
    }
    let items: [Item]
}

// MARK: - Helpers

private extension KubectlEventList.Item {
    func parsedTimestamp(using formatter: ISO8601DateFormatter) -> Date? {
        if let eventTime, let date = formatter.date(from: eventTime) { return date }
        if let lastTimestamp, let date = formatter.date(from: lastTimestamp) { return date }
        if let firstTimestamp, let date = formatter.date(from: firstTimestamp) { return date }
        return nil
    }

    func relativeAge(now: Date, formatter: ISO8601DateFormatter) -> EventAge {
        guard let timestamp = parsedTimestamp(using: formatter) else { return .hours(0) }
        return EventAge.from(date: timestamp)
    }
}

private extension WorkloadStatus {
    static func fromReady(total: Int, ready: Int) -> WorkloadStatus {
        guard total > 0 else { return .healthy }
        if ready == total { return .healthy }
        if ready == 0 { return .failed }
        return .degraded
    }
}

private extension WorkloadSummary {
    var alertMessage: String? {
        guard status != .healthy else { return nil }
        return "\(name) is \(status.displayName)"
    }
}
