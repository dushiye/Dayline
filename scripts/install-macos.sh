#!/bin/bash
# Copies a locally built Dayline.app to a destination the caller names.
# It never reads or writes ~/Library/Application Support/Dayline.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

usage() {
  cat <<'EOF'
Usage: scripts/install-macos.sh /path/to/Dayline.app

Copies the app built by scripts/build-macos.sh. It does not create or modify
the personal database in ~/Library/Application Support/Dayline.

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
  backup="${destination%.app}-previous-$(date +%Y%m%d-%H%M%S).app"
  if [[ -e "$backup" ]]; then
    echo "error: backup path already exists: $backup" >&2
    exit 1
  fi
  mv "$destination" "$backup"
  echo "Previous app retained: $backup"
fi

if [[ ! -x "$root/build/Dayline.app/Contents/MacOS/Dayline" ]]; then
  "$root/scripts/build-macos.sh"
fi

source_app="$(cd "$root/build/Dayline.app" && pwd -P)"
mkdir -p "$(dirname "$destination")"
if [[ -e "$destination" ]]; then
  rm -rf "$destination"
fi
ditto --norsrc --noextattr "$source_app" "$destination"
codesign --verify --deep --strict "$destination"
echo "Installed copy: $destination"
echo "Personal data was not read or changed."
echo "First launch of a copy you built yourself uses a local ad-hoc signature."
echo "Do not download an ad-hoc build from someone else and disable Gatekeeper to open it."
