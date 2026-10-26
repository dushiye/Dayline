#!/bin/bash
# Builds the Mac app with the existing release script. Does not install it and does not open a database.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
"$root/scripts/check-environment.sh"
"$root/scripts/build-app.sh" release
say_built="$(readlink "$root/build/Dayline.app" || true)"
printf '\nBuilt. The app was not installed.\n'
printf 'Shortcut: %s\n' "$root/build/Dayline.app"
if [[ -n "$say_built" ]]; then
  printf 'Bundle: %s\n' "$say_built"
fi
printf 'Next, install only to a path you choose:\n'
printf '  scripts/install-macos.sh /desired/path/Dayline.app\n'
printf 'This build does not read ~/Library/Application Support/Dayline.\n'
