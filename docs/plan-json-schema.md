# Plan JSON Schema

`brewmatch plan --json` emits a dry-run migration plan. It never executes commands.

## Top-level Fields

```json
{
  "schemaVersion": "1",
  "version": "0.1.0",
  "generatedAt": "2026-06-21T20:00:00Z",
  "safetyMode": "dry-run",
  "proposedActions": [],
  "reviewRequiredActions": [],
  "skippedActions": [],
  "warnings": []
}
```

| Field | Type | Meaning |
| --- | --- | --- |
| `schemaVersion` | string | Plan JSON schema version. Current value: `1`. |
| `version` | string | BrewMatch CLI version. |
| `generatedAt` | string | ISO-8601 generation timestamp. |
| `safetyMode` | string | Always `dry-run`. |
| `proposedActions` | array | Low/medium risk high-confidence candidates. |
| `reviewRequiredActions` | array | Candidates that need manual review before any future adoption. |
| `skippedActions` | array | Apps excluded from migration planning. |
| `warnings` | array | Scan warnings, such as missing Homebrew. |

## Entry Fields

Each action entry uses the same shape:

```json
{
  "appName": "Firefox.app",
  "bundleIdentifier": "org.mozilla.firefox",
  "path": "/Applications/Firefox.app",
  "sourceClassification": "manual app",
  "status": "proposed",
  "risk": "low",
  "selectedCandidate": {
    "token": "firefox",
    "confidence": "high",
    "reason": "exact bundle identifier match"
  },
  "alternativeCandidates": [],
  "commandKind": "active",
  "command": "brew install --cask --adopt firefox",
  "reasons": [
    "eligible dry-run candidate",
    "status: proposed",
    "risk: low",
    "source: manual app",
    "confidence: high",
    "match: exact bundle identifier match"
  ]
}
```

| Field | Type | Meaning |
| --- | --- | --- |
| `appName` | string | `.app` bundle filename. |
| `bundleIdentifier` | string or null | Bundle identifier from `Info.plist`. |
| `path` | string | App bundle path. Treat as sensitive when sharing. |
| `sourceClassification` | string | `manual app`, `Homebrew managed`, `App Store app`, `system app`, or `ignored`. |
| `status` | string | `proposed`, `reviewRequired`, or `skipped`. |
| `risk` | string | `low`, `medium`, `high`, or `review-required`. |
| `selectedCandidate` | object or null | Chosen cask candidate. |
| `alternativeCandidates` | array | Other candidate matches, mainly for ambiguous apps. |
| `commandKind` | string | `active`, `commented`, or `none`. |
| `command` | string or null | Dry-run command text when `--with-commands` is used. |
| `reasons` | array | Audit trail for status, risk, confidence, and source decisions. |

## Risk Rules

- `low`: high confidence plus exact bundle identifier match.
- `medium`: high confidence from exact app name, artifact name, or cask token/name.
- `review-required`: medium/low confidence, ambiguous candidates, App Store apps, and system apps.

## Command Rules

- `active`: only for proposed entries when `--with-commands` is used.
- `commented`: review-required entries when `--with-commands` is used.
- `none`: no command rendered.

Commented command example:

```json
{
  "commandKind": "commented",
  "command": "# review required: brew install --cask --adopt cursor"
}
```

Even active commands are text only. BrewMatch does not execute adoption commands.
