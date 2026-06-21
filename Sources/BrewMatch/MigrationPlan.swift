import Foundation

enum MigrationRisk: String, Codable, Equatable, Sendable {
    case low
    case medium
    case high
    case reviewRequired = "review-required"
}

enum MigrationPlanStatus: String, Codable, Equatable, Sendable {
    case proposed
    case skipped
    case reviewRequired
}

enum MigrationCommandKind: String, Codable, Equatable, Sendable {
    case active
    case commented
    case none
}

struct MigrationPlanOptions {
    var includeMedium = false
    var includeLow = false
    var includeAmbiguous = false
    var withCommands = false
    var strict = false
    var explain = false
}

struct MigrationPlan: Codable, Sendable {
    var schemaVersion: String
    var version: String
    var generatedAt: String
    var safetyMode: String
    var proposedActions: [MigrationPlanEntry]
    var reviewRequiredActions: [MigrationPlanEntry]
    var skippedActions: [MigrationPlanEntry]
    var warnings: [String]
}

struct MigrationPlanEntry: Codable, Equatable, Sendable {
    var appName: String
    var bundleIdentifier: String?
    var path: String
    var sourceClassification: String
    var status: MigrationPlanStatus
    var risk: MigrationRisk
    var selectedCandidate: CaskMatch?
    var alternativeCandidates: [CaskMatch]
    var commandKind: MigrationCommandKind
    var command: String?
    var reasons: [String]
}

struct MigrationPlanner {
    func build(_ result: ScanResult, options: MigrationPlanOptions, generatedAt: Date = Date()) -> MigrationPlan {
        var proposed: [MigrationPlanEntry] = []
        var reviewRequired: [MigrationPlanEntry] = []
        var skipped: [MigrationPlanEntry] = []

        for report in result.reports {
            switch report.status {
            case .replaceable:
                placeReplaceable(report, options: options, proposed: &proposed, reviewRequired: &reviewRequired, skipped: &skipped)
            case .ambiguous:
                reviewRequired.append(entry(report, status: .reviewRequired, risk: .reviewRequired, reason: "ambiguous candidates", commandKind: .commented, options: options))
            default:
                skipped.append(entry(report, status: .skipped, risk: skippedRisk(report), reason: skipReason(report), commandKind: .none, options: options))
            }
        }

        return MigrationPlan(
            schemaVersion: "1",
            version: BrewMatchVersion.value,
            generatedAt: ISO8601DateFormatter().string(from: generatedAt),
            safetyMode: "dry-run",
            proposedActions: proposed.sorted { lhs, rhs in
                (lhs.selectedCandidate?.token ?? lhs.appName) < (rhs.selectedCandidate?.token ?? rhs.appName)
            },
            reviewRequiredActions: reviewRequired.sorted { $0.appName < $1.appName },
            skippedActions: skipped.sorted { $0.appName < $1.appName },
            warnings: result.warnings
        )
    }

    private func placeReplaceable(
        _ report: AppReport,
        options: MigrationPlanOptions,
        proposed: inout [MigrationPlanEntry],
        reviewRequired: inout [MigrationPlanEntry],
        skipped: inout [MigrationPlanEntry]
    ) {
        guard let match = report.matches.first else {
            skipped.append(entry(report, status: .skipped, risk: .reviewRequired, reason: "no candidate", commandKind: .none, options: options))
            return
        }

        if match.confidence == .medium && !options.includeMedium {
            skipped.append(entry(report, status: .skipped, risk: .reviewRequired, reason: "confidence below threshold", commandKind: .none, options: options))
            return
        }

        if match.confidence == .low && !options.includeLow {
            skipped.append(entry(report, status: .skipped, risk: .reviewRequired, reason: "confidence below threshold", commandKind: .none, options: options))
            return
        }

        let risk = riskFor(match)
        if match.confidence != .high {
            reviewRequired.append(entry(report, status: .reviewRequired, risk: .reviewRequired, reason: "confidence requires review", commandKind: .commented, options: options))
        } else if options.strict && risk != .low {
            reviewRequired.append(entry(report, status: .reviewRequired, risk: risk, reason: "excluded by strict mode", commandKind: .commented, options: options))
        } else {
            proposed.append(entry(report, status: .proposed, risk: risk, reason: "eligible dry-run candidate", commandKind: .active, options: options))
        }
    }

