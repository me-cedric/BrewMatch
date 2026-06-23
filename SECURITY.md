# Security Policy

BrewMatch is local-first and dry-run by default.

## Security Model

- No telemetry.
- No credentials.
- No background service.
- No direct app delete, move, or file modification actions.
- No network access except local Homebrew commands such as `brew list`, `brew search`, and `brew info`.
- JSON and text reports are generated locally.

`brewmatch doctor` performs local readiness checks only. It does not modify applications. If the temporary output check runs, it writes and removes one temporary file in the system temp directory.

`brewmatch adopt` is dry-run by default. The only guarded mutation path is `brew install --cask --adopt <token>`, and it requires `--execute`, an exact selector, a low-risk proposed candidate, high confidence, Homebrew availability, the exact confirmation phrase `--confirm "adopt <token>"`, and `--i-understand-this-may-change-my-system`.

Adopt execution also performs preflight checks before calling Homebrew. BrewMatch does not delete, move, or directly modify applications.

## Sensitive Data

BrewMatch reports can contain app names, bundle identifiers, versions, and local filesystem paths. These may reveal private workflow or account details.

Audit logs may contain app names, app paths, bundle identifiers, cask tokens, command arguments, stdout, stderr, and exit codes. Review and sanitize audit logs before sharing them.

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
