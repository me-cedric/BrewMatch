import Foundation

protocol BrewExecutor {
    func run(arguments: [String]) -> BrewExecutionResult
}

struct BrewExecutionResult: Codable, Equatable, Sendable {
    var stdout: String
    var stderr: String
    var exitCode: Int32
}

struct LocalBrewExecutor: BrewExecutor {
    func run(arguments: [String]) -> BrewExecutionResult {
        guard let brewURL = findBrewURL() else {
            return BrewExecutionResult(stdout: "", stderr: "Homebrew not found.", exitCode: 127)
        }

        let process = Process()
        process.executableURL = brewURL
        process.arguments = arguments
        process.environment = ProcessInfo.processInfo.environment.merging(["HOMEBREW_NO_AUTO_UPDATE": "1"]) { _, new in new }

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return BrewExecutionResult(stdout: "", stderr: "\(error)", exitCode: 127)
        }

        return BrewExecutionResult(
            stdout: String(decoding: stdout.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self),
            stderr: String(decoding: stderr.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self),
            exitCode: process.terminationStatus
        )
    }

    private func findBrewURL() -> URL? {
        let candidates = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
            + (ProcessInfo.processInfo.environment["PATH"] ?? "")
                .split(separator: ":")
                .map { "\($0)/brew" }
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
            .map { URL(fileURLWithPath: $0) }
    }
}

struct AdoptOptions {
    var cask: String?
    var app: String?
    var execute = false
    var confirm: String?
    var json = false
    var strict = false
    var explain = false
}

struct AdoptResponse: Codable, Sendable {
    var version: String
    var generatedAt: String
    var executionMode: String
    var selectedAction: MigrationPlanEntry?
    var matchingActions: [MigrationPlanEntry]
    var executed: Bool
    var blocked: Bool
    var blockReasons: [String]
    var command: [String]
    var stdout: String
    var stderr: String
    var exitCode: Int?
}

struct AdoptCoordinator {
    func run(plan: MigrationPlan, options: AdoptOptions, brewAvailable: Bool, executor: BrewExecutor, generatedAt: Date = Date()) -> AdoptResponse {
        let matches = selectEntries(plan: plan, options: options)
        var reasons: [String] = []
        let selected = matches.count == 1 ? matches.first : nil

        if options.cask != nil && options.app != nil {
            reasons.append("use only one selector")
        }
        if options.execute && options.cask == nil && options.app == nil {
            reasons.append("select exactly one cask with --cask <token> or app with --app <name-or-bundle-id>")
        }
        if options.cask != nil || options.app != nil {
            if matches.isEmpty {
                reasons.append("selector matched no entries")
            } else if matches.count > 1 {
                reasons.append("selector matched multiple entries; use a more specific selector")
            }
        }

        if let selected {
            reasons += blockReasons(for: selected, brewAvailable: brewAvailable)
            if options.execute {
                let expected = "adopt \(selected.selectedCandidate?.token ?? "")"
                if options.confirm != expected {
                    reasons.append("confirmation required: --confirm \"\(expected)\"")
                }
            }
        }

        let command = selected.flatMap(commandArguments) ?? []
        let shouldExecute = options.execute && selected != nil && reasons.isEmpty
        let result = shouldExecute ? executor.run(arguments: command) : nil

        return AdoptResponse(
            version: BrewMatchVersion.value,
            generatedAt: ISO8601DateFormatter().string(from: generatedAt),
            executionMode: options.execute ? "execute" : "dry-run",
            selectedAction: selected,
            matchingActions: options.cask == nil && options.app == nil ? allCandidateEntries(plan) : matches,
            executed: shouldExecute,
            blocked: !reasons.isEmpty,
            blockReasons: reasons,
            command: command,
            stdout: result?.stdout ?? "",
            stderr: result?.stderr ?? "",
            exitCode: result.map { Int($0.exitCode) }
        )
    }

