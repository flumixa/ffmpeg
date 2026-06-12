#!/usr/bin/env bash
#
# Build a static ffmpeg.exe for Windows x64 using MSYS2/MinGW64.
#
# Run inside an MSYS2 MINGW64 shell (the GitHub Actions msys2/setup-msys2
# action provides this). All third-party libraries are statically linked;
# the resulting .exe depends only on KERNEL32/USER32/etc. (Windows system DLLs).
#
# Usage:
#   FFMPEG_VERSION=8.0.1 BUILD_COMMIT=abc123 ./scripts/build-windows.sh

set -euo pipefail

: "${FFMPEG_VERSION:?FFMPEG_VERSION required (e.g. 8.0.1)}"
: "${BUILD_COMMIT:=$(git rev-parse --short HEAD 2>/dev/null || echo unknown)}"
: "${BUILD_DATE:=$(date -u +'%Y-%m-%dT%H:%M:%SZ')}"
: "${JOBS:=$(nproc 2>/dev/null || echo 4)}"

ARCH=x64
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="${REPO_ROOT}/.work-windows-${ARCH}"
DIST="${REPO_ROOT}/dist"
PKG_NAME="ffmpeg-${FFMPEG_VERSION}-windows-${ARCH}"

mkdir -p "$WORK" "$DIST/${PKG_NAME}"

# ---------------------------------------------------------------------------
# 1. Verify build environment
# ---------------------------------------------------------------------------
if [ "${MSYSTEM:-}" != "MINGW64" ] && [ "${MSYSTEM:-}" != "UCRT64" ]; then
  echo "build-windows: must run inside MSYS2 MINGW64/UCRT64 shell" >&2
  exit 1
fi

# Static deps from MSYS2/MinGW64 repos. MSYS2 ships static (.a) variants of
# all these libraries via the same package.
PACMAN_PKGS=(
  base-devel
  mingw-w64-x86_64-toolchain
  mingw-w64-x86_64-pkgconf
  mingw-w64-x86_64-nasm
  mingw-w64-x86_64-yasm
  mingw-w64-x86_64-cmake
  mingw-w64-x86_64-x264
  mingw-w64-x86_64-x265
  mingw-w64-x86_64-libvpx
  mingw-w64-x86_64-lame
  mingw-w64-x86_64-opus
  mingw-w64-x86_64-libvorbis
  mingw-w64-x86_64-fdk-aac
  mingw-w64-x86_64-srt
  mingw-w64-x86_64-freetype
  mingw-w64-x86_64-harfbuzz
  mingw-w64-x86_64-openssl
  mingw-w64-x86_64-dav1d
  mingw-w64-x86_64-aom
  mingw-w64-x86_64-libxml2
  mingw-w64-x86_64-amf-headers
)

echo "==> Installing MSYS2 packages"
pacman -S --needed --noconfirm "${PACMAN_PKGS[@]}"

# ---------------------------------------------------------------------------
# 2. Download ffmpeg source and apply patches
# ---------------------------------------------------------------------------
SRC_TAR="${WORK}/ffmpeg-${FFMPEG_VERSION}.tar.gz"
SRC_DIR="${WORK}/ffmpeg-${FFMPEG_VERSION}"

if [ ! -f "$SRC_TAR" ]; then
  echo "==> Downloading ffmpeg ${FFMPEG_VERSION}"
  curl -fsSL "https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.gz" -o "$SRC_TAR"
fi

if [ ! -d "$SRC_DIR" ]; then
  echo "==> Extracting"
  tar -xz -C "$WORK" -f "$SRC_TAR"

  echo "==> Applying patches"
  ( cd "$SRC_DIR" && \
    patch -p1 < "${REPO_ROOT}/contrib/ffmpeg-jsonstats.patch" && \
    patch -p1 < "${REPO_ROOT}/contrib/ffmpeg-hls.patch" )
fi

# ---------------------------------------------------------------------------
# 3. Configure & build
# ---------------------------------------------------------------------------
echo "==> Configuring"

cd "$SRC_DIR"

./configure \
  --prefix="${WORK}/install" \
  --extra-version="flumixa-${BUILD_COMMIT}-${BUILD_DATE}" \
  --pkg-config-flags="--static" \
  --extra-cflags="-O2" \
  --extra-libs="-lpthread -lm -lz -lws2_32 -lcrypt32" \
  --enable-static \
  --disable-shared \
  --enable-gpl \
  --enable-version3 \
  --enable-nonfree \
  --enable-openssl \
  --enable-libxml2 \
  --enable-libfreetype \
  --enable-libharfbuzz \
  --enable-libsrt \
  --enable-libx264 \
  --enable-libx265 \
  --enable-libvpx \
  --enable-libmp3lame \
  --enable-libopus \
  --enable-libvorbis \
  --enable-libfdk-aac \
  --enable-libdav1d \
  --enable-libaom \
  --enable-d3d11va \
  --enable-dxva2 \
  --enable-mediafoundation \
  --enable-amf \
  --disable-ffplay \
  --disable-doc \
  --disable-debug

echo "==> Building (-j${JOBS})"
make -j"${JOBS}"

# ---------------------------------------------------------------------------
# 4. Package
# ---------------------------------------------------------------------------
echo "==> Packaging"
# ffprobe.exe is built alongside ffmpeg.exe by the same `make` invocation
# (configure leaves it enabled by default). Both go into the package — the
# Wails desktop app uses ffprobe for media metadata extraction.
strip ffmpeg.exe ffprobe.exe
cp ffmpeg.exe ffprobe.exe "${DIST}/${PKG_NAME}/"

"${DIST}/${PKG_NAME}/ffmpeg.exe"  -version > "${DIST}/${PKG_NAME}/ffmpeg.version.txt"  2>&1 || true
"${DIST}/${PKG_NAME}/ffprobe.exe" -version > "${DIST}/${PKG_NAME}/ffprobe.version.txt" 2>&1 || true

( cd "$DIST" && \
  if command -v zip >/dev/null 2>&1; then
    zip -r "${PKG_NAME}.zip" "${PKG_NAME}"
  else
    7z a -tzip "${PKG_NAME}.zip" "${PKG_NAME}"
  fi )

ls -lh "${DIST}/${PKG_NAME}.zip"
echo "==> Done: ${DIST}/${PKG_NAME}.zip"
