#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# The standalone runner executes the same assertions as the XCTest suite, plus
# a separate-process disk restart. It needs only Apple Command Line Tools.
scripts/test-native.sh
scripts/test-v11.sh
scripts/test-planning.sh
scripts/test-export.sh
if swift -e 'import XCTest' >/dev/null 2>&1; then
  # Desktop may be managed by File Provider; keep signed XCTest bundles outside it.
  swift test --scratch-path "$HOME/Library/Caches/DaylineSwiftPMBuild"
else
  echo "XCTest unavailable in selected toolchain; XCTest suite NOT executed. Native assertions above were executed."
fi
scripts/build-app.sh debug
