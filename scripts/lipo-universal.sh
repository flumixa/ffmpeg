#!/usr/bin/env bash
#
# Combine arm64 and x86_64 macOS ffmpeg + ffprobe binaries into a single
# universal package using Apple's lipo tool. Expects both single-arch
# packages to be already extracted (or downloaded as workflow artifacts).
#
# Two ways to call:
#
#   1. Point at the extracted per-arch package directories (preferred —
#      handles every binary inside automatically):
#
#      FFMPEG_VERSION=8.0.1 \
#      ARM64_DIR=/path/to/ffmpeg-8.0.1-darwin-arm64 \
#      AMD64_DIR=/path/to/ffmpeg-8.0.1-darwin-x86_64 \
#      ./scripts/lipo-universal.sh
#
#   2. Legacy: pass individual ffmpeg binary paths (universal package will
#      contain only ffmpeg, no ffprobe):
#
#      FFMPEG_VERSION=8.0.1 \
#      ARM64_BIN=/path/to/arm64/ffmpeg \
#      AMD64_BIN=/path/to/x86_64/ffmpeg \
#      ./scripts/lipo-universal.sh

set -euo pipefail

: "${FFMPEG_VERSION:?FFMPEG_VERSION required}"

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="${REPO_ROOT}/dist"
PKG_NAME="ffmpeg-${FFMPEG_VERSION}-darwin-universal"
OUT_DIR="${DIST}/${PKG_NAME}"

mkdir -p "$OUT_DIR"

# lipo_one: lipo-merge a single binary name from the two source dirs.
lipo_one() {
  local name="$1" arm="$2" amd="$3"
  if [ ! -f "$arm" ] || [ ! -f "$amd" ]; then
    echo "lipo-universal: missing $name in one of the inputs ($arm / $amd) — skipping" >&2
    return 0
  fi
  lipo -create -output "${OUT_DIR}/${name}" "$arm" "$amd"
  chmod +x "${OUT_DIR}/${name}"
  echo "==> lipo $name:"
  lipo -info "${OUT_DIR}/${name}"
  "${OUT_DIR}/${name}" -version > "${OUT_DIR}/${name}.version.txt" 2>&1 || true
}

if [ -n "${ARM64_DIR:-}" ] && [ -n "${AMD64_DIR:-}" ]; then
  for bin in ffmpeg ffprobe; do
    lipo_one "$bin" "${ARM64_DIR}/${bin}" "${AMD64_DIR}/${bin}"
  done
elif [ -n "${ARM64_BIN:-}" ] && [ -n "${AMD64_BIN:-}" ]; then
  # Legacy mode: only handles ffmpeg.
  lipo_one ffmpeg "$ARM64_BIN" "$AMD64_BIN"
else
  echo "lipo-universal: provide either ARM64_DIR+AMD64_DIR or ARM64_BIN+AMD64_BIN" >&2
  exit 1
fi

( cd "$DIST" && tar -czf "${PKG_NAME}.tar.gz" "${PKG_NAME}" )

ls -lh "${DIST}/${PKG_NAME}.tar.gz"
