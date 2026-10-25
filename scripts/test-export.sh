#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/export-tests
arch_name="$(uname -m)"
swiftc -swift-version 5 -parse-as-library -target "${arch_name}-apple-macosx14.0" \
  Sources/Dayline/Export/*.swift Tests/DaylineTests/ExportChecks.swift \
  scripts/export-tests.swift -o .build/export-tests/DaylineExportTests
.build/export-tests/DaylineExportTests "${1:-build/export-samples}"
