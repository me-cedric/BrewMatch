# Changelog

## Unreleased

## 0.1.0 - 2026-06-21

### Batch 1

- Created SwiftPM executable CLI.
- Added read-only app scanning for `/Applications` and `~/Applications`.
- Parsed app `Info.plist` fields.
- Added system app, App Store receipt, and Homebrew cask detection.
- Added matching confidence and candidate reasons.
- Added JSON and text reports.
- Added unit tests with mocked Homebrew client.

### Batch 2

- Initialized git repository and Swift/macOS `.gitignore`.
- Added `--output`, `--force`, and `--ignore-file`.
- Added ignore file support and ignored report status.
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

### Public project hygiene

- Added MIT license, CONTRIBUTING, SECURITY, issue templates, PR template, CI workflow, and manual release build workflow.
- Added validation and smoke release scripts.
