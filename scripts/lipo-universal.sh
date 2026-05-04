#!/usr/bin/env bash
#
# Combine arm64 and x86_64 macOS ffmpeg binaries into a single universal
# binary using Apple's lipo tool. Expects both single-arch packages to be
# already extracted (or downloaded as workflow artifacts).
#
# Usage:
#   FFMPEG_VERSION=8.0.1 \
#   ARM64_BIN=/path/to/arm64/ffmpeg \
#   AMD64_BIN=/path/to/x86_64/ffmpeg \
#   ./scripts/lipo-universal.sh

set -euo pipefail

: "${FFMPEG_VERSION:?FFMPEG_VERSION required}"
: "${ARM64_BIN:?ARM64_BIN required}"
: "${AMD64_BIN:?AMD64_BIN required}"

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="${REPO_ROOT}/dist"
PKG_NAME="ffmpeg-${FFMPEG_VERSION}-darwin-universal"

mkdir -p "${DIST}/${PKG_NAME}"

lipo -create -output "${DIST}/${PKG_NAME}/ffmpeg" "$ARM64_BIN" "$AMD64_BIN"
chmod +x "${DIST}/${PKG_NAME}/ffmpeg"

echo "==> lipo result:"
lipo -info "${DIST}/${PKG_NAME}/ffmpeg"

"${DIST}/${PKG_NAME}/ffmpeg" -version > "${DIST}/${PKG_NAME}/ffmpeg.version.txt" 2>&1 || true

( cd "$DIST" && tar -czf "${PKG_NAME}.tar.gz" "${PKG_NAME}" )

ls -lh "${DIST}/${PKG_NAME}.tar.gz"
