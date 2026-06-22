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

It is designed for local-first inventory and migration planning. It is dry-run by default; the only opt-in mutation path is the guarded Homebrew adopt command.

## Status

BrewMatch is early pre-1.0 software. Current version: `0.2.0`.

The scanner, report output, ignore file, and Brewfile suggestion export are functional and covered by unit tests. Matching remains heuristic and should be reviewed before running `brew bundle`.

| Area | Current state |
| --- | --- |
| App scanning | Reads `/Applications` and `~/Applications`, one level deep. |
| Metadata | Parses app `Info.plist`, MAS receipts, and local Homebrew Cask metadata. |
| Matching | Uses bundle identifiers, cask artifact names, normalized names, prefix matches, and fuzzy fallback. |
| Reports | Text and JSON scan reports with summary counts and warnings. |
| Brewfile export | Suggestion-only output for high-confidence matches by default. |
| App changes | Dry-run by default. Guarded adoption command exists for one explicit Homebrew adopt command only. |

## Safety

- Dry-run by default.
- No direct app delete, move, or modify actions.
- The only mutation path is an explicit `brew install --cask --adopt <token>` call after all adopt safety gates pass.
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

Install the release binary locally:

```sh
cp .build/release/brewmatch /usr/local/bin/brewmatch
```

Safer local test before installing:

```sh
.build/release/brewmatch scan
```

Run from SwiftPM:

```sh
swift run brewmatch scan
```

Use built binary:

```sh
.build/release/brewmatch scan
```

No Homebrew cask or tap exists yet.

## Commands

| Command | Purpose |
| --- | --- |
| `brewmatch scan` | Scan apps and print a text report. |
| `brewmatch scan --json` | Scan apps and print JSON. |
| `brewmatch scan --output report.json` | Export JSON report based on `.json` extension. |
| `brewmatch report --output report.txt --force` | Export text report and overwrite existing file. |
| `brewmatch brewfile` | Print suggested Brewfile content. |
| `brewmatch brewfile --with-comments --output Brewfile` | Export commented Brewfile suggestions. |
| `brewmatch suggestions` | Alias for `brewmatch brewfile --with-comments`. |
| `brewmatch plan` | Print a dry-run migration plan. No actions are executed. v0.2 still does not adopt apps. |
| `brewmatch plan --strict` | Include only low-risk proposed entries; move other candidates to review. |
| `brewmatch plan --explain` | Include detailed reasoning, source classification, and risk notes. |
| `brewmatch plan --with-commands` | Include proposed commands as dry-run text only. |
| `brewmatch adopt` | Dry-run adopt planning. No actions are executed by default. |
| `brewmatch adopt --cask firefox` | Show the selected dry-run adoption candidate. |
| `brewmatch adopt --dry-run --cask firefox` | Explicit dry-run; same as default. |
| `brewmatch adopt --cask firefox --execute --confirm "adopt firefox" --i-understand-this-may-change-my-system` | Execute only if every safety gate and preflight check passes. |

`suggestions` is an alias for `brewfile --with-comments`.

Report export:

```sh
brewmatch scan --output report.json
brewmatch report --output report.txt --force
```

JSON output includes raw app fields, match reasons, warnings, and summary counts:

