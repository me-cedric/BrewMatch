<div align="center">
<br />
<h1>BrewMatch</h1>
<p><strong>Read-only macOS app scanner for Homebrew Cask migration.</strong></p>
<p>
<a href="https://github.com/me-cedric/BrewMatch/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/me-cedric/BrewMatch/ci.yml?branch=main&label=CI&logo=github&style=flat" alt="CI Status" /></a>
<a href="LICENSE"><img src="https://img.shields.io/github/license/me-cedric/BrewMatch?label=License&style=flat" alt="MIT License" /></a>
<a href="https://swift.org"><img src="https://img.shields.io/badge/Swift-6.3-orange?logo=swift&style=flat" alt="Swift 6.3" /></a>
<a href="https://developer.apple.com/macos/"><img src="https://img.shields.io/badge/macOS-14%2B-blue?logo=apple&style=flat" alt="macOS 14+" /></a>
<a href="https://brew.sh"><img src="https://img.shields.io/badge/Homebrew-Cask-fbb040?logo=homebrew&logoColor=black&style=flat" alt="Homebrew Cask" /></a>
</p>
<br />
</div>

BrewMatch is a SwiftPM macOS CLI that scans installed `.app` bundles and reports which manually installed apps may have a Homebrew Cask replacement. It can also export a suggested Brewfile for review.

It is designed for local-first inventory and migration planning. It does not modify applications.

## Status

BrewMatch is early pre-1.0 software. The scanner, report output, ignore file, and Brewfile suggestion export are functional and covered by unit tests. Matching remains heuristic and should be reviewed before running `brew bundle`.

| Area | Current state |
| --- | --- |
| App scanning | Reads `/Applications` and `~/Applications`, one level deep. |
| Metadata | Parses app `Info.plist`, MAS receipts, and local Homebrew Cask metadata. |
| Matching | Uses bundle identifiers, cask artifact names, normalized names, prefix matches, and fuzzy fallback. |
| Reports | Text and JSON scan reports with summary counts and warnings. |
| Brewfile export | Suggestion-only output for high-confidence matches by default. |
| App changes | Not implemented by design. Read-only only. |

## Safety

- No app install, delete, move, adopt, or modify actions.
- No credentials.
- No telemetry.
- No network calls except local `brew` commands.
- Missing Homebrew is OK: BrewMatch still scans apps and reports matching as unavailable.

## Features

- Scans installed macOS `.app` bundles.
- Detects likely system apps and App Store apps.
- Detects Homebrew-managed casks when Homebrew is available.
- Finds possible Homebrew Cask replacements for manually installed apps.
- Produces plain text and JSON reports.
- Supports ignore files by bundle identifier, app name, or absolute path.
- Exports suggested Brewfile content for review.
- Keeps ambiguous suggestions commented, never active.

## Install

Build from source:

```sh
git clone https://github.com/me-cedric/BrewMatch.git
cd BrewMatch
swift build -c release
```

Run from SwiftPM:

```sh
swift run brewmatch scan
```

Use built binary:

```sh
.build/release/brewmatch scan
```

## Commands

```sh
brewmatch scan
brewmatch scan --json
brewmatch scan --output report.json
brewmatch report --output report.txt --force
brewmatch brewfile
brewmatch brewfile --with-comments --output Brewfile
brewmatch suggestions
```

`suggestions` is an alias for `brewfile --with-comments`.

Report export:

```sh
brewmatch scan --output report.json
brewmatch report --output report.txt --force
```

## Brewfile Export

By default, Brewfile export includes only high-confidence, non-ambiguous cask matches:

```ruby
# BrewMatch suggested Brewfile
# Generated from local macOS application scan
# Review before running brew bundle
# Active casks are high-confidence non-ambiguous suggestions by default

cask "firefox"
```

Options:

- `--include-medium`
- `--include-low`
- `--include-ambiguous`
- `--with-comments`
- `--no-header`
- `--output <path>`
- `--force`
- `--ignore-file <path>`

Ambiguous matches are commented when included:

```ruby
# Ambiguous: Cursor.app
# candidate: cursor confidence: medium reason: normalized app name match
# candidate: cursor-cli confidence: medium reason: token prefix match
# cask "cursor"
```

## Ignore File

Default path:

```sh
~/.config/brewmatch/ignore.json
```

Supported formats:

```json
[
  "com.example.CustomApp",
  "Custom App.app",
  "/Applications/Custom App.app"
]
```

Or grouped:

```json
{
  "bundleIdentifiers": ["com.example.CustomApp"],
  "names": ["Custom App.app"],
  "paths": ["/Applications/Custom App.app"]
}
```

Ignored apps stay visible in reports under `Ignored`.

## Architecture

```text
BrewMatch/
├── Sources/BrewMatch/
│   ├── AppScanner.swift          # read-only .app discovery and Info.plist parsing
│   ├── BrewClient.swift          # local brew command wrapper and cask metadata parsing
│   ├── Matcher.swift             # cask confidence scoring
│   ├── Reporter.swift            # scan report assembly and text/JSON rendering
│   ├── BrewfileRenderer.swift    # suggestion-only Brewfile output
│   └── main.swift                # CLI entry point
└── Tests/BrewMatchTests/
```

Core boundaries:

- `AppScanner` only reads filesystem metadata.
- `BrewClient` only calls local `brew` commands and returns parsed data.
- `Matcher` is pure matching logic.
- `Reporter` and `BrewfileRenderer` turn scan results into output.
- Tests use mocked Homebrew clients and temporary directories.

## Testing

```sh
swift test
swift build
```

Unit tests do not require Homebrew to be installed.

## Current Limitations

- Matching is heuristic.
- Homebrew metadata depends on local `brew info --json=v2 --cask`.
- Scanner only searches `/Applications` and `~/Applications`, one level deep.
- Brewfile output is suggestion-only. Review before running `brew bundle`.

## Roadmap

- More cask metadata fields.
- Better duplicate app grouping.
- Optional config file.
- GUI later, after CLI behavior stabilizes.

## Keywords

macOS, Swift, SwiftPM, command line, CLI, Homebrew, Homebrew Cask, Brewfile, brew bundle, application inventory, app migration, local-first, privacy, read-only.

## License

MIT. See [LICENSE](LICENSE).
