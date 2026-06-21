# Security Policy

BrewMatch is local-first and read-only.

## Security Model

- No telemetry.
- No credentials.
- No background service.
- No destructive app actions.
- No network access except local Homebrew commands such as `brew list`, `brew search`, and `brew info`.
- JSON and text reports are generated locally.

`brewmatch adopt` is dry-run by default. The only guarded future mutation path is `brew install --cask --adopt <token>`, and it requires `--execute`, an exact selector, a low-risk proposed candidate, high confidence, Homebrew availability, and the exact confirmation phrase `--confirm "adopt <token>"`.

## Sensitive Data

BrewMatch reports can contain app names, bundle identifiers, versions, and local filesystem paths. These may reveal private workflow or account details.

Before sharing output:

- remove user names from paths,
- remove private application names,
- remove internal bundle identifiers,
- sanitize JSON snippets.

Do not include secrets, tokens, passwords, private keys, or proprietary app paths in issues.

## Reporting Issues

Use GitHub private vulnerability reporting if it is enabled for this repository.

If private reporting is not available, open a GitHub issue with only sanitized details and state that the issue is security-sensitive.

## Scope

Security reports are most useful for:

- unintended app modification,
- secret exposure,
- unsafe command execution,
- unsafe report output,
- behavior that breaks the read-only guarantee.
