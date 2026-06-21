import Foundation
import Testing
@testable import BrewMatch

@Test func normalizationStripsAppAndPunctuation() {
    #expect(Normalizer.words("Visual Studio Code.app") == ["visual", "studio", "code"])
    #expect(Normalizer.key("Visual Studio Code.app") == "visualstudiocode")
    #expect(Normalizer.key("visual-studio-code") == "visualstudiocode")
}

@Test func matcherRanksBundleArtifactTokenMediumAndFuzzyMatches() {
    let matcher = AppMatcher(casks: [
        CaskMetadata(token: "firefox", bundleIdentifiers: ["org.mozilla.firefox"]),
        CaskMetadata(token: "cursor-editor"),
        CaskMetadata(token: "visual-studio-code", appNames: ["Code.app"]),
        CaskMetadata(token: "fireflop"),
    ])

    #expect(matcher.matches(for: app("Firefox.app", bundleID: "org.mozilla.firefox")).first == CaskMatch(token: "firefox", confidence: .high, reason: "exact bundle identifier match"))
    #expect(matcher.matches(for: app("Code.app")).first == CaskMatch(token: "visual-studio-code", confidence: .high, reason: "exact app display name match from cask artifact"))
    #expect(matcher.matches(for: app("Cursor.app")).first == CaskMatch(token: "cursor-editor", confidence: .medium, reason: "prefix/contains normalized match"))
    #expect(matcher.matches(for: app("Fireflox.app")).first == CaskMatch(token: "fireflop", confidence: .low, reason: "fuzzy weak match"))
}

