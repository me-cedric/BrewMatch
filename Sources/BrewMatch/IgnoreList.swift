import Foundation

struct IgnoreList: Sendable {
    var values: Set<String>

    static let empty = IgnoreList(values: [])

    func contains(_ app: ScannedApp) -> Bool {
        let candidates = [
            app.bundleIdentifier,
            app.displayName,
            app.bundleName,
            app.fileName,
            app.path,
        ].compactMap { $0 }
        return candidates.contains { values.contains($0) || values.contains(Normalizer.key($0)) }
    }

    static func load(from url: URL, fileManager: FileManager = .default) throws -> IgnoreList {
        guard fileManager.fileExists(atPath: url.path) else { return .empty }
        do {
            let data = try Data(contentsOf: url)
            let json = try JSONSerialization.jsonObject(with: data)
            let entries = try parse(json)
            return IgnoreList(values: Set(entries.flatMap { [$0, Normalizer.key($0)] }))
        } catch CLIError.malformedIgnoreFile {
            throw CLIError.malformedIgnoreFile(url.path)
        } catch {
            throw CLIError.malformedIgnoreFile(url.path)
        }
    }

    private static func parse(_ json: Any) throws -> [String] {
        if let strings = json as? [String] {
            return strings
        }

        guard let dict = json as? [String: Any] else {
            throw CLIError.malformedIgnoreFile("")
        }

        let keys = ["bundleIdentifiers", "names", "paths", "ignore"]
        let values = keys.flatMap { key -> [String] in
            guard let array = dict[key] as? [String] else { return [] }
            return array
        }

        guard !values.isEmpty else { throw CLIError.malformedIgnoreFile("") }
        return values
    }
}
