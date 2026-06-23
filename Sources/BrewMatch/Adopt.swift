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

protocol AdoptPreflightChecking {
    func checks(for entry: MigrationPlanEntry) -> [AdoptPreflightCheck]
}

struct AdoptPreflightCheck: Codable, Equatable, Sendable {
    var name: String
    var passed: Bool
    var reason: String?
}

struct LocalAdoptPreflightChecker: AdoptPreflightChecking {
    var brew: BrewClient
    var fileManager: FileManager = .default

    func checks(for entry: MigrationPlanEntry) -> [AdoptPreflightCheck] {
        let token = entry.selectedCandidate?.token ?? ""
        return [
            brewExists(),
            caskExists(token),
            appExists(entry.path),
            notHomebrewManaged(entry),
            bundleIdentifierUnchanged(entry),
        ]
    }

    private func brewExists() -> AdoptPreflightCheck {
        AdoptPreflightCheck(
            name: "brew exists",
            passed: brew.isAvailable,
            reason: brew.isAvailable ? nil : "Homebrew not found"
        )
    }

    private func caskExists(_ token: String) -> AdoptPreflightCheck {
        let exists = !token.isEmpty && (brew.metadata(for: token) != nil || brew.availableCasks().contains { $0.token == token })
        return AdoptPreflightCheck(
            name: "cask exists",
            passed: exists,
            reason: exists ? nil : "cask token could not be resolved: \(token)"
        )
    }

    private func appExists(_ path: String) -> AdoptPreflightCheck {
        let exists = fileManager.fileExists(atPath: path)
        return AdoptPreflightCheck(
            name: "app exists",
            passed: exists,
            reason: exists ? nil : "app no longer exists at scanned path: \(path)"
        )
    }

    private func notHomebrewManaged(_ entry: MigrationPlanEntry) -> AdoptPreflightCheck {
        let installed = brew.installedCasks()
        let standardizedPath = URL(fileURLWithPath: entry.path).standardizedFileURL.path
        let managed = installed.contains { cask in
            cask.appPaths.map { URL(fileURLWithPath: $0).standardizedFileURL.path }.contains(standardizedPath)
                || entry.bundleIdentifier.map { cask.bundleIdentifiers.contains($0) } == true
        }
        return AdoptPreflightCheck(
            name: "not Homebrew-managed",
            passed: !managed,
            reason: managed ? "selected app is already Homebrew-managed" : nil
        )
    }

    private func bundleIdentifierUnchanged(_ entry: MigrationPlanEntry) -> AdoptPreflightCheck {
        guard let expected = entry.bundleIdentifier else {
            return AdoptPreflightCheck(name: "bundle identifier unchanged", passed: true, reason: nil)
        }
        let url = URL(fileURLWithPath: entry.path).appendingPathComponent("Contents/Info.plist")
        guard
            let data = try? Data(contentsOf: url),
            let object = try? PropertyListSerialization.propertyList(from: data, format: nil),
            let plist = object as? [String: Any],
            let actual = plist["CFBundleIdentifier"] as? String
        else {
            return AdoptPreflightCheck(name: "bundle identifier unchanged", passed: false, reason: "could not verify bundle identifier")
        }
        let passed = actual == expected
        return AdoptPreflightCheck(
            name: "bundle identifier unchanged",
            passed: passed,
            reason: passed ? nil : "bundle identifier changed from \(expected) to \(actual)"
        )
    }
}

struct AdoptOptions {
    var cask: String?
    var app: String?
    var execute = false
    var dryRun = false
    var confirm: String?
    var json = false
    var strict = false
    var explain = false
    var withCommands = false
    var systemChangeAcknowledged = false
    var requireCleanPlan = false
    var interactionRequired = false
    var interactiveConfirmed = true
}

struct AdoptSafetyGate: Codable, Equatable, Sendable {
    var name: String
    var passed: Bool
    var reason: String?
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
    var safetyGates: [AdoptSafetyGate]
    var preflightChecks: [AdoptPreflightCheck]
    var auditLogPath: String?
    var interactionRequired: Bool
    var showCopyableCommands: Bool
}

struct AdoptCoordinator {
    func run(plan: MigrationPlan, options: AdoptOptions, preflight: AdoptPreflightChecking, executor: BrewExecutor, generatedAt: Date = Date()) -> AdoptResponse {
        let matches = selectEntries(plan: plan, options: options)
        let selected = matches.count == 1 ? matches.first : nil
        let command = selected.flatMap(commandArguments) ?? []
        let safetyGates = gates(plan: plan, options: options, matches: matches, selected: selected, command: command)
        let gateReasons: [String] = safetyGates.compactMap { gate in
            if gate.passed { return nil }
            if gate.name == "clean plan" && !options.execute { return nil }
            return gate.reason
        }
        let preflightChecks = options.execute && selected != nil && gateReasons.isEmpty ? preflight.checks(for: selected!) : []
        let preflightReasons = preflightChecks.compactMap { $0.passed ? nil : $0.reason }
        let reasons = gateReasons + preflightReasons
        let shouldExecute = options.execute && !options.dryRun && selected != nil && reasons.isEmpty
        let result = shouldExecute ? executor.run(arguments: command) : nil

        return AdoptResponse(
            version: BrewMatchVersion.value,
            generatedAt: ISO8601DateFormatter().string(from: generatedAt),
            executionMode: shouldExecute || options.execute ? "execute" : "dry-run",
            selectedAction: selected,
            matchingActions: options.cask == nil && options.app == nil ? allCandidateEntries(plan) : matches,
            executed: shouldExecute,
            blocked: !reasons.isEmpty,
            blockReasons: reasons,
            command: command,
            stdout: result?.stdout ?? "",
            stderr: result?.stderr ?? "",
            exitCode: result.map { Int($0.exitCode) },
            safetyGates: safetyGates,
            preflightChecks: preflightChecks,
            auditLogPath: nil,
            interactionRequired: options.interactionRequired,
            showCopyableCommands: options.withCommands
        )
    }

