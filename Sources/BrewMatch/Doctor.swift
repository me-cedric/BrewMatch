import Foundation

enum DoctorStatus: String, Codable, Sendable {
    case pass
    case warn
    case fail
}

struct DoctorCheck: Codable, Sendable {
    var group: String
    var name: String
    var status: DoctorStatus
    var detail: String
    var remediation: String?
}

struct DoctorSummary: Codable, Equatable, Sendable {
    var passed: Int
    var warnings: Int
    var failures: Int
}

struct DoctorReport: Codable, Sendable {
    var version: String
    var generatedAt: String
    var checks: [DoctorCheck]
    var summary: DoctorSummary
    var warnings: [String]
    var failures: [String]
}

struct DoctorOptions {
    var ignoreFile: URL
    var applicationsRoot = URL(fileURLWithPath: "/Applications")
    var userApplicationsRoot = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
    var temporaryDirectory = FileManager.default.temporaryDirectory
    var knownCask = "firefox"
}

struct Doctor {
    var fileManager: FileManager = .default
    var scanner = AppScanner()

    func run(brew: BrewClient, options: DoctorOptions, generatedAt: Date = Date()) -> DoctorReport {
        var checks: [DoctorCheck] = [
            DoctorCheck(group: "System", name: "macOS version", status: .pass, detail: ProcessInfo.processInfo.operatingSystemVersionString, remediation: nil),
            DoctorCheck(group: "System", name: "architecture", status: .pass, detail: machineArchitecture(), remediation: nil),
        ]

        checks += brewChecks(brew, knownCask: options.knownCask)
        checks.append(readabilityCheck("Applications readable", url: options.applicationsRoot, missingIsWarning: false))
        checks.append(readabilityCheck("User Applications readable", url: options.userApplicationsRoot, missingIsWarning: true))
        checks.append(ignoreFileCheck(options.ignoreFile))
        checks.append(temporaryWriteCheck(options.temporaryDirectory))
        checks.append(scanCheck([options.applicationsRoot, options.userApplicationsRoot]))

        let summary = DoctorSummary(
            passed: checks.filter { $0.status == .pass }.count,
            warnings: checks.filter { $0.status == .warn }.count,
            failures: checks.filter { $0.status == .fail }.count
        )
        return DoctorReport(
            version: BrewMatchVersion.value,
            generatedAt: ISO8601DateFormatter().string(from: generatedAt),
            checks: checks,
            summary: summary,
            warnings: checks.filter { $0.status == .warn }.map(\.detail),
            failures: checks.filter { $0.status == .fail }.map(\.detail)
        )
    }

    private func brewChecks(_ brew: BrewClient, knownCask: String) -> [DoctorCheck] {
        guard brew.isAvailable else {
            return [
                DoctorCheck(group: "Homebrew", name: "brew exists", status: .warn, detail: "Homebrew not found.", remediation: "Install Homebrew or run BrewMatch for scan-only output."),
                DoctorCheck(group: "Homebrew", name: "brew path", status: .warn, detail: "No brew executable path.", remediation: "Check PATH or install Homebrew."),
                DoctorCheck(group: "Homebrew", name: "brew version", status: .warn, detail: "Cannot read Homebrew version.", remediation: "Install Homebrew or fix brew."),
                DoctorCheck(group: "Homebrew", name: "cask metadata", status: .warn, detail: "Cannot check cask metadata without Homebrew.", remediation: "Run again after Homebrew is available."),
            ]
        }

        let version = brew.version()
        let metadata = brew.metadata(for: knownCask)
        return [
            DoctorCheck(group: "Homebrew", name: "brew exists", status: .pass, detail: "Homebrew found.", remediation: nil),
            DoctorCheck(group: "Homebrew", name: "brew path", status: brew.executablePath == nil ? .warn : .pass, detail: brew.executablePath ?? "No brew executable path.", remediation: brew.executablePath == nil ? "Check PATH." : nil),
            DoctorCheck(group: "Homebrew", name: "brew version", status: version == nil ? .warn : .pass, detail: version ?? "Cannot read Homebrew version.", remediation: version == nil ? "Run `brew --version` manually." : nil),
            DoctorCheck(group: "Homebrew", name: "cask metadata", status: metadata == nil ? .warn : .pass, detail: metadata == nil ? "Cannot read metadata for cask `\(knownCask)`." : "Cask metadata works for `\(knownCask)`.", remediation: metadata == nil ? "Run `brew info --json=v2 --cask \(knownCask)` manually." : nil),
        ]
    }

