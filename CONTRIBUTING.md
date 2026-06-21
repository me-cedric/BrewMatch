# Contributing

Thanks for helping improve BrewMatch.

## Local Setup

Requirements:

- macOS 14 or newer
- Swift 6.3 or compatible Xcode toolchain
- Homebrew optional

```sh
git clone https://github.com/me-cedric/BrewMatch.git
cd BrewMatch
swift package describe
swift build
swift test
```

## Branch Naming

Use short conventional prefixes:

- `feat/<short-name>`
- `fix/<short-name>`
- `docs/<short-name>`
- `test/<short-name>`
- `chore/<short-name>`

## Test Requirements

Run before opening a PR:

```sh
./scripts/validate.sh
```

Unit tests must not require Homebrew. Use mocked `BrewClient` data for matching and metadata behavior.

## Safety Constraints

BrewMatch is a read-only scanner by default.

- Do not install, adopt, delete, move, rename, quarantine, unquarantine, or modify apps.
- Do not add destructive behavior without explicit project approval and confirmation UX.
- Do not add telemetry.
- Do not collect credentials.
- Do not include secrets in tests, fixtures, logs, reports, or examples.
- Treat app names, bundle identifiers, and paths as potentially sensitive.

## Code Style

- Keep SwiftPM only.
- Keep dependencies at zero unless there is a strong reason.
- Prefer small, testable types over framework-heavy abstractions.
- Keep CLI output deterministic where possible.
- Add focused tests for matching, scanning, rendering, and error behavior.
- Update README and CHANGELOG for user-visible changes.
