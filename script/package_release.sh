#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-0.1.0}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE_DIR="$ROOT_DIR/release"
APP_BUNDLE="$ROOT_DIR/dist/DockDock.app"
ZIP_PATH="$RELEASE_DIR/DockDock-$VERSION.zip"

mkdir -p "$RELEASE_DIR"
"$ROOT_DIR/script/build_and_run.sh" --build-only

rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"

SHA256="$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')"

cat <<EOF
Release artifact:
  $ZIP_PATH

Homebrew Cask values:
  version: $VERSION
  sha256:  $SHA256
EOF
