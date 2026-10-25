#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ ! -x build/Dayline.app/Contents/MacOS/Dayline ]]; then
  ./scripts/build-app.sh release
fi
destination="$HOME/Applications/Dayline.app"
mkdir -p "$HOME/Applications"
if [[ -e "$destination" ]]; then
  backup="$HOME/Applications/Dayline-previous-$(date +%Y%m%d-%H%M%S).app"
  if [[ -e "$backup" ]]; then
    echo "Backup path already exists: $backup" >&2
    exit 1
  fi
  mv "$destination" "$backup"
  echo "Previous app retained: $backup"
fi
ditto --norsrc --noextattr build/Dayline.app "$destination"
codesign --verify --deep --strict "$destination"
echo "Installed: $destination"
echo "Your database is kept separately in ~/Library/Application Support/Dayline."
