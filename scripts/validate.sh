#!/usr/bin/env bash
set -euo pipefail

swift package describe
swift build
swift test