    private func blockReasons(for entry: MigrationPlanEntry, brewAvailable: Bool) -> [String] {
        var reasons: [String] = []
        if entry.status != .proposed {
            reasons.append("selected action is not proposed")
        }
        if entry.risk != .low {
            reasons.append("selected action risk is \(entry.risk.rawValue), required low")
        }
        if entry.selectedCandidate?.confidence != .high {
            reasons.append("selected candidate confidence is not high")
        }
        if ["ignored", "App Store app", "system app"].contains(entry.sourceClassification) {
            reasons.append("selected app source is \(entry.sourceClassification)")
        }
        if !brewAvailable {
            reasons.append("Homebrew not found")
        }
        return reasons
    }

    private func selectEntries(plan: MigrationPlan, options: AdoptOptions) -> [MigrationPlanEntry] {
        let entries = allEntries(plan)
        if let cask = options.cask {
            return entries.filter { $0.selectedCandidate?.token == cask }
        }
        if let app = options.app {
            return entries.filter {
                $0.appName == app || $0.bundleIdentifier == app
            }
        }
        return []
    }

    private func allCandidateEntries(_ plan: MigrationPlan) -> [MigrationPlanEntry] {
        allEntries(plan).filter { $0.selectedCandidate != nil }
    }

    private func allEntries(_ plan: MigrationPlan) -> [MigrationPlanEntry] {
        plan.proposedActions + plan.reviewRequiredActions + plan.skippedActions
    }

    private func commandArguments(for entry: MigrationPlanEntry) -> [String]? {
        guard entry.status == .proposed || entry.status == .reviewRequired else { return nil }
        guard let token = entry.selectedCandidate?.token else { return nil }
        return ["install", "--cask", "--adopt", token]
    }
}

struct AdoptRenderer {
    func text(_ response: AdoptResponse, explain: Bool = false) -> String {
        var lines = ["BrewMatch adopt"]

        if let selected = response.selectedAction {
            lines.append("Selected:")
            append(selected, to: &lines, explain: explain)
        } else if !response.matchingActions.isEmpty {
            lines.append("Available candidates:")
            response.matchingActions.forEach { append($0, to: &lines, explain: explain) }
        } else {
            lines.append("No matching adopt candidates.")
        }

        if !response.blockReasons.isEmpty {
            lines.append("Blocked:")
            lines.append(contentsOf: response.blockReasons.map { "- \($0)" })
        }

        if !response.command.isEmpty {
            lines.append("Command:")
            let commandText = "brew \(response.command.joined(separator: " "))"
            if response.selectedAction?.status == .reviewRequired {
                lines.append("# review required: \(commandText)")
            } else if response.selectedAction?.status == .proposed {
                lines.append(commandText)
            }
        }

        if response.executed {
            lines.append("Executed command.")
            if !response.stdout.isEmpty { lines.append("stdout:\n\(response.stdout)") }
            if !response.stderr.isEmpty { lines.append("stderr:\n\(response.stderr)") }
            if let exitCode = response.exitCode { lines.append("exitCode: \(exitCode)") }
            lines.append("Rerun `brewmatch scan` to verify.")
        } else {
            lines.append("No actions were executed.")
        }

        return lines.joined(separator: "\n") + "\n"
    }

    func json(_ response: AdoptResponse) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return String(decoding: try encoder.encode(response), as: UTF8.self)
    }

    private func append(_ entry: MigrationPlanEntry, to lines: inout [String], explain: Bool) {
        lines.append("- \(entry.appName) -> \(entry.selectedCandidate?.token ?? "<none>")")
        lines.append("  status: \(entry.status.rawValue)")
        lines.append("  risk: \(entry.risk.rawValue)")
        if let selected = entry.selectedCandidate {
            lines.append("  confidence: \(selected.confidence.rawValue)")
            lines.append("  reason: \(selected.reason)")
        }
        if entry.status == .proposed && entry.risk == .low, let token = entry.selectedCandidate?.token {
            lines.append("  command: brew install --cask --adopt \(token)")
        } else if entry.status == .reviewRequired, let token = entry.selectedCandidate?.token {
            lines.append("  command: # review required: brew install --cask --adopt \(token)")
        }
        if explain {
            lines.append("  source: \(entry.sourceClassification)")
            lines.append("  reasons:")
            lines.append(contentsOf: entry.reasons.map { "    - \($0)" })
        }
    }
}
