#!/usr/bin/env bash
set -euo pipefail

swift package describe --disable-sandbox
swift build --disable-sandbox
swift test --disable-sandbox
