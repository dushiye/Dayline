#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/v11-tests
arch_name="$(uname -m)"
swiftc -swift-version 5 -parse-as-library -target "${arch_name}-apple-macosx14.0" \
  Sources/Dayline/Models/*.swift Tests/DaylineTests/RuleChecks.swift \
  Tests/DaylineTests/V11Checks.swift scripts/v11-tests.swift \
  -o .build/v11-tests/DaylineV11Tests
.build/v11-tests/DaylineV11Tests
