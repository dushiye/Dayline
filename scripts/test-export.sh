#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/export-tests
arch_name="$(uname -m)"
scratch="${DAYLINE_SCRIPT_SCRATCH:-$HOME/Library/Caches/DaylineScriptTests/export}"
swift build --scratch-path "$scratch"
products="$scratch/out/Products/Debug"
swiftc -swift-version 5 -parse-as-library -D DAYLINE_SCRIPT_TEST \
  -target "${arch_name}-apple-macosx14.0" -I "$products" \
  Sources/Dayline/Export/*.swift Tests/DaylineTests/ExportChecks.swift \
  scripts/export-tests.swift "$products/DaylineData.o" "$products/DaylineCore.o" \
  -lsqlite3 -o .build/export-tests/DaylineExportTests
.build/export-tests/DaylineExportTests "${1:-build/export-samples}"
