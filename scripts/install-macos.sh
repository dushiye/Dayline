#!/bin/bash
# Builds the current source, then copies Dayline.app to a path the caller names.
# It never reads or writes ~/Library/Application Support/Dayline.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

usage() {
  cat <<'EOF'
Usage: scripts/install-macos.sh /path/to/Dayline.app

Checks the environment, builds the Mac app from this checkout, then copies it.
A later run after git pull therefore installs the updated source.
It does not create or modify the personal database in
~/Library/Application Support/Dayline.

A new path, including a missing ~/Applications/Dayline.app, is created.
Replacing an existing ~/Applications/Dayline.app requires
DAYLINE_REPLACE_INSTALLED=yes. Replacing any other existing path requires
DAYLINE_REPLACE_DESTINATION=yes. The previous app bundle is moved aside.

EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || $# -ne 1 ]]; then
  usage
  exit 2
fi

destination="$1"
formal="$HOME/Library/Application Support/Dayline"
case "$destination" in
  "$formal"|"$formal"/*)
    echo "error: refusing to install into the personal Dayline data directory." >&2
    exit 1
    ;;
esac

installed="$HOME/Applications/Dayline.app"
if [[ -e "$destination" ]]; then
  if [[ "$destination" == "$installed" && "${DAYLINE_REPLACE_INSTALLED:-}" != "yes" ]]; then
    echo "error: refusing to replace ~/Applications/Dayline.app." >&2
    echo "Set DAYLINE_REPLACE_INSTALLED=yes only when you intend to update that installed copy." >&2
    echo "The personal database will still be left untouched." >&2
    exit 3
  fi
  if [[ "$destination" != "$installed" && "${DAYLINE_REPLACE_DESTINATION:-}" != "yes" ]]; then
    echo "error: destination already exists: $destination" >&2
    echo "Set DAYLINE_REPLACE_DESTINATION=yes to replace that copy." >&2
    exit 3
  fi
fi

# Build before moving any existing app, so a failed compile leaves that app in place.
"$root/scripts/check-environment.sh"
"$root/scripts/build-app.sh" release

if [[ -e "$destination" ]]; then
  backup="${destination%.app}-previous-$(date +%Y%m%d-%H%M%S).app"
  if [[ -e "$backup" ]]; then
    echo "error: backup path already exists: $backup" >&2
    exit 1
  fi
  mv "$destination" "$backup"
  echo "Previous app retained: $backup"
fi

source_app="$(cd "$root/build/Dayline.app" && pwd -P)"
mkdir -p "$(dirname "$destination")"
ditto --norsrc --noextattr "$source_app" "$destination"
codesign --verify --deep --strict "$destination"
echo "Installed copy: $destination"
echo "Built from the source in this checkout."
echo "Personal data was not read or changed."
echo "A copy you built on this Mac uses a local ad-hoc signature."
