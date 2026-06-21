import Foundation

protocol BrewClient {
    var isAvailable: Bool { get }
    func warnings() -> [String]
    func installedCasks() -> [CaskMetadata]
    func availableCasks() -> [CaskMetadata]
    func metadata(for token: String) -> CaskMetadata?
}

final class LocalBrewClient: BrewClient {
    private let brewURL: URL?
    private var cachedInstalled: [CaskMetadata]?
    private var cachedAvailable: [CaskMetadata]?
    private var cachedMetadata: [String: CaskMetadata] = [:]

    init() {
        brewURL = Self.findBrewURL()
    }

    var isAvailable: Bool { brewURL != nil }

    func warnings() -> [String] {
        isAvailable ? [] : ["Homebrew not found. Homebrew matching unavailable."]
    }

    func installedCasks() -> [CaskMetadata] {
        if let cachedInstalled { return cachedInstalled }
        guard isAvailable else { return [] }
        let result = runLines(["list", "--cask"]).map { token in
            var meta = metadata(for: token) ?? CaskMetadata(token: token)
            meta.appPaths = Array(Set(meta.appPaths + runLines(["list", "--cask", token]).filter { $0.hasSuffix(".app") }))
            return meta
        }
        cachedInstalled = result
        return result
    }

    func availableCasks() -> [CaskMetadata] {
        if let cachedAvailable { return cachedAvailable }
        guard isAvailable else { return [] }
        let result = runLines(["search", "--cask"]).map { CaskMetadata(token: $0) }
        cachedAvailable = result
        return result
    }

    func metadata(for token: String) -> CaskMetadata? {
        if let cached = cachedMetadata[token] { return cached }
        guard isAvailable, let data = runData(["info", "--json=v2", "--cask", token]) else { return nil }
        guard let parsed = Self.parseMetadata(data).first else { return nil }
        cachedMetadata[token] = parsed
        return parsed
    }

    static func parseMetadata(_ data: Data) -> [CaskMetadata] {
        guard
            let json = try? JSONSerialization.jsonObject(with: data),
            let root = json as? [String: Any],
            let casks = root["casks"] as? [[String: Any]]
        else { return [] }

        return casks.compactMap { dict in
            guard let token = dict["token"] as? String else { return nil }
            return CaskMetadata(
                token: token,
                names: strings(from: dict["name"]),
                appNames: appNames(in: dict),
                bundleIdentifiers: bundleIDs(in: dict),
                appPaths: []
            )
        }
    }

    private static func findBrewURL() -> URL? {
        let candidates = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
            + (ProcessInfo.processInfo.environment["PATH"] ?? "")
                .split(separator: ":")
                .map { "\($0)/brew" }
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
            .map { URL(fileURLWithPath: $0) }
    }

    private static func appNames(in value: Any) -> [String] {
        var names: [String] = []
        walk(value) { key, item in
            guard key == "app" else { return }
            names += strings(from: item).map { $0.hasSuffix(".app") ? $0 : "\($0).app" }
        }
        return Array(Set(names)).sorted()
    }

    private static func bundleIDs(in value: Any) -> [String] {
        var ids: [String] = []
        walk(value) { key, item in
            let lower = key.lowercased()
            guard lower.contains("bundle") && lower.contains("id") else { return }
            ids += strings(from: item)
        }
        return Array(Set(ids)).sorted()
    }

    private static func strings(from value: Any?) -> [String] {
        switch value {
        case let string as String:
            return [string]
        case let array as [Any]:
            return array.flatMap { strings(from: $0) }
        default:
            return []
        }
    }

    private static func walk(_ value: Any, visit: (String, Any) -> Void) {
        if let dict = value as? [String: Any] {
            for (key, item) in dict {
                visit(key, item)
                walk(item, visit: visit)
            }
        } else if let array = value as? [Any] {
            array.forEach { walk($0, visit: visit) }
        }
    }

    private func runLines(_ arguments: [String]) -> [String] {
        guard let data = runData(arguments) else { return [] }
        return String(decoding: data, as: UTF8.self)
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func runData(_ arguments: [String]) -> Data? {
        guard let brewURL else { return nil }
        let process = Process()
        process.executableURL = brewURL
        process.arguments = arguments
        process.environment = ProcessInfo.processInfo.environment.merging(["HOMEBREW_NO_AUTO_UPDATE": "1"]) { _, new in new }

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard process.terminationStatus == 0 else { return nil }
        return pipe.fileHandleForReading.readDataToEndOfFile()
    }
}
