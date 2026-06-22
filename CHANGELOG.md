# Changelog

## Unreleased

### v0.3.0 foundation

- Added guarded `brewmatch adopt` command.
- Kept dry-run as default behavior.
- Added `--execute` and exact `--confirm "adopt <token>"` safety gates.
- Added explicit `--i-understand-this-may-change-my-system` execution gate.
- Added `--dry-run`, including safe conflict handling with `--execute`.
- Added `--require-clean-plan` for blocking execution when review-required entries, warnings, or selected alternatives exist.
- Added preflight checks for Homebrew availability, cask resolution, app existence, Homebrew-managed status, and bundle identifier drift.
- Added optional `--audit-log <path>` JSON audit output with overwrite protection.
- Added JSON safety gate and preflight check fields.
- Added final interactive `ADOPT` prompt for TTY execution.
- Added executor abstraction for future `brew install --cask --adopt <token>` calls.
- Added JSON adopt responses with execution mode, command args, block reasons, and mocked execution result fields.
- Kept real adoption out of tests and default behavior.

## 0.2.0 - 2026-06-21

- Added dry-run migration plan command.
- Added JSON migration plan output with `safetyMode: "dry-run"`.
- Added optional command rendering for future adopt commands without execution.
- Added risk levels, plan statuses, strict mode, explain output, and command kind fields.
- Added machine-readable plan JSON schema documentation.
- Added active/commented command safety for plan output.
- Kept real app adoption out of scope.

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