@Test func scannerReadsFixtureInfoPlistAndMASReceipt() throws {
    let root = try temporaryDirectory()
    let app = root.appendingPathComponent("Sample.app")
    let contents = app.appendingPathComponent("Contents")
    let receipt = contents.appendingPathComponent("_MASReceipt/receipt")
    try FileManager.default.createDirectory(at: receipt.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data().write(to: receipt)
    try FileManager.default.copyItem(
        at: Bundle.module.url(forResource: "SampleInfo", withExtension: "plist", subdirectory: "Fixtures")!,
        to: contents.appendingPathComponent("Info.plist")
    )

    let scanned = AppScanner().readApp(app)
    #expect(scanned.fileName == "Sample.app")
    #expect(scanned.displayName == "Sample Tool")
    #expect(scanned.bundleIdentifier == "com.example.sampletool")
    #expect(scanned.version == "1.2.3")
    #expect(scanned.hasMASReceipt)
    #expect(!scanned.isSystemApp)
}

@Test func scannerFindsAppsOnlyOneLevelDeep() throws {
    let root = try temporaryDirectory()
    try makeApp(root.appendingPathComponent("Top.app"))
    try makeApp(root.appendingPathComponent("Folder/Nested.app"))
    try makeApp(root.appendingPathComponent("Folder/TooDeep/Deep.app"))

    let names = AppScanner().appURLs(in: root).map(\.lastPathComponent).sorted()
    #expect(names == ["Nested.app", "Top.app"])
}

@Test func scannerDetectsProtectedAppleBundleIDAsSystemApp() throws {
    let root = try temporaryDirectory()
    let app = root.appendingPathComponent("Safari.app")
    try makeApp(app, bundleID: "com.apple.Safari")

    #expect(AppScanner().readApp(app).isSystemApp)
}

@Test func exportRefusesOverwrite() throws {
    let url = try temporaryDirectory().appendingPathComponent("report.txt")
    try "old".write(to: url, atomically: true, encoding: .utf8)

    do {
        try Exporter().write("new", to: url, force: false)
        Issue.record("Expected overwrite refusal")
    } catch CLIError.outputExists(let path) {
        #expect(path == url.path)
    }
}

@Test func exportForceOverwrites() throws {
    let url = try temporaryDirectory().appendingPathComponent("report.txt")
    try "old".write(to: url, atomically: true, encoding: .utf8)

    try Exporter().write("new", to: url, force: true)
    #expect(try String(contentsOf: url, encoding: .utf8) == "new")
}

@Test func ignoreByBundleIDNameAndPath() {
    let ignored = IgnoreList(values: Set([
        "com.example.bundle",
        Normalizer.key("Named App"),
        "/Applications/Path.app",
    ]))

    #expect(ignored.contains(app("Bundle.app", bundleID: "com.example.bundle")))
    #expect(ignored.contains(app("Named App.app")))
    #expect(ignored.contains(app("Path.app", path: "/Applications/Path.app")))

    let result = Reporter().build(
        apps: [app("Bundle.app", bundleID: "com.example.bundle")],
        brew: MockBrewClient(available: [CaskMetadata(token: "bundle")]),
        ignoreList: ignored
    )
    #expect(result.reports.first?.status == .ignored)
}

@Test func malformedIgnoreFileFails() throws {
    let url = try temporaryDirectory().appendingPathComponent("ignore.json")
    try "{ nope".write(to: url, atomically: true, encoding: .utf8)

    do {
        _ = try IgnoreList.load(from: url)
        Issue.record("Expected malformed ignore file")
    } catch CLIError.malformedIgnoreFile(let path) {
        #expect(path == url.path)
    }
}

@Test func ambiguousHighMatchDetected() {
    let result = Reporter().build(
        apps: [app("Thing.app")],
        brew: MockBrewClient(available: [
            CaskMetadata(token: "thing"),
            CaskMetadata(token: "thing-app", appNames: ["Thing.app"]),
        ])
    )

    #expect(result.reports.first?.status == .ambiguous)
    #expect(result.reports.first?.matches.count == 2)
}

@Test func brewMissingAddsWarningAndNoCandidate() throws {
    let result = Reporter().build(
        apps: [app("Firefox.app")],
        brew: MockBrewClient(isAvailable: false, warningList: ["Homebrew not found. Homebrew matching unavailable."])
    )

    #expect(result.warnings == ["Homebrew not found. Homebrew matching unavailable."])
    #expect(result.reports.first?.status == .noCandidate)
    #expect(try Reporter().json(result).contains("\"warnings\""))
    #expect(Reporter().text(result).contains("Warnings:"))
}

@Test func summaryCountsAreCorrect() {
    let apps = [
        app("Managed.app"),
        app("Firefox.app", bundleID: "org.mozilla.firefox"),
        app("Cursor.app"),
        app("Ambiguous.app"),
        app("Store.app", mas: true),
        app("Safari.app", system: true),
        app("Ignored.app"),
        app("Custom.app"),
    ]
    let result = Reporter().build(
        apps: apps,
        brew: MockBrewClient(
            installed: [CaskMetadata(token: "managed", appPaths: ["/Applications/Managed.app"])],
            available: [
                CaskMetadata(token: "firefox", bundleIdentifiers: ["org.mozilla.firefox"]),
                CaskMetadata(token: "cursor-editor"),
                CaskMetadata(token: "ambiguous", appNames: ["Ambiguous.app"]),
                CaskMetadata(token: "ambiguous-alt", appNames: ["Ambiguous.app"]),
            ]
        ),
        ignoreList: IgnoreList(values: [Normalizer.key("Ignored.app")])
    )

    #expect(result.summary == ReportSummary(
        totalApps: 8,
        homebrewManaged: 1,
        replaceableHighConfidence: 1,
        replaceableMediumConfidence: 1,
        ambiguous: 1,
        appStoreSkipped: 1,
        systemSkipped: 1,
        ignored: 1,
        noMatch: 1
    ))
}

@Test func brewfileIncludesHighConfidenceByDefault() {
    let brewfile = BrewfileRenderer().render(brewfileResult(), options: BrewfileOptions(noHeader: true))
    #expect(brewfile.contains("cask \"firefox\""))
}

