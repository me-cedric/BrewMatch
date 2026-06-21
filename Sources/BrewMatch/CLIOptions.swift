import Foundation

struct CLIOptions {
    var command: String
    var json: Bool
    var output: URL?
    var force: Bool
    var ignoreFile: URL
    var includeMedium: Bool
    var includeLow: Bool
    var includeAmbiguous: Bool
    var withComments: Bool
    var noHeader: Bool

    static func parse(_ arguments: [String]) throws -> CLIOptions {
        var args = arguments
        let command = args.first { !$0.hasPrefix("-") } ?? "scan"
        guard ["scan", "report", "brewfile", "suggestions"].contains(command) else { throw CLIError.usage }
        args.removeAll { $0 == command }

        var json = false
        var output: URL?
        var force = false
        var ignoreFile = defaultIgnoreFile()
        var includeMedium = false
        var includeLow = false
        var includeAmbiguous = false
        var withComments = command == "suggestions"
        var noHeader = false

        while let arg = args.first {
            args.removeFirst()
            switch arg {
            case "--json":
                json = true
            case "--include-medium":
                includeMedium = true
            case "--include-low":
                includeLow = true
            case "--include-ambiguous":
                includeAmbiguous = true
            case "--with-comments":
                withComments = true
            case "--no-header":
                noHeader = true
            case "--force":
                force = true
            case "--output":
                guard let value = args.first else { throw CLIError.missingValue("--output") }
                args.removeFirst()
                output = URL(fileURLWithPath: value)
            case "--ignore-file":
                guard let value = args.first else { throw CLIError.missingValue("--ignore-file") }
                args.removeFirst()
                ignoreFile = URL(fileURLWithPath: value)
            default:
                throw CLIError.usage
            }
        }

        return CLIOptions(
            command: command,
            json: json,
            output: output,
            force: force,
            ignoreFile: ignoreFile,
            includeMedium: includeMedium,
            includeLow: includeLow,
            includeAmbiguous: includeAmbiguous,
            withComments: withComments,
            noHeader: noHeader
        )
    }

    private static func defaultIgnoreFile() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/brewmatch/ignore.json")
    }
}
