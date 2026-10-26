#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
destination="$HOME/Applications/Dayline.app"
if [[ -e "$destination" && "${DAYLINE_REPLACE_INSTALLED:-}" != "yes" ]]; then
  echo "error: refusing to replace $destination." >&2
  echo "Set DAYLINE_REPLACE_INSTALLED=yes to update this copy." >&2
  echo "The database in ~/Library/Application Support/Dayline is not modified." >&2
  exit 3
fi
./scripts/check-environment.sh
./scripts/build-app.sh release
if [[ -e "$destination" ]]; then
  backup="$HOME/Applications/Dayline-previous-$(date +%Y%m%d-%H%M%S).app"
  if [[ -e "$backup" ]]; then
    echo "Backup path already exists: $backup" >&2
    exit 1
  fi
  mv "$destination" "$backup"
  echo "Previous app retained: $backup"
fi
mkdir -p "$HOME/Applications"
ditto --norsrc --noextattr build/Dayline.app "$destination"
codesign --verify --deep --strict "$destination"
echo "Installed: $destination"
echo "Built from the source in this checkout."
echo "Your database is kept separately in ~/Library/Application Support/Dayline."