@Test func brewfileExcludesMediumLowAndAmbiguousByDefault() {
    let brewfile = BrewfileRenderer().render(brewfileResult(), options: BrewfileOptions(noHeader: true))
    #expect(!brewfile.contains("cask \"cursor-editor\""))
    #expect(!brewfile.contains("cask \"fireflop\""))
    #expect(!brewfile.contains("Ambiguous:"))
}

@Test func brewfileIncludeMediumIncludesMedium() {
    let brewfile = BrewfileRenderer().render(
        brewfileResult(),
        options: BrewfileOptions(includeMedium: true, noHeader: true)
    )
    #expect(brewfile.contains("cask \"cursor-editor\""))
}

@Test func brewfileIncludeLowIncludesLow() {
    let brewfile = BrewfileRenderer().render(
        brewfileResult(),
        options: BrewfileOptions(includeLow: true, noHeader: true)
    )
    #expect(brewfile.contains("cask \"fireflop\""))
}

@Test func brewfileIncludeAmbiguousOutputsCommentedCandidates() {
    let brewfile = BrewfileRenderer().render(
        brewfileResult(),
        options: BrewfileOptions(includeAmbiguous: true, noHeader: true)
    )
    #expect(brewfile.contains("# Ambiguous: Cursor.app"))
    #expect(brewfile.contains("# candidate: cursor confidence: medium reason: normalized app name match"))
    #expect(brewfile.contains("# cask \"cursor\""))
    #expect(!brewfile.contains("\ncask \"cursor\""))
}

@Test func brewfileExcludesIgnoredMASSystemHomebrewAndNoMatchApps() {
    let brewfile = BrewfileRenderer().render(
        brewfileResult(),
        options: BrewfileOptions(includeMedium: true, includeLow: true, includeAmbiguous: true, noHeader: true)
    )
    #expect(!brewfile.contains("ignored-cask"))
    #expect(!brewfile.contains("store-cask"))
    #expect(!brewfile.contains("safari-cask"))
    #expect(!brewfile.contains("managed-cask"))
    #expect(!brewfile.contains("custom-cask"))
}

@Test func brewfileDuplicateCasksCollapsed() {
    let result = ScanResult(summary: emptySummary(2), warnings: [], reports: [
        report("Firefox.app", token: "firefox", confidence: .high),
        report("Firefox Beta.app", token: "firefox", confidence: .high),
    ])

    let brewfile = BrewfileRenderer().render(result, options: BrewfileOptions(withComments: true, noHeader: true))
    #expect(occurrences(of: "cask \"firefox\"", in: brewfile) == 1)
    #expect(brewfile.contains("# Firefox Beta.app, Firefox.app"))
}

@Test func brewfileOutputRefusesOverwriteWithoutForce() throws {
    let url = try temporaryDirectory().appendingPathComponent("Brewfile")
    try "old".write(to: url, atomically: true, encoding: .utf8)

    do {
        try Exporter().write("cask \"firefox\"\n", to: url, force: false)
        Issue.record("Expected overwrite refusal")
    } catch CLIError.outputExists(let path) {
        #expect(path == url.path)
    }
}

@Test func brewfileOutputOverwritesWithForce() throws {
    let url = try temporaryDirectory().appendingPathComponent("Brewfile")
    try "old".write(to: url, atomically: true, encoding: .utf8)

    try Exporter().write("cask \"firefox\"\n", to: url, force: true)
    #expect(try String(contentsOf: url, encoding: .utf8) == "cask \"firefox\"\n")
}

@Test func brewfileNoHeaderOmitsHeader() {
    let brewfile = BrewfileRenderer().render(brewfileResult(), options: BrewfileOptions(noHeader: true))
    #expect(!brewfile.contains("# BrewMatch suggested Brewfile"))
}

@Test func brewfileWithCommentsRendersAppMetadata() {
    let brewfile = BrewfileRenderer().render(
        brewfileResult(),
        options: BrewfileOptions(withComments: true, noHeader: true)
    )
    #expect(brewfile.contains("# Firefox.app"))
    #expect(brewfile.contains("# bundle: org.mozilla.firefox"))
    #expect(brewfile.contains("# confidence: high"))
    #expect(brewfile.contains("# reason: exact bundle identifier match"))
}

