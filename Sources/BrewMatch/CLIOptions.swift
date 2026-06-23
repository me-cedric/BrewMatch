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
    var withCommands: Bool
    var noHeader: Bool
    var strict: Bool
    var explain: Bool
    var cask: String?
    var app: String?
    var execute: Bool
    var dryRun: Bool
    var confirm: String?
    var systemChangeAcknowledged: Bool
    var requireCleanPlan: Bool
    var auditLog: URL?
    var includeSystem: Bool

    static func parse(_ arguments: [String]) throws -> CLIOptions {
        var args = arguments
        if args == ["--version"] {
            return CLIOptions.version()
        }

        let command = args.first { !$0.hasPrefix("-") } ?? "scan"
        guard ["scan", "report", "brewfile", "suggestions", "plan", "adopt", "doctor", "version"].contains(command) else { throw CLIError.usage }
        args.removeAll { $0 == command }

        var json = false
        var output: URL?
        var force = false
        var ignoreFile = defaultIgnoreFile()
        var includeMedium = false
        var includeLow = false
        var includeAmbiguous = false
        var withComments = command == "suggestions"
        var withCommands = false
        var noHeader = false
        var strict = false
        var explain = false
        var cask: String?
        var app: String?
        var execute = false
        var dryRun = false
        var confirm: String?
        var systemChangeAcknowledged = false
        var requireCleanPlan = false
        var auditLog: URL?
        var includeSystem = false

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
            case "--with-commands":
                withCommands = true
            case "--no-header":
                noHeader = true
            case "--strict":
                strict = true
            case "--explain":
                explain = true
            case "--execute":
                execute = true
            case "--dry-run":
                dryRun = true
            case "--i-understand-this-may-change-my-system":
                systemChangeAcknowledged = true
            case "--require-clean-plan":
                requireCleanPlan = true
            case "--include-system":
                includeSystem = true
            case "--cask":
                guard let value = args.first else { throw CLIError.missingValue("--cask") }
                args.removeFirst()
                cask = value
            case "--app":
                guard let value = args.first else { throw CLIError.missingValue("--app") }
                args.removeFirst()
                app = value
            case "--confirm":
                guard let value = args.first else { throw CLIError.missingValue("--confirm") }
                args.removeFirst()
                confirm = value
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
            case "--audit-log":
                guard let value = args.first else { throw CLIError.missingValue("--audit-log") }
                args.removeFirst()
                auditLog = URL(fileURLWithPath: value)
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
            withCommands: withCommands,
            noHeader: noHeader,
            strict: strict,
            explain: explain,
            cask: cask,
            app: app,
            execute: execute,
            dryRun: dryRun,
            confirm: confirm,
            systemChangeAcknowledged: systemChangeAcknowledged,
            requireCleanPlan: requireCleanPlan,
            auditLog: auditLog,
            includeSystem: includeSystem
        )
    }

    private static func version() -> CLIOptions {
        CLIOptions(
            command: "version",
            json: false,
            output: nil,
            force: false,
            ignoreFile: defaultIgnoreFile(),
            includeMedium: false,
            includeLow: false,
            includeAmbiguous: false,
            withComments: false,
            withCommands: false,
            noHeader: false,
            strict: false,
            explain: false,
            cask: nil,
            app: nil,
            execute: false,
            dryRun: false,
            confirm: nil,
            systemChangeAcknowledged: false,
            requireCleanPlan: false,
            auditLog: nil,
            includeSystem: false
        )
    }

    private static func defaultIgnoreFile() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/brewmatch/ignore.json")
    }
}
