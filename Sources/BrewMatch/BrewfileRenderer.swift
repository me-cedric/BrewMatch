import Foundation

struct BrewfileOptions {
    var includeMedium = false
    var includeLow = false
    var includeAmbiguous = false
    var withComments = false
    var noHeader = false
}

struct BrewfileRenderer {
    func render(_ result: ScanResult, options: BrewfileOptions) -> String {
        var lines: [String] = []

        if !options.noHeader {
            lines += [
                "# BrewMatch suggested Brewfile",
                "# Generated from local macOS application scan",
                "# Review before running brew bundle",
                "# Active casks are high-confidence non-ambiguous suggestions by default",
                "",
            ]
        }

        let active = activeSuggestions(from: result.reports, options: options)
        for suggestion in active {
            if options.withComments {
                lines.append("# \(suggestion.apps.map(\.fileName).sorted().joined(separator: ", "))")
                lines.append("# bundle: \(suggestion.apps.compactMap(\.bundleIdentifier).sorted().joined(separator: ", ").nilIfEmpty ?? "<none>")")
                lines.append("# confidence: \(suggestion.match.confidence.rawValue)")
                lines.append("# reason: \(suggestion.match.reason)")
            }
            lines.append("cask \"\(suggestion.match.token)\"")
            lines.append("")
        }

        if options.includeAmbiguous {
            for report in ambiguousSuggestions(from: result.reports) {
                lines.append("# Ambiguous: \(report.app.fileName)")
                for match in report.matches {
                    lines.append("# candidate: \(match.token) confidence: \(match.confidence.rawValue) reason: \(match.reason)")
                }
                if let token = report.matches.first?.token {
                    lines.append("# cask \"\(token)\"")
                }
                lines.append("")
            }
        }

        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
    }

    private func activeSuggestions(from reports: [AppReport], options: BrewfileOptions) -> [BrewfileSuggestion] {
        let allowed: Set<MatchConfidence> = {
            var values: Set<MatchConfidence> = [.high]
            if options.includeMedium { values.insert(.medium) }
            if options.includeLow { values.insert(.low) }
            return values
        }()

        let pairs = reports.compactMap { report -> (ScannedApp, CaskMatch)? in
            guard report.status == .replaceable, let match = report.matches.first, allowed.contains(match.confidence) else { return nil }
            return (report.app, match)
        }

        let grouped = Dictionary(grouping: pairs, by: { $0.1.token })
        return grouped.map { token, pairs in
            let best = pairs.map(\.1).sorted {
                if $0.confidence == $1.confidence { return $0.reason < $1.reason }
                return $0.confidence > $1.confidence
            }.first ?? CaskMatch(token: token, confidence: .low, reason: "unknown")
            return BrewfileSuggestion(match: best, apps: pairs.map(\.0))
        }.sorted { $0.match.token < $1.match.token }
    }

    private func ambiguousSuggestions(from reports: [AppReport]) -> [AppReport] {
        reports
            .filter { $0.status == .ambiguous }
            .sorted { ($0.matches.first?.token ?? $0.app.fileName) < ($1.matches.first?.token ?? $1.app.fileName) }
    }
}

private struct BrewfileSuggestion {
    var match: CaskMatch
    var apps: [ScannedApp]
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