@Test func suggestionsAliasDefaultsToComments() throws {
    let options = try CLIOptions.parse(["suggestions"])
    #expect(options.command == "suggestions")
    #expect(options.withComments)
}

@Test func versionProviderAndOptions() throws {
    #expect(BrewMatchVersion.value == "0.2.0")
    #expect(BrewMatchVersion.display == "BrewMatch 0.2.0")
    #expect(try CLIOptions.parse(["--version"]).command == "version")
    #expect(try CLIOptions.parse(["version"]).command == "version")
}

@Test func planIncludesHighConfidenceByDefault() {
    let plan = MigrationPlanner().build(brewfileResult(), options: MigrationPlanOptions())
    #expect(plan.proposedActions.map { $0.selectedCandidate?.token } == ["firefox"])
}

@Test func planExcludesMediumAndLowByDefault() {
    let plan = MigrationPlanner().build(brewfileResult(), options: MigrationPlanOptions())
    #expect(!plan.proposedActions.contains { $0.selectedCandidate?.token == "cursor-editor" })
    #expect(!plan.proposedActions.contains { $0.selectedCandidate?.token == "fireflop" })
}

@Test func planIncludeMediumWorks() {
    let plan = MigrationPlanner().build(brewfileResult(), options: MigrationPlanOptions(includeMedium: true))
    #expect(plan.reviewRequiredActions.contains { $0.selectedCandidate?.token == "cursor-editor" })
}

@Test func planIncludeLowWorks() {
    let plan = MigrationPlanner().build(brewfileResult(), options: MigrationPlanOptions(includeLow: true))
    #expect(plan.reviewRequiredActions.contains { $0.selectedCandidate?.token == "fireflop" })
}

@Test func planAmbiguousBecomesReviewRequired() {
    let plan = MigrationPlanner().build(brewfileResult(), options: MigrationPlanOptions())
    #expect(plan.reviewRequiredActions.contains { $0.appName == "Cursor.app" && $0.reasons.contains("ambiguous candidates") })
}

@Test func planIncludeAmbiguousKeepsReviewNeededNotExecutable() {
    let plan = MigrationPlanner().build(brewfileResult(), options: MigrationPlanOptions(includeAmbiguous: true, withCommands: true))
    let review = plan.reviewRequiredActions.first { $0.appName == "Cursor.app" && $0.selectedCandidate?.token == "cursor" }
    #expect(review?.alternativeCandidates.map(\.token) == ["cursor-cli"])
    #expect(!plan.proposedActions.contains { $0.selectedCandidate?.token == "cursor" })
}

@Test func planJSONContainsDryRunSafetyMode() throws {
    let plan = MigrationPlanner().build(
        brewfileResult(),
        options: MigrationPlanOptions(),
        generatedAt: Date(timeIntervalSince1970: 0)
    )
    let json = try MigrationPlanRenderer().json(plan)
    #expect(json.contains("\"safetyMode\" : \"dry-run\""))
    #expect(json.contains("\"schemaVersion\" : \"1\""))
    #expect(json.contains("\"version\" : \"0.2.0\""))
}

@Test func planWithCommandsRendersAdoptCommand() {
    let plan = MigrationPlanner().build(brewfileResult(), options: MigrationPlanOptions(withCommands: true))
    let text = MigrationPlanRenderer().text(plan)
    #expect(text.contains("No actions will be executed."))
    #expect(text.contains("command: brew install --cask --adopt firefox"))
}

@Test func planDefaultDoesNotRenderExecutableCommand() {
    let plan = MigrationPlanner().build(brewfileResult(), options: MigrationPlanOptions())
    let text = MigrationPlanRenderer().text(plan)
    #expect(text.contains("No actions will be executed."))
    #expect(!text.contains("brew install --cask --adopt"))
    #expect(plan.proposedActions.allSatisfy { $0.command == nil })
}

