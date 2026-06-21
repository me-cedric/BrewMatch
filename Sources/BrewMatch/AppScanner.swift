import Foundation

struct AppScanner {
    var fileManager: FileManager = .default

    func scan(roots: [URL]) -> [ScannedApp] {
        roots.flatMap(appURLs(in:))
            .map(readApp)
            .sorted { $0.fileName.localizedCaseInsensitiveCompare($1.fileName) == .orderedAscending }
    }

    func appURLs(in root: URL) -> [URL] {
        guard let direct = try? fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var apps: [URL] = []
        for url in direct {
            if url.pathExtension == "app" {
                apps.append(url)
                continue
            }

            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { continue }
            let nested = (try? fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )) ?? []
            apps.append(contentsOf: nested.filter { $0.pathExtension == "app" })
        }
        return apps
    }

    func readApp(_ url: URL) -> ScannedApp {
        let info = readInfoPlist(url.appendingPathComponent("Contents/Info.plist"))
        let path = url.standardizedFileURL.path
        let bundleID = info["CFBundleIdentifier"] as? String
        return ScannedApp(
            path: path,
            fileName: url.lastPathComponent,
            bundleName: info["CFBundleName"] as? String,
            displayName: info["CFBundleDisplayName"] as? String,
            bundleIdentifier: bundleID,
            version: info["CFBundleShortVersionString"] as? String,
            hasMASReceipt: fileManager.fileExists(atPath: url.appendingPathComponent("Contents/_MASReceipt/receipt").path),
            isSystemApp: isSystemPath(path) || isProtectedAppleBundleID(bundleID)
        )
    }

    private func readInfoPlist(_ url: URL) -> [String: Any] {
        guard
            let data = try? Data(contentsOf: url),
            let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
            let dict = plist as? [String: Any]
        else { return [:] }
        return dict
    }

    private func isSystemPath(_ path: String) -> Bool {
        path.hasPrefix("/System/Applications/")
    }

    private func isProtectedAppleBundleID(_ bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return [
            "com.apple.Safari",
            "com.apple.MobileSMS",
            "com.apple.mail",
            "com.apple.Music",
            "com.apple.Photos",
            "com.apple.TV",
            "com.apple.Terminal",
            "com.apple.systempreferences",
            "com.apple.finder",
            "com.apple.AppStore",
        ].contains(bundleID)
    }
}