    private func gates(
        plan: MigrationPlan,
        options: AdoptOptions,
        matches: [MigrationPlanEntry],
        selected: MigrationPlanEntry?,
        command: [String]
    ) -> [AdoptSafetyGate] {
        var gates: [AdoptSafetyGate] = []
        gates.append(gate("mode conflict", !(options.dryRun && options.execute), "Cannot pass both --dry-run and --execute."))

        if options.cask != nil && options.app != nil {
            gates.append(gate("single selector", false, "use only one selector"))
        } else if options.execute && options.cask == nil && options.app == nil {
            gates.append(gate("single selector", false, "select exactly one cask with --cask <token> or app with --app <name-or-bundle-id>"))
        } else if options.cask != nil || options.app != nil {
            if matches.isEmpty {
                gates.append(gate("selector matched", false, "selector matched no entries"))
            } else if matches.count > 1 {
                gates.append(gate("selector matched", false, "selector matched multiple entries; use a more specific selector"))
            } else {
                gates.append(gate("selector matched", true, nil))
            }
        }

        guard options.execute else {
            if options.requireCleanPlan {
                gates.append(cleanPlanGate(plan: plan, selected: selected))
            }
            return gates
        }

        gates.append(gate("system-change acknowledgement", options.systemChangeAcknowledged, "system-change acknowledgement required: --i-understand-this-may-change-my-system"))

        if let selected {
            gates.append(gate("status proposed", selected.status == .proposed, "selected action is not proposed"))
            gates.append(gate("risk low", selected.risk == .low, "selected action risk is \(selected.risk.rawValue), required low"))
            gates.append(gate("confidence high", selected.selectedCandidate?.confidence == .high, "selected candidate confidence is not high"))
            gates.append(gate("source allowed", !["ignored", "App Store app", "system app"].contains(selected.sourceClassification), "selected app source is \(selected.sourceClassification)"))
            let token = selected.selectedCandidate?.token ?? ""
            gates.append(gate("confirmation phrase", options.confirm == "adopt \(token)", "confirmation required: --confirm \"adopt \(token)\""))
            gates.append(gate("exact command", command == ["install", "--cask", "--adopt", token], "execution command must be exactly brew install --cask --adopt \(token)"))
        }

        if options.requireCleanPlan {
            gates.append(cleanPlanGate(plan: plan, selected: selected))
        }
        if options.interactionRequired {
            gates.append(gate("interactive confirmation", options.interactiveConfirmed, "interactive confirmation required: type ADOPT"))
        }

        return gates
    }

    private func cleanPlanGate(plan: MigrationPlan, selected: MigrationPlanEntry?) -> AdoptSafetyGate {
        var reasons: [String] = []
        if !plan.reviewRequiredActions.isEmpty {
            reasons.append("reviewRequired entries exist")
        }
        if !plan.warnings.isEmpty {
            reasons.append("plan warnings exist")
        }
        if selected?.alternativeCandidates.isEmpty == false {
            reasons.append("selected app has alternative candidates")
        }
        return gate("clean plan", reasons.isEmpty, reasons.isEmpty ? nil : "require-clean-plan failed: \(reasons.joined(separator: "; "))")
    }

    private func gate(_ name: String, _ passed: Bool, _ reason: String?) -> AdoptSafetyGate {
        AdoptSafetyGate(name: name, passed: passed, reason: passed ? nil : reason)
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

        if explain && !response.safetyGates.isEmpty {
            lines.append("Safety gates:")
            lines.append(contentsOf: response.safetyGates.map { "- \($0.name): \($0.passed ? "passed" : "failed")\($0.reason.map { " (\($0))" } ?? "")" })
        }

        if !response.preflightChecks.isEmpty {
            lines.append("Preflight checks:")
            lines.append(contentsOf: response.preflightChecks.map { "- \($0.name): \($0.passed ? "passed" : "failed")\($0.reason.map { " (\($0))" } ?? "")" })
        }

        if !response.blockReasons.isEmpty {
            lines.append("Blocked:")
            lines.append(contentsOf: response.blockReasons.map { "- \($0)" })
        }

        if !response.command.isEmpty {
            lines.append("Command:")
            let commandText = "brew \(response.command.joined(separator: " "))"
            if response.selectedAction?.status == .proposed && !response.blocked {
                lines.append(commandText)
            } else {
                lines.append("# review required: \(commandText)")
            }
        }

        let copyable = copyableCommands(response)
        if !copyable.isEmpty {
            lines.append("Copyable commands:")
            lines.append(contentsOf: copyable)
        }

        if let auditLogPath = response.auditLogPath {
            lines.append("Audit log: \(auditLogPath)")
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

    private func copyableCommands(_ response: AdoptResponse) -> [String] {
        guard response.showCopyableCommands, response.executionMode == "dry-run" else { return [] }
        let entries = (response.selectedAction.map { [$0] } ?? response.matchingActions)
        return entries.compactMap { entry in
            guard entry.status == .proposed, entry.risk == .low, let token = entry.selectedCandidate?.token else { return nil }
            return "brew install --cask --adopt \(token)"
        }
    }
}

struct AdoptAuditLogger {
    func write(_ response: AdoptResponse, to url: URL, force: Bool) throws {
        try Exporter().write(try AdoptRenderer().json(response), to: url, force: force)
    }
}
