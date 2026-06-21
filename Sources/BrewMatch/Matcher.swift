import Foundation

struct AppMatcher {
    var casks: [CaskMetadata]

    func matches(for app: ScannedApp) -> [CaskMatch] {
        casks.compactMap { cask in
            bestMatch(app: app, cask: cask)
        }.sorted {
            if $0.confidence == $1.confidence { return $0.token < $1.token }
            return $0.confidence > $1.confidence
        }
    }

    private func bestMatch(app: ScannedApp, cask: CaskMetadata) -> CaskMatch? {
        let appNames = [app.displayName, app.bundleName, app.fileName].compactMap { $0 }
        let appKeys = Set(appNames.map(Normalizer.key).filter { !$0.isEmpty })
        let caskNames = [cask.token] + cask.names + cask.appNames
        let caskKeys = Set(caskNames.map(Normalizer.key).filter { !$0.isEmpty })

        if let bundleID = app.bundleIdentifier, cask.bundleIdentifiers.contains(bundleID) {
            return CaskMatch(token: cask.token, confidence: .high, reason: "exact bundle identifier match")
        }

        if !Set(cask.appNames.map(Normalizer.key)).isDisjoint(with: appKeys) {
            return CaskMatch(token: cask.token, confidence: .high, reason: "exact app display name match from cask artifact")
        }

        if !caskKeys.isDisjoint(with: appKeys) {
            return CaskMatch(token: cask.token, confidence: .high, reason: "exact normalized cask token/name match")
        }

        if appKeys.contains(where: { appKey in
            caskKeys.contains { caskKey in
                appKey.hasPrefix(caskKey) || caskKey.hasPrefix(appKey) || appKey.contains(caskKey) || caskKey.contains(appKey)
            }
        }) {
            return CaskMatch(token: cask.token, confidence: .medium, reason: "prefix/contains normalized match")
        }

        if appKeys.contains(where: { appKey in
            caskKeys.contains { caskKey in
                Self.distance(appKey, caskKey) <= max(2, min(appKey.count, caskKey.count) / 5)
            }
        }) {
            return CaskMatch(token: cask.token, confidence: .low, reason: "fuzzy weak match")
        }

        return nil
    }

    static func distance(_ a: String, _ b: String) -> Int {
        let a = Array(a)
        let b = Array(b)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }

        var previous = Array(0...b.count)
        for (i, ca) in a.enumerated() {
            var current = [i + 1] + Array(repeating: 0, count: b.count)
            for (j, cb) in b.enumerated() {
                current[j + 1] = min(
                    previous[j + 1] + 1,
                    current[j] + 1,
                    previous[j] + (ca == cb ? 0 : 1)
                )
            }
            previous = current
        }
        return previous[b.count]
    }
}
