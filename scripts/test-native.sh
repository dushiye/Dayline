#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/native-tests
arch_name="$(uname -m)"
swiftc -swift-version 5 -parse-as-library -target "${arch_name}-apple-macosx14.0" \
  Sources/Dayline/Models/*.swift Tests/DaylineTests/RuleChecks.swift \
  scripts/native-tests.swift -o .build/native-tests/DaylineNativeTests
.build/native-tests/DaylineNativeTests
