#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
destination="$HOME/Applications/Dayline.app"
if [[ -e "$destination" ]]; then
  printf 'An existing app will be moved aside: %s\n' "$destination"
  printf 'The database in ~/Library/Application Support/Dayline will not be changed.\n'
  printf 'Continue? [y/N] '
  read -r answer
  if [[ "$answer" != "y" && "$answer" != "Y" ]]; then
    echo "Cancelled."
    exit 1
  fi
  export DAYLINE_REPLACE_INSTALLED=yes
fi
./scripts/install.sh
open "$destination"
