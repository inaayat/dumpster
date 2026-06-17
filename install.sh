#!/usr/bin/env bash
set -e

REPO="https://github.com/inaayat/dumpster.git"
DIR="$HOME/dumpster"
APP="/Applications/Dumpster.app"

echo "==> Cloning Dumpster..."
if [ -d "$DIR/.git" ]; then
  git -C "$DIR" pull --ff-only
else
  git clone "$REPO" "$DIR"
fi

echo "==> Building (this takes ~30s)..."
cd "$DIR"
swift build -c release

echo "==> Installing to $APP..."
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Dumpster "$APP/Contents/MacOS/"
cp -R .build/release/Dumpster_Dumpster.bundle "$APP/Contents/Resources/"
cp Sources/Dumpster/Resources/AppIcon.icns "$APP/Contents/Resources/"
codesign --force --sign - "$APP/Contents/MacOS/Dumpster"
codesign --force --sign - "$APP"

echo "==> Done! Opening Dumpster..."
open "$APP"
