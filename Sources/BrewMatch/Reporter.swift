import Foundation

struct Reporter {
    func build(apps: [ScannedApp], brew: BrewClient, ignoreList: IgnoreList = .empty) -> ScanResult {
        let installed = brew.installedCasks()
        let installedTokens = Set(installed.map { Normalizer.key($0.token) })
        let installedPaths = Set(installed.flatMap(\.appPaths).map { URL(fileURLWithPath: $0).standardizedFileURL.path })
        let installedBundleIDs = Set(installed.flatMap(\.bundleIdentifiers))
        let installedNames = Set(installed.flatMap { [$0.token] + $0.names + $0.appNames }.map(Normalizer.key))

        let available = brew.availableCasks()
        let availableByToken = Dictionary(uniqueKeysWithValues: available.map { ($0.token, $0) })
        let matcher = AppMatcher(casks: available)

        let reports = apps.map { app in
            if ignoreList.contains(app) {
                return AppReport(status: .ignored, app: app, matches: [], matchReason: "ignored by ignore file")
            }

            if app.isSystemApp {
                return AppReport(status: .skippedSystem, app: app, matches: [], matchReason: "system app")
            }

            if app.hasMASReceipt {
                return AppReport(status: .skippedAppStore, app: app, matches: [], matchReason: "App Store app")
            }

            if installedPaths.contains(app.path)
                || app.bundleIdentifier.map(installedBundleIDs.contains) == true
                || appNameKeys(app).contains(where: installedTokens.contains)
                || appNameKeys(app).contains(where: installedNames.contains) {
                return AppReport(status: .homebrewManaged, app: app, matches: [], matchReason: "managed by Homebrew cask")
            }

            let initialMatches = matcher.matches(for: app)
            let enriched = initialMatches.map { match in
                brew.metadata(for: match.token) ?? availableByToken[match.token] ?? CaskMetadata(token: match.token)
            }
            let matches = enriched.isEmpty ? initialMatches : AppMatcher(casks: enriched).matches(for: app)

            guard let best = matches.first else {
                return AppReport(status: .noCandidate, app: app, matches: [], matchReason: brew.isAvailable ? "no candidate" : "Homebrew matching unavailable")
            }

            let tied = matches.filter { $0.confidence == best.confidence }
            let ambiguous = (best.confidence == .high || best.confidence == .medium) && tied.count > 1
            return AppReport(
                status: ambiguous ? .ambiguous : .replaceable,
                app: app,
                matches: matches,
                matchReason: best.reason
            )
        }

        return ScanResult(summary: summary(for: reports), warnings: brew.warnings(), reports: reports)
    }

    func text(_ result: ScanResult) -> String {
        let reports = result.reports
        var lines: [String] = ["Found \(result.summary.totalApps) apps.", ""]

        if !result.warnings.isEmpty {
            lines.append("Warnings:")
            lines.append(contentsOf: result.warnings.map { "- \($0)" })
            lines.append("")
        }

        lines.append("Summary:")
        lines.append("- Homebrew managed: \(result.summary.homebrewManaged)")
        lines.append("- Replaceable high confidence: \(result.summary.replaceableHighConfidence)")
        lines.append("- Replaceable medium confidence: \(result.summary.replaceableMediumConfidence)")
        lines.append("- Ambiguous: \(result.summary.ambiguous)")
        lines.append("- App Store skipped: \(result.summary.appStoreSkipped)")
        lines.append("- System skipped: \(result.summary.systemSkipped)")
        lines.append("- Ignored: \(result.summary.ignored)")
        lines.append("- No match: \(result.summary.noMatch)")
        lines.append("")

        section("Already managed by Homebrew:", reports.filter { $0.status == .homebrewManaged }, into: &lines) {
            "✓ \($0.app.fileName)"
        }

        section("Replaceable by Homebrew:", reports.filter { $0.status == .replaceable }, into: &lines) {
            guard let match = $0.matches.first else { return "✓ \($0.app.fileName)" }
            return "✓ \(pad($0.app.fileName)) -> \(pad(match.token, 24)) \(match.confidence.rawValue)"
        }

        section("Ambiguous candidate:", reports.filter { $0.status == .ambiguous }, into: &lines) {
            "? \($0.app.fileName) -> \($0.matches.map { "\($0.token) \($0.confidence.rawValue)" }.joined(separator: ", "))"
        }

        section("Ignored:", reports.filter { $0.status == .ignored }, into: &lines) {
            "- \($0.app.fileName) \($0.matchReason ?? "ignored")"
        }

        section("Skipped:", reports.filter { $0.status == .skippedSystem || $0.status == .skippedAppStore }, into: &lines) {
            "- \($0.app.fileName) \($0.matchReason ?? "skipped")"
        }

        section("No match:", reports.filter { $0.status == .noCandidate }, into: &lines) {
            "- \($0.app.fileName)"
        }

        return lines.joined(separator: "\n")
    }

    func json(_ result: ScanResult) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return String(decoding: try encoder.encode(result), as: UTF8.self)
    }

    private func summary(for reports: [AppReport]) -> ReportSummary {
        ReportSummary(
            totalApps: reports.count,
            homebrewManaged: reports.filter { $0.status == .homebrewManaged }.count,
            replaceableHighConfidence: reports.filter { $0.status == .replaceable && $0.matches.first?.confidence == .high }.count,
            replaceableMediumConfidence: reports.filter { $0.status == .replaceable && $0.matches.first?.confidence == .medium }.count,
            ambiguous: reports.filter { $0.status == .ambiguous }.count,
            appStoreSkipped: reports.filter { $0.status == .skippedAppStore }.count,
            systemSkipped: reports.filter { $0.status == .skippedSystem }.count,
            ignored: reports.filter { $0.status == .ignored }.count,
            noMatch: reports.filter { $0.status == .noCandidate }.count
        )
    }

    private func appNameKeys(_ app: ScannedApp) -> [String] {
        [app.displayName, app.bundleName, app.fileName].compactMap { $0 }.map(Normalizer.key)
    }

    private func section(_ title: String, _ reports: [AppReport], into lines: inout [String], render: (AppReport) -> String) {
        guard !reports.isEmpty else { return }
        lines.append(title)
        lines.append(contentsOf: reports.map(render))
        lines.append("")
    }
}

private func pad(_ value: String, _ length: Int = 24) -> String {
    value.padding(toLength: max(length, value.count + 1), withPad: " ", startingAt: 0)
}