    private func entry(
        _ report: AppReport,
        status: MigrationPlanStatus,
        risk: MigrationRisk,
        reason: String,
        commandKind: MigrationCommandKind,
        options: MigrationPlanOptions
    ) -> MigrationPlanEntry {
        let selected = report.matches.first
        let command: String? = if options.withCommands, let token = selected?.token {
            switch commandKind {
            case .active:
                "brew install --cask --adopt \(token)"
            case .commented:
                "# review required: brew install --cask --adopt \(token)"
            case .none:
                nil
            }
        } else {
            nil
        }

        return MigrationPlanEntry(
            appName: report.app.fileName,
            bundleIdentifier: report.app.bundleIdentifier,
            path: report.app.path,
            sourceClassification: sourceClassification(report),
            status: status,
            risk: risk,
            selectedCandidate: selected,
            alternativeCandidates: Array(report.matches.dropFirst()),
            commandKind: options.withCommands ? commandKind : .none,
            command: command,
            reasons: reasons(report, primary: reason, risk: risk, status: status)
        )
    }

    private func reasons(_ report: AppReport, primary: String, risk: MigrationRisk, status: MigrationPlanStatus) -> [String] {
        var values = [primary, "status: \(status.rawValue)", "risk: \(risk.rawValue)", "source: \(sourceClassification(report))"]
        if let match = report.matches.first {
            values.append("confidence: \(match.confidence.rawValue)")
            values.append("match: \(match.reason)")
        }
        return values
    }

    private func riskFor(_ match: CaskMatch) -> MigrationRisk {
        if match.confidence == .high && match.reason == "exact bundle identifier match" {
            return .low
        }
        if match.confidence == .high {
            return .medium
        }
        return .reviewRequired
    }

    private func skippedRisk(_ report: AppReport) -> MigrationRisk {
        switch report.status {
        case .skippedAppStore, .skippedSystem:
            return .reviewRequired
        default:
            return .reviewRequired
        }
    }

    private func sourceClassification(_ report: AppReport) -> String {
        switch report.status {
        case .homebrewManaged:
            return "Homebrew managed"
        case .skippedSystem:
            return "system app"
        case .skippedAppStore:
            return "App Store app"
        case .ignored:
            return "ignored"
        default:
            return "manual app"
        }
    }

    private func skipReason(_ report: AppReport) -> String {
        switch report.status {
        case .homebrewManaged:
            return "already managed by Homebrew"
        case .skippedSystem:
            return "system app"
        case .skippedAppStore:
            return "App Store app"
        case .ignored:
            return "ignored"
        case .noCandidate:
            return "no candidate"
        case .replaceable, .ambiguous:
            return report.matchReason ?? "skipped"
        }
    }
}

struct MigrationPlanRenderer {
    func text(_ plan: MigrationPlan, explain: Bool = false) -> String {
        var lines = [
            "BrewMatch migration plan",
            "No actions will be executed.",
            "",
        ]

        if !plan.warnings.isEmpty {
            lines.append("Warnings:")
            lines.append(contentsOf: plan.warnings.map { "- \($0)" })
            lines.append("")
        }

        append("Proposed:", plan.proposedActions, explain: explain, to: &lines)
        lines.append("")
        append("Review required:", plan.reviewRequiredActions, explain: explain, to: &lines)
        lines.append("")
        append("Skipped:", plan.skippedActions, explain: explain, to: &lines)

        return lines.joined(separator: "\n") + "\n"
    }

    func json(_ plan: MigrationPlan) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return String(decoding: try encoder.encode(plan), as: UTF8.self)
    }

    private func append(_ title: String, _ entries: [MigrationPlanEntry], explain: Bool, to lines: inout [String]) {
        lines.append(title)
        guard !entries.isEmpty else {
            lines.append("- none")
            return
        }

        for entry in entries {
            let token = entry.selectedCandidate.map { " -> \($0.token)" } ?? ""
            lines.append("- \(entry.appName)\(token)")
            lines.append("  status: \(entry.status.rawValue)")
            lines.append("  risk: \(entry.risk.rawValue)")
            if let selected = entry.selectedCandidate {
                lines.append("  confidence: \(selected.confidence.rawValue)")
                lines.append("  reason: \(selected.reason)")
            }
            if let command = entry.command {
                lines.append("  command: \(command)")
            }
            if explain {
                lines.append("  source: \(entry.sourceClassification)")
                lines.append("  reasons:")
                lines.append(contentsOf: entry.reasons.map { "    - \($0)" })
            }
        }
    }
}