    private func readabilityCheck(_ name: String, url: URL, missingIsWarning: Bool) -> DoctorCheck {
        guard fileManager.fileExists(atPath: url.path) else {
            return DoctorCheck(
                group: "Filesystem",
                name: name,
                status: missingIsWarning ? .warn : .fail,
                detail: "\(url.path) is missing.",
                remediation: missingIsWarning ? "Create it only if you use per-user Applications." : "Check macOS installation."
            )
        }
        let readable = fileManager.isReadableFile(atPath: url.path)
        return DoctorCheck(
            group: "Filesystem",
            name: name,
            status: readable ? .pass : .fail,
            detail: readable ? "\(url.path) is readable." : "\(url.path) is not readable.",
            remediation: readable ? nil : "Check directory permissions."
        )
    }

    private func ignoreFileCheck(_ url: URL) -> DoctorCheck {
        guard fileManager.fileExists(atPath: url.path) else {
            return DoctorCheck(group: "Configuration", name: "ignore file", status: .warn, detail: "Ignore file missing at \(url.path).", remediation: "No action needed unless you want ignored apps.")
        }
        do {
            _ = try IgnoreList.load(from: url, fileManager: fileManager)
            return DoctorCheck(group: "Configuration", name: "ignore file", status: .pass, detail: "Ignore file is valid.", remediation: nil)
        } catch {
            return DoctorCheck(group: "Configuration", name: "ignore file", status: .fail, detail: "Ignore file malformed at \(url.path).", remediation: "Fix JSON or pass --ignore-file with a valid file.")
        }
    }

    private func temporaryWriteCheck(_ directory: URL) -> DoctorCheck {
        let url = directory.appendingPathComponent("brewmatch-doctor-\(UUID().uuidString).tmp")
        do {
            try "ok".write(to: url, atomically: true, encoding: .utf8)
            try? fileManager.removeItem(at: url)
            return DoctorCheck(group: "Filesystem", name: "temporary output write", status: .pass, detail: "Temporary output write works.", remediation: nil)
        } catch {
            return DoctorCheck(group: "Filesystem", name: "temporary output write", status: .fail, detail: "Temporary output write failed: \(error)", remediation: "Check temporary directory permissions.")
        }
    }

    private func scanCheck(_ roots: [URL]) -> DoctorCheck {
        _ = scanner.scan(roots: roots)
        return DoctorCheck(group: "Scanner", name: "app scan", status: .pass, detail: "App scan completed.", remediation: nil)
    }

    private func machineArchitecture() -> String {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return "unknown"
        #endif
    }
}

struct DoctorRenderer {
    func text(_ report: DoctorReport) -> String {
        var lines = ["BrewMatch doctor", ""]
        for group in orderedGroups(report.checks) {
            lines.append("\(group):")
            for check in report.checks.filter({ $0.group == group }) {
                lines.append("- \(check.status.rawValue.uppercased()) \(check.name): \(check.detail)")
                if let remediation = check.remediation {
                    lines.append("  remediation: \(remediation)")
                }
            }
            lines.append("")
        }
        lines.append("Summary: \(report.summary.passed) passed, \(report.summary.warnings) warnings, \(report.summary.failures) failures")
        return lines.joined(separator: "\n") + "\n"
    }

    func json(_ report: DoctorReport) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return String(decoding: try encoder.encode(report), as: UTF8.self)
    }

    private func orderedGroups(_ checks: [DoctorCheck]) -> [String] {
        var seen: Set<String> = []
        return checks.compactMap { check in
            guard !seen.contains(check.group) else { return nil }
            seen.insert(check.group)
            return check.group
        }
    }
}