```sh
brewmatch scan --json
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

## Migration Plan

`brewmatch plan` prepares a dry-run migration plan for apps that may be movable under Homebrew management later.

It does not run `brew install --cask --adopt`, install casks, delete apps, move apps, or modify apps.

```sh
brewmatch plan
brewmatch plan --json
brewmatch plan --strict
brewmatch plan --strict --with-commands
brewmatch plan --explain
brewmatch plan --with-commands
brewmatch plan --output plan.json --json --force
brewmatch plan --json --output plan.json --force
```

Every plan includes:

```text
No actions will be executed.
```

Risk levels:

- `low`: high confidence from an exact bundle identifier match.
- `medium`: high confidence from app name, artifact name, or token matching.
- `review-required`: medium or low confidence, ambiguous candidates, App Store apps, and system apps.

Plan statuses:

- `proposed`: low/medium risk high-confidence candidates, unless `--strict` excludes medium risk.
- `reviewRequired`: candidates that should be manually checked.
- `skipped`: system, App Store, ignored, already managed, no-match, or threshold-excluded apps.

`--strict` keeps only low-risk entries as proposed and marks medium-risk candidates as review-required with `excluded by strict mode`.

Exact adopt commands are shown only when `--with-commands` is passed. Proposed entries render active command text. Review-required entries render commented command text:

```sh
# review required: brew install --cask --adopt cursor
```

These commands are never executed by BrewMatch. See [docs/plan-json-schema.md](docs/plan-json-schema.md) for machine-readable plan fields.

## Adopt

`brewmatch adopt` is a guarded foundation for future Homebrew Cask adoption. Default behavior is dry-run.

```sh
brewmatch adopt
brewmatch adopt --dry-run
brewmatch adopt --cask firefox
brewmatch adopt --app Firefox.app
brewmatch adopt --json --output adopt.json --force
brewmatch adopt --cask firefox --audit-log adopt-audit.json
brewmatch adopt --cask firefox --require-clean-plan --explain
brewmatch adopt --cask firefox --execute --confirm "adopt firefox" --i-understand-this-may-change-my-system
```

Dry-run output may show the exact command that would be used:

```sh
brew install --cask --adopt firefox
```

BrewMatch does not run that command unless all safety gates pass:

- `--execute` is present.
- `--dry-run` is not present.
- Exactly one cask token or app selector is provided.
- Selected entry is `proposed`.
- Selected entry is `low` risk.
- Selected match confidence is `high`.
- Selected app is not ignored, not App Store, not system, and not ambiguous.
- Confirmation phrase exactly matches `--confirm "adopt <token>"`.
- User also passes `--i-understand-this-may-change-my-system`.
- If stdin is interactive, user types exact final prompt response `ADOPT`.
- Command arguments are exactly `["install", "--cask", "--adopt", "<token>"]`.

Before execution, BrewMatch also runs preflight checks:

- Homebrew is available.
- The selected cask token resolves through Homebrew metadata or cask search.
- The app still exists at the scanned path.
- The app is not already Homebrew-managed.
- The bundle identifier still matches the scanned app, when available.

`--require-clean-plan` adds stricter execution gates. It blocks execution when the current scan has review-required entries, warnings, or the selected app has alternative candidates. In dry-run mode, `--explain` shows this gate without executing.

`--audit-log <path>` writes a JSON audit object for dry-run, blocked, and executed runs. It refuses to overwrite existing files unless `--force` is passed.

Blocked or dry-run output always includes:

```text
No actions were executed.
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
│   ├── MigrationPlan.swift       # dry-run migration planning and plan JSON
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
swift package describe
swift test
swift build
```

Unit tests do not require Homebrew to be installed.

Shortcut targets:

```sh
./scripts/validate.sh
./scripts/smoke-release.sh
make validate
make smoke
make build
make test
make clean
```

## Release Builds

The manual `Release Build` GitHub Actions workflow builds a release binary and uploads it as an artifact. It does not publish a Homebrew tap and does not require secrets.

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

## Contributing

Contributions are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a PR.

Keep changes aligned with the read-only safety model:

- no app modification,
- no telemetry,
- no secrets,
- no Homebrew dependency in tests.

## Security

BrewMatch reports may include app names, bundle identifiers, versions, and local paths. Treat JSON reports as potentially sensitive and sanitize them before sharing.

See [SECURITY.md](SECURITY.md) for reporting guidance.

## Keywords

macOS, Swift, SwiftPM, command line, CLI, Homebrew, Homebrew Cask, Brewfile, brew bundle, application inventory, app migration, local-first, privacy, read-only.

## License

MIT. See [LICENSE](LICENSE).
