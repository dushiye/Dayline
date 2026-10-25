#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/planning-tests
swiftc -swift-version 5 -parse-as-library \
  Sources/Dayline/Models/PlanningAnalysis.swift \
  Tests/DaylineTests/PlanningChecks.swift scripts/planning-tests.swift \
  -o .build/planning-tests/DaylinePlanningTests
.build/planning-tests/DaylinePlanningTests
