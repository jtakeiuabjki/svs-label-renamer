#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="4.0.1.2"
ARCHIVE_NAME="openslide-bin-${VERSION}-macos-arm64-x86_64.tar.xz"
URL="https://github.com/openslide/openslide-bin/releases/download/v${VERSION}/${ARCHIVE_NAME}"
EXPECTED_SHA256="d4aadd29bbb84f3e9392627f71c52332af094bbea4e56f58e977b7a149448dbb"
DOWNLOAD_DIR="$ROOT/.vendor/downloads"
RUNTIME_DIR="$ROOT/.vendor/openslide"
ARCHIVE="$DOWNLOAD_DIR/$ARCHIVE_NAME"

if [[ -x "$RUNTIME_DIR/bin/slidetool" && -f "$RUNTIME_DIR/lib/libopenslide.1.dylib" ]]; then
    echo "OpenSlide runtime is ready: $RUNTIME_DIR"
    exit 0
fi

mkdir -p "$DOWNLOAD_DIR" "$ROOT/.vendor"

NEEDS_DOWNLOAD=1
if [[ -f "$ARCHIVE" ]]; then
    EXISTING_SHA256="$(shasum -a 256 "$ARCHIVE" | awk '{print $1}')"
    if [[ "$EXISTING_SHA256" == "$EXPECTED_SHA256" ]]; then
        NEEDS_DOWNLOAD=0
    fi
fi
if [[ "$NEEDS_DOWNLOAD" == "1" ]]; then
    curl --fail --location --retry 5 --continue-at - --output "$ARCHIVE" "$URL"
fi

ACTUAL_SHA256="$(shasum -a 256 "$ARCHIVE" | awk '{print $1}')"
if [[ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]]; then
    echo "OpenSlide checksum mismatch" >&2
    echo "expected: $EXPECTED_SHA256" >&2
    echo "actual:   $ACTUAL_SHA256" >&2
    exit 1
fi

UNPACKED="$ROOT/.vendor/unpacked-$VERSION"
rm -rf "$UNPACKED"
mkdir -p "$UNPACKED"
tar -xJf "$ARCHIVE" -C "$UNPACKED"
SLIDETOOL="$(find "$UNPACKED" -type f -path '*/bin/slidetool' -print -quit)"
if [[ -z "$SLIDETOOL" ]]; then
    echo "slidetool was not found in the official archive" >&2
    exit 1
fi
UPSTREAM_ROOT="$(cd "$(dirname "$SLIDETOOL")/.." && pwd)"
rm -rf "$RUNTIME_DIR"
mkdir -p "$RUNTIME_DIR/bin" "$RUNTIME_DIR/lib" "$RUNTIME_DIR/licenses"
cp "$UPSTREAM_ROOT/bin/slidetool" "$RUNTIME_DIR/bin/"
cp "$UPSTREAM_ROOT/lib/libopenslide.1.dylib" "$RUNTIME_DIR/lib/"
cp -R "$UPSTREAM_ROOT/licenses/." "$RUNTIME_DIR/licenses/"
cp "$UPSTREAM_ROOT/README.md" "$RUNTIME_DIR/"
cp "$UPSTREAM_ROOT/VERSIONS.md" "$RUNTIME_DIR/"
chmod +x "$RUNTIME_DIR/bin/slidetool"
rm -rf "$UNPACKED"
echo "OpenSlide runtime is ready: $RUNTIME_DIR"
