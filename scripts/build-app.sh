#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PRODUCT="FocusSounds"
APP_DIR="$ROOT/dist/${PRODUCT}.app"
SOUNDS_SRC="$ROOT/Sounds"
SOUNDS_DST="$ROOT/Sources/FocusSounds/Resources/Sounds"

mkdir -p "$SOUNDS_DST"
if compgen -G "$SOUNDS_SRC"/* >/dev/null; then
  cp -f "$SOUNDS_SRC"/* "$SOUNDS_DST"/
  echo "Copied bundled sounds from $SOUNDS_SRC"
else
  echo "Warning: $SOUNDS_SRC is empty — add focus sound files before building." >&2
fi

cd "$ROOT"
swift build -c release

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$ROOT/.build/release/$PRODUCT" "$APP_DIR/Contents/MacOS/$PRODUCT"
cp "$ROOT/Sources/FocusSounds/Info.plist" "$APP_DIR/Contents/Info.plist"
chmod +x "$APP_DIR/Contents/MacOS/$PRODUCT"

if compgen -G "$SOUNDS_DST"/* >/dev/null; then
  mkdir -p "$APP_DIR/Contents/Resources/Sounds"
  cp -f "$SOUNDS_DST"/* "$APP_DIR/Contents/Resources/Sounds/"
fi

echo "Built $APP_DIR"
echo "Run: open \"$APP_DIR\""
