#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
./scripts/install.sh
open "$HOME/Applications/Dayline.app"
