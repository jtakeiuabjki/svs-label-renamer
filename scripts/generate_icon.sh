#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="$ROOT/Resources/AppIcon.svg"
WORK="$ROOT/.build-icon"
ICONSET="$WORK/AppIcon.iconset"
OUTPUT="$ROOT/Resources/AppIcon.icns"

rm -rf "$WORK"
mkdir -p "$ICONSET"
qlmanage -t -s 1024 -o "$WORK" "$SOURCE" >/dev/null
MASTER="$WORK/AppIcon.svg.png"

for SIZE in 16 32 128 256 512; do
    sips -z "$SIZE" "$SIZE" "$MASTER" --out "$ICONSET/icon_${SIZE}x${SIZE}.png" >/dev/null
    DOUBLE=$((SIZE * 2))
    sips -z "$DOUBLE" "$DOUBLE" "$MASTER" --out "$ICONSET/icon_${SIZE}x${SIZE}@2x.png" >/dev/null
done

iconutil -c icns "$ICONSET" -o "$OUTPUT"
rm -rf "$WORK"
echo "Generated: $OUTPUT"
