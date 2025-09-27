import Foundation

protocol HelmService: Sendable {
    func listReleases(contextName: String) async throws -> [HelmRelease]
}

struct HelmCLIService: HelmService {
    func listReleases(contextName: String) async throws -> [HelmRelease] {
        let output = try await runHelm(arguments: [
            "list",
            "--all-namespaces",
            "--kube-context",
            contextName,
            "--output",
            "json"
        ])

        guard let data = output.data(using: .utf8) else {
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(Self.decodeHelmDate)

        let entries = try decoder.decode([HelmListEntry].self, from: data)
        return entries.map { $0.toRelease() }
    }

    private func runHelm(arguments: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["helm"] + arguments

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            process.terminationHandler = { process in
                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

                if process.terminationStatus == 0 {
                    let output = String(data: stdoutData, encoding: .utf8) ?? ""
                    continuation.resume(returning: output)
                } else {
                    let message = String(data: stderrData, encoding: .utf8) ?? "helm command failed"
                    continuation.resume(throwing: KubectlError(message: message.trimmingCharacters(in: .whitespacesAndNewlines)))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: KubectlError(message: error.localizedDescription))
            }
        }
    }

    private static func decodeHelmDate(from decoder: Decoder) throws -> Date {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        guard let date = Self.parseHelmDate(string) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unrecognised Helm date format: \(string)")
        }
        return date
    }

    private static func parseHelmDate(_ string: String) -> Date? {
        let normalized = string.replacingOccurrences(of: " UTC", with: "")
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSSSS ZZZZ"
        if let date = formatter.date(from: normalized) {
            return date
        }
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss ZZZZ"
        if let date = formatter.date(from: normalized) {
            return date
        }
        return nil
    }
}

#if DEBUG
struct MockHelmService: HelmService {
    var releases: [HelmRelease]

    func listReleases(contextName: String) async throws -> [HelmRelease] {
        releases
    }
}
#endif

private struct HelmListEntry: Decodable {
    var name: String
    var namespace: String
    var revision: String
    var updated: Date?
    var status: String
    var chart: String
    var app_version: String?

    func toRelease() -> HelmRelease {
        HelmRelease(
            name: name,
            namespace: namespace,
            revision: Int(revision) ?? 0,
            status: status,
            chart: chart,
            appVersion: app_version,
            updated: updated
        )
    }
}
