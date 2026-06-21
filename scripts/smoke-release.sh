#!/usr/bin/env bash
set -euo pipefail

swift build -c release

.build/release/brewmatch --version
.build/release/brewmatch scan --json --output /tmp/brewmatch-smoke.json --force
.build/release/brewmatch report --output /tmp/brewmatch-smoke.txt --force
.build/release/brewmatch brewfile --output /tmp/Brewfile.brewmatch --force

printf 'Generated files:\n'
printf '%s\n' '- /tmp/brewmatch-smoke.json'
printf '%s\n' '- /tmp/brewmatch-smoke.txt'
printf '%s\n' '- /tmp/Brewfile.brewmatch'
