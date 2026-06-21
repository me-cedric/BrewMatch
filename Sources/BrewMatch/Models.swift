import Foundation

struct ScannedApp: Codable, Equatable, Sendable {
    var path: String
    var fileName: String
    var bundleName: String?
    var displayName: String?
    var bundleIdentifier: String?
    var version: String?
    var hasMASReceipt: Bool
    var isSystemApp: Bool
}

enum MatchConfidence: String, Codable, Comparable, Sendable {
    case low
    case medium
    case high

    private var rank: Int {
        switch self {
        case .low: 1
        case .medium: 2
        case .high: 3
        }
    }

    static func < (lhs: MatchConfidence, rhs: MatchConfidence) -> Bool {
        lhs.rank < rhs.rank
    }
}

struct CaskMatch: Codable, Equatable, Sendable {
    var token: String
    var confidence: MatchConfidence
    var reason: String
}

struct CaskMetadata: Codable, Equatable, Sendable {
    var token: String
    var names: [String]
    var appNames: [String]
    var bundleIdentifiers: [String]
    var appPaths: [String]

    init(token: String, names: [String] = [], appNames: [String] = [], bundleIdentifiers: [String] = [], appPaths: [String] = []) {
        self.token = token
        self.names = names
        self.appNames = appNames
        self.bundleIdentifiers = bundleIdentifiers
        self.appPaths = appPaths
    }
}

enum ReportStatus: String, Codable, Sendable {
    case homebrewManaged
    case replaceable
    case ambiguous
    case noCandidate
    case skippedSystem
    case skippedAppStore
    case ignored
}

struct AppReport: Codable, Sendable {
    var status: ReportStatus
    var app: ScannedApp
    var matches: [CaskMatch]
    var matchReason: String?
}

struct ReportSummary: Codable, Equatable, Sendable {
    var totalApps: Int
    var homebrewManaged: Int
    var replaceableHighConfidence: Int
    var replaceableMediumConfidence: Int
    var ambiguous: Int
    var appStoreSkipped: Int
    var systemSkipped: Int
    var ignored: Int
    var noMatch: Int
}

struct ScanResult: Codable, Sendable {
    var summary: ReportSummary
    var warnings: [String]
    var reports: [AppReport]
}
