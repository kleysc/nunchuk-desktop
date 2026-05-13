#!/usr/bin/env bash
# Packages build/Nunchuk.app into a portable, self-contained .dmg.
# Run after `build.sh` succeeds. Requires Qt5 macdeployqt and create-dmg.
set -euo pipefail

SRC_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP="$SRC_ROOT/build/Nunchuk.app"
QMLDIR="$SRC_ROOT/Qml"
DMG="$SRC_ROOT/build/Nunchuk-dev-macos.dmg"

MACDEPLOYQT="${MACDEPLOYQT:-/opt/homebrew/opt/qt@5/bin/macdeployqt}"
[[ -x "$MACDEPLOYQT" ]] || MACDEPLOYQT="$(command -v macdeployqt || true)"

if [[ ! -x "$MACDEPLOYQT" ]]; then
  echo "error: macdeployqt not found. Install Qt5: brew install qt@5" >&2
  exit 1
fi

if ! command -v create-dmg >/dev/null 2>&1; then
  echo "error: create-dmg not found. Install: brew install create-dmg" >&2
  exit 1
fi

if [[ ! -d "$APP" ]]; then
  echo "error: $APP not found. Run ./build.sh first." >&2
  exit 1
fi

if [[ ! -d "$QMLDIR" ]]; then
  echo "error: QML dir $QMLDIR not found." >&2
  exit 1
fi

echo "==> Running macdeployqt"
"$MACDEPLOYQT" "$APP" -qmldir="$QMLDIR" -always-overwrite

echo "==> Verifying bundle has no /opt/homebrew or /usr/local LOAD references"
# otool -L prints: header line, then install_name (LC_ID_DYLIB) on line 2, then LOAD deps.
# We only care about LOAD deps (line 3+), since install_name is cosmetic metadata.
LEAKS=""
while IFS= read -r -d '' f; do
  deps=$(otool -L "$f" 2>/dev/null | tail -n +3 | grep -E '/opt/homebrew|/usr/local/(opt|Cellar)' || true)
  if [[ -n "$deps" ]]; then
    LEAKS+="${f}:"$'\n'"${deps}"$'\n'
  fi
done < <(find "$APP" -type f \( -name '*.dylib' -o -name 'Nunchuk' \) -print0)

if [[ -n "$LEAKS" ]]; then
  echo "error: bundle still has host-path LOAD references:" >&2
  echo "$LEAKS" >&2
  exit 1
fi
echo "    bundle is self-contained ✓"

echo "==> Building $DMG"
rm -f "$DMG"
create-dmg \
  --volname "Nunchuk" \
  --window-size 540 360 \
  --icon-size 110 \
  --icon "Nunchuk.app" 140 180 \
  --app-drop-link 400 180 \
  --no-internet-enable \
  "$DMG" \
  "$APP"

echo "==> Done: $DMG"