@Test func planLowRiskForExactBundleIDHighConfidence() {
    let plan = MigrationPlanner().build(brewfileResult(), options: MigrationPlanOptions())
    let firefox = plan.proposedActions.first { $0.selectedCandidate?.token == "firefox" }
    #expect(firefox?.risk == .low)
    #expect(firefox?.status == .proposed)
}

@Test func planMediumRiskForHighConfidenceTokenOnly() {
    let plan = MigrationPlanner().build(
        ScanResult(summary: emptySummary(1), warnings: [], reports: [
            report("Token.app", token: "token", confidence: .high),
        ]),
        options: MigrationPlanOptions()
    )
    #expect(plan.proposedActions.first?.risk == .medium)
}

@Test func planStrictIncludesOnlyLowRiskProposed() {
    let plan = MigrationPlanner().build(
        ScanResult(summary: emptySummary(2), warnings: [], reports: [
            report("Firefox.app", bundleID: "org.mozilla.firefox", token: "firefox", confidence: .high, reason: "exact bundle identifier match"),
            report("Token.app", token: "token", confidence: .high),
        ]),
        options: MigrationPlanOptions(strict: true)
    )

    #expect(plan.proposedActions.map { $0.selectedCandidate?.token } == ["firefox"])
    #expect(plan.reviewRequiredActions.contains { $0.selectedCandidate?.token == "token" && $0.reasons.contains("excluded by strict mode") })
}

@Test func planWithCommandsActiveOnlyForProposed() {
    let plan = MigrationPlanner().build(brewfileResult(), options: MigrationPlanOptions(includeMedium: true, withCommands: true))
    #expect(plan.proposedActions.first { $0.selectedCandidate?.token == "firefox" }?.commandKind == .active)
    #expect(plan.proposedActions.first { $0.selectedCandidate?.token == "firefox" }?.command == "brew install --cask --adopt firefox")
    #expect(plan.reviewRequiredActions.first { $0.selectedCandidate?.token == "cursor-editor" }?.commandKind == .commented)
    #expect(plan.reviewRequiredActions.first { $0.selectedCandidate?.token == "cursor-editor" }?.command == "# review required: brew install --cask --adopt cursor-editor")
}

@Test func planExplainOutputIncludesReasons() {
    let plan = MigrationPlanner().build(brewfileResult(), options: MigrationPlanOptions(withCommands: true))
    let text = MigrationPlanRenderer().text(plan, explain: true)
    #expect(text.contains("source: manual app"))
    #expect(text.contains("reasons:"))
    #expect(text.contains("match: exact bundle identifier match"))
}

@Test func planJSONContainsRiskStatusCommandKindCandidates() throws {
    let plan = MigrationPlanner().build(brewfileResult(), options: MigrationPlanOptions(withCommands: true))
    let json = try MigrationPlanRenderer().json(plan)
    #expect(json.contains("\"risk\" : \"low\""))
    #expect(json.contains("\"status\" : \"proposed\""))
    #expect(json.contains("\"commandKind\" : \"active\""))
    #expect(json.contains("\"selectedCandidate\""))
    #expect(json.contains("\"alternativeCandidates\""))
}

@Test func planOutputOverwriteGuardWorks() throws {
    let url = try temporaryDirectory().appendingPathComponent("plan.json")
    try "{}".write(to: url, atomically: true, encoding: .utf8)

    do {
        try Exporter().write("{}", to: url, force: false)
        Issue.record("Expected overwrite refusal")
    } catch CLIError.outputExists(let path) {
        #expect(path == url.path)
    }
}

private struct MockBrewClient: BrewClient {
    var isAvailable: Bool = true
    var warningList: [String] = []
    var installed: [CaskMetadata] = []
    var available: [CaskMetadata] = []
    var byToken: [String: CaskMetadata] = [:]

    func warnings() -> [String] { warningList }
    func installedCasks() -> [CaskMetadata] { installed }
    func availableCasks() -> [CaskMetadata] { available }
    func metadata(for token: String) -> CaskMetadata? { byToken[token] }
}

