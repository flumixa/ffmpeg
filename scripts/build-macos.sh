#!/usr/bin/env bash
#
# Build a static-ish ffmpeg binary for macOS with the same codec set and
# patches as the Linux Alpine build (full GPL: x264, x265, fdk-aac, vpx,
# dav1d, aom, mp3lame, opus, vorbis, srt, freetype) plus VideoToolbox HW
# acceleration native to macOS.
#
# Apple does not allow fully static binaries (libSystem cannot be statically
# linked), so the resulting binary is statically linked against all third-party
# libraries but dynamically linked against macOS system libraries. This is the
# same approach used by evermeet.cx and BtbN macOS builds.
#
# Usage:
#   FFMPEG_VERSION=8.0.1 ARCH=arm64 BUILD_COMMIT=abc123 ./scripts/build-macos.sh
#
# Outputs:
#   dist/ffmpeg-${FFMPEG_VERSION}-darwin-${ARCH}.tar.gz
#   dist/ffmpeg-${FFMPEG_VERSION}-darwin-${ARCH}/ffmpeg

set -euo pipefail

: "${FFMPEG_VERSION:?FFMPEG_VERSION required (e.g. 8.0.1)}"
: "${ARCH:=$(uname -m)}"
: "${BUILD_COMMIT:=$(git rev-parse --short HEAD 2>/dev/null || echo unknown)}"
: "${BUILD_DATE:=$(date -u +'%Y-%m-%dT%H:%M:%SZ')}"
: "${JOBS:=$(sysctl -n hw.ncpu)}"

case "$ARCH" in
  arm64|aarch64) ARCH=arm64 ;;
  x86_64|amd64)  ARCH=x86_64 ;;
  *) echo "build-macos: unsupported arch '$ARCH'" >&2; exit 1 ;;
esac

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="${REPO_ROOT}/.work-macos-${ARCH}"
DIST="${REPO_ROOT}/dist"
PKG_NAME="ffmpeg-${FFMPEG_VERSION}-darwin-${ARCH}"

mkdir -p "$WORK" "$DIST/${PKG_NAME}"

# ---------------------------------------------------------------------------
# 1. Install build dependencies via Homebrew (idempotent)
# ---------------------------------------------------------------------------
echo "==> Installing Homebrew dependencies"

BREW_PKGS=(
  pkg-config nasm yasm cmake automake libtool autoconf gettext
  x264 x265 libvpx lame opus libvorbis fdk-aac
  srt freetype openssl@3 dav1d aom libxml2 harfbuzz
)

for pkg in "${BREW_PKGS[@]}"; do
  brew list --formula "$pkg" >/dev/null 2>&1 || brew install "$pkg"
done

BREW_PREFIX="$(brew --prefix)"
PKG_CONFIG_PATH="${BREW_PREFIX}/lib/pkgconfig"
PKG_CONFIG_PATH="${PKG_CONFIG_PATH}:${BREW_PREFIX}/opt/openssl@3/lib/pkgconfig"
PKG_CONFIG_PATH="${PKG_CONFIG_PATH}:${BREW_PREFIX}/opt/libxml2/lib/pkgconfig"
export PKG_CONFIG_PATH

# ---------------------------------------------------------------------------
# 2. Download ffmpeg sources and apply Flumixa patches
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
echo "==> Configuring (${ARCH})"

cd "$SRC_DIR"

CFLAGS="-arch ${ARCH} -mmacosx-version-min=11.0 -O2"
LDFLAGS="-arch ${ARCH} -mmacosx-version-min=11.0"

./configure \
  --prefix="${WORK}/install" \
  --extra-version="flumixa-${BUILD_COMMIT}-${BUILD_DATE}" \
  --extra-cflags="${CFLAGS}" \
  --extra-ldflags="${LDFLAGS}" \
  --pkg-config-flags="--static" \
  --enable-static \
  --disable-shared \
  --enable-gpl \
  --enable-version3 \
  --enable-nonfree \
  --enable-openssl \
  --enable-libxml2 \
  --enable-libfreetype \
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
  --enable-videotoolbox \
  --enable-audiotoolbox \
  --disable-ffplay \
  --disable-doc \
  --disable-debug

echo "==> Building (-j${JOBS})"
make -j"${JOBS}"

# ---------------------------------------------------------------------------
# 4. Package
# ---------------------------------------------------------------------------
echo "==> Packaging"
strip ffmpeg
cp ffmpeg "${DIST}/${PKG_NAME}/ffmpeg"

# Print versioning info into the package for easy verification.
"${DIST}/${PKG_NAME}/ffmpeg" -version > "${DIST}/${PKG_NAME}/ffmpeg.version.txt" 2>&1 || true

( cd "$DIST" && tar -czf "${PKG_NAME}.tar.gz" "${PKG_NAME}" )

ls -lh "${DIST}/${PKG_NAME}.tar.gz"
echo "==> Done: ${DIST}/${PKG_NAME}.tar.gz"
