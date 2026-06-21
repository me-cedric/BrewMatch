import Foundation

enum Normalizer {
    static func words(_ value: String) -> [String] {
        let withoutApp = value.lowercased().replacingOccurrences(of: #"\.app$"#, with: "", options: .regularExpression)
        let spaced = withoutApp.replacingOccurrences(of: #"[^a-z0-9]+"#, with: " ", options: .regularExpression)
        return spaced.split(separator: " ").map(String.init)
    }

    static func key(_ value: String) -> String {
        words(value).joined()
    }
}
