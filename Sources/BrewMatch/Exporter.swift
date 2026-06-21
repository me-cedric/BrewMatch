import Foundation

enum OutputFormat {
    case json
    case text
}

struct Exporter {
    func format(for url: URL) throws -> OutputFormat {
        switch url.pathExtension.lowercased() {
        case "json": return .json
        case "txt": return .text
        default: throw CLIError.unsupportedOutputExtension(url.pathExtension)
        }
    }

    func render(_ result: ScanResult, format: OutputFormat) throws -> String {
        switch format {
        case .json: return try Reporter().json(result)
        case .text: return Reporter().text(result)
        }
    }

    func write(_ contents: String, to url: URL, force: Bool, fileManager: FileManager = .default) throws {
        if fileManager.fileExists(atPath: url.path), !force {
            throw CLIError.outputExists(url.path)
        }
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try contents.write(to: url, atomically: true, encoding: .utf8)
    }
}
