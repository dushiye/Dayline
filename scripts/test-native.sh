#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/native-tests
arch_name="$(uname -m)"
scratch="${DAYLINE_SCRIPT_SCRATCH:-$HOME/Library/Caches/DaylineScriptTests/native}"
swift build --scratch-path "$scratch"
products="$scratch/out/Products/Debug"
swiftc -swift-version 5 -parse-as-library -D DAYLINE_SCRIPT_TEST \
  -target "${arch_name}-apple-macosx14.0" -I "$products" \
  Tests/DaylineTests/RuleChecks.swift scripts/native-tests.swift \
  "$products/DaylineData.o" "$products/DaylineCore.o" -lsqlite3 \
  -o .build/native-tests/DaylineNativeTests
.build/native-tests/DaylineNativeTests
