# Changelog

## Unreleased

### Batch 1

- Created SwiftPM executable CLI.
- Added read-only scan for `/Applications` and `~/Applications`.
- Parsed app `Info.plist` fields.
- Added system app, App Store receipt, Homebrew cask, and candidate matching report.
- Added JSON output.
- Added unit tests with mocked Homebrew client.

### Batch 2

- Initialized git repository and Swift/macOS `.gitignore`.
- Added `--output`, `--force`, and `--ignore-file`.
- Added ignore report status.
- Added Homebrew cask metadata enrichment.
- Improved confidence scoring and ambiguity detection.
- Added summary counts and missing Homebrew warnings.
- Added tests for export, ignore, warning, ambiguity, and summary behavior.

### Batch 3

- Added `brewmatch brewfile`.
- Added `brewmatch suggestions` alias.
- Added Brewfile export filters, comments, header controls, ambiguous comments, sorting, and duplicate protection.
- Added README.
- Added Brewfile tests.
