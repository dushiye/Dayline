#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
configuration="${1:-release}"
if [[ "$configuration" != release && "$configuration" != debug ]]; then
  echo "Usage: scripts/build-app.sh [release|debug]" >&2
  exit 2
fi
swift build -c "$configuration"
binary_dir="$(swift build -c "$configuration" --show-bin-path)"
project_key="$(printf '%s' "$PWD" | shasum | cut -c1-12)"
# Desktop can be managed by File Provider, which immediately re-adds FinderInfo
# to .app directories and prevents code signing. Assemble outside synced folders.
app_dir="$HOME/Library/Caches/DaylineBuild/$project_key/Dayline.app"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp -X "$binary_dir/Dayline" "$app_dir/Contents/MacOS/Dayline"
cp -X Resources/Info.plist "$app_dir/Contents/Info.plist"
if [[ -f Resources/Dayline.icns ]]; then cp -X Resources/Dayline.icns "$app_dir/Contents/Resources/Dayline.icns"; fi
printf 'APPL????' > "$app_dir/Contents/PkgInfo"
# Finder/File Provider may decorate the generated bundle after it is opened.
# Strip only signing-incompatible cosmetic metadata from our build artifact.
xattr -dr com.apple.FinderInfo "$app_dir" 2>/dev/null || true
xattr -dr com.apple.ResourceFork "$app_dir" 2>/dev/null || true
codesign --force --deep --sign - "$app_dir"
codesign --verify --deep --strict "$app_dir"
mkdir -p build
if [[ -L build/Dayline.app ]]; then
  rm build/Dayline.app
elif [[ -e build/Dayline.app ]]; then
  mv build/Dayline.app "build/Dayline-previous-$(date +%Y%m%d-%H%M%S).app"
fi
ln -s "$app_dir" build/Dayline.app
ditto -c -k --keepParent --norsrc --noextattr "$app_dir" build/Dayline-macOS.zip
echo "Built: $app_dir"
echo "Project shortcut: $PWD/build/Dayline.app"
echo "Portable archive: $PWD/build/Dayline-macOS.zip"
