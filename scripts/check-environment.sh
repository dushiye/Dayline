#!/bin/bash
# Reports whether this Mac can build Dayline from source. Exits non-zero on a hard failure.
set -euo pipefail

fail=0
say() { printf '%s\n' "$*"; }
bad() { printf 'error: %s\n' "$*" >&2; fail=1; }

say "Dayline environment check"
say "macOS: $(sw_vers -productVersion) ($(uname -m))"

version="$(sw_vers -productVersion)"
major="${version%%.*}"
if [[ "$major" -lt 14 ]]; then
  bad "Dayline requires macOS 14 or newer."
fi

if ! xcode-select -p >/dev/null 2>&1; then
  bad "No developer directory. Install Xcode or run: xcode-select --install"
else
  say "Developer directory: $(xcode-select -p)"
fi

if ! command -v swift >/dev/null 2>&1; then
  bad "swift is not on PATH."
else
  say "Swift: $(swift --version | head -n 1)"
fi

if ! command -v codesign >/dev/null 2>&1; then
  bad "codesign is not available."
fi

if [[ -d /Applications/Xcode.app ]]; then
  say "Xcode.app: present"
else
  say "Xcode.app: not found. Command Line Tools can still build the Mac app."
fi

if [[ "$fail" -ne 0 ]]; then
  say "Environment check failed."
  exit 1
fi
say "Environment check passed."
