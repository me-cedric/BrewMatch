import Foundation

enum BrewMatchCLI {
    static func main() throws {
        let options = try CLIOptions.parse(Array(CommandLine.arguments.dropFirst()))
        let roots = [
            URL(fileURLWithPath: "/Applications"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications"),
        ]

        let ignoreList = try IgnoreList.load(from: options.ignoreFile)
        let result = Reporter().build(apps: AppScanner().scan(roots: roots), brew: LocalBrewClient(), ignoreList: ignoreList)
        let exporter = Exporter()

        if options.command == "brewfile" || options.command == "suggestions" {
            let content = BrewfileRenderer().render(result, options: BrewfileOptions(
                includeMedium: options.includeMedium,
                includeLow: options.includeLow,
                includeAmbiguous: options.includeAmbiguous,
                withComments: options.withComments,
                noHeader: options.noHeader
            ))
            if let output = options.output {
                try exporter.write(content, to: output, force: options.force)
            } else {
                print(content, terminator: "")
            }
            return
        }

        if let output = options.output {
            let format = try exporter.format(for: output)
            try exporter.write(try exporter.render(result, format: format), to: output, force: options.force)
            return
        }

        if options.json {
            print(try Reporter().json(result))
        } else {
            print(Reporter().text(result))
        }
    }
}

enum CLIError: Error, CustomStringConvertible, Equatable {
    case usage
    case missingValue(String)
    case unsupportedOutputExtension(String)
    case outputExists(String)
    case malformedIgnoreFile(String)

    var description: String {
        switch self {
        case .usage:
            return "Usage: brewmatch scan [--json] [--output <path>] [--force] [--ignore-file <path>]\n       brewmatch report [--output <path>] [--force] [--ignore-file <path>]\n       brewmatch brewfile [--include-medium] [--include-low] [--include-ambiguous] [--with-comments] [--no-header] [--output <path>] [--force] [--ignore-file <path>]\n       brewmatch suggestions [brewfile options]"
        case .missingValue(let flag):
            return "Missing value for \(flag)."
        case .unsupportedOutputExtension(let ext):
            let suffix = ext.isEmpty ? "(none)" : ".\(ext)"
            return "Unsupported output extension '\(suffix)'. Use .json or .txt."
        case .outputExists(let path):
            return "Output file already exists: \(path). Use --force to overwrite."
        case .malformedIgnoreFile(let path):
            return "Malformed ignore file: \(path)."
        }
    }
}

do {
    try BrewMatchCLI.main()
} catch {
    fputs("\(error)\n", stderr)
    exit(64)
}