private func brewfileResult() -> ScanResult {
    ScanResult(summary: emptySummary(10), warnings: [], reports: [
        report("Firefox.app", bundleID: "org.mozilla.firefox", token: "firefox", confidence: .high, reason: "exact bundle identifier match"),
        report("Cursor.app", token: "cursor-editor", confidence: .medium, reason: "prefix/contains normalized match"),
        report("Fireflox.app", token: "fireflop", confidence: .low, reason: "fuzzy weak match"),
        AppReport(status: .ambiguous, app: app("Cursor.app"), matches: [
            CaskMatch(token: "cursor", confidence: .medium, reason: "normalized app name match"),
            CaskMatch(token: "cursor-cli", confidence: .medium, reason: "token prefix match"),
        ], matchReason: "normalized app name match"),
        AppReport(status: .ignored, app: app("Ignored.app"), matches: [
            CaskMatch(token: "ignored-cask", confidence: .high, reason: "exact normalized cask token/name match"),
        ], matchReason: "ignored by ignore file"),
        AppReport(status: .skippedAppStore, app: app("Store.app", mas: true), matches: [
            CaskMatch(token: "store-cask", confidence: .high, reason: "exact normalized cask token/name match"),
        ], matchReason: "App Store app"),
        AppReport(status: .skippedSystem, app: app("Safari.app", system: true), matches: [
            CaskMatch(token: "safari-cask", confidence: .high, reason: "exact normalized cask token/name match"),
        ], matchReason: "system app"),
        AppReport(status: .homebrewManaged, app: app("Managed.app"), matches: [
            CaskMatch(token: "managed-cask", confidence: .high, reason: "exact normalized cask token/name match"),
        ], matchReason: "managed by Homebrew cask"),
        AppReport(status: .noCandidate, app: app("Custom.app"), matches: [
            CaskMatch(token: "custom-cask", confidence: .high, reason: "exact normalized cask token/name match"),
        ], matchReason: "no candidate"),
    ])
}

private func report(
    _ fileName: String,
    bundleID: String? = nil,
    token: String,
    confidence: MatchConfidence,
    reason: String = "exact normalized cask token/name match"
) -> AppReport {
    AppReport(
        status: .replaceable,
        app: app(fileName, bundleID: bundleID),
        matches: [CaskMatch(token: token, confidence: confidence, reason: reason)],
        matchReason: reason
    )
}

private func emptySummary(_ total: Int) -> ReportSummary {
    ReportSummary(
        totalApps: total,
        homebrewManaged: 0,
        replaceableHighConfidence: 0,
        replaceableMediumConfidence: 0,
        ambiguous: 0,
        appStoreSkipped: 0,
        systemSkipped: 0,
        ignored: 0,
        noMatch: 0
    )
}

private func occurrences(of needle: String, in haystack: String) -> Int {
    haystack.components(separatedBy: needle).count - 1
}

private func temporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func app(
    _ fileName: String,
    path: String? = nil,
    bundleID: String? = nil,
    mas: Bool = false,
    system: Bool = false
) -> ScannedApp {
    ScannedApp(
        path: path ?? "/Applications/\(fileName)",
        fileName: fileName,
        bundleName: fileName.replacingOccurrences(of: ".app", with: ""),
        displayName: nil,
        bundleIdentifier: bundleID,
        version: "1",
        hasMASReceipt: mas,
        isSystemApp: system
    )
}

private func makeApp(_ url: URL, bundleID: String = "com.example.app") throws {
    let contents = url.appendingPathComponent("Contents")
    try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
    let plist = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>CFBundleName</key>
      <string>\(url.deletingPathExtension().lastPathComponent)</string>
      <key>CFBundleIdentifier</key>
      <string>\(bundleID)</string>
    </dict>
    </plist>
    """
    try plist.data(using: .utf8)!.write(to: contents.appendingPathComponent("Info.plist"))
}
