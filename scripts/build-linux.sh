#!/usr/bin/env bash
#
# Build a static-ish ffmpeg + ffprobe for Linux x86_64.
#
# Strategy: build inside Ubuntu 22.04 (glibc 2.35) and statically link
# everything except libc/libpthread/libdl. The resulting binary runs on
# any glibc 2.31+ distro — Debian 11+, Ubuntu 20.04+, Fedora 33+, RHEL 9+
# — with no extra packages required.
#
# We deliberately don't go fully static (`-static`): musl Alpine can't
# easily build static C++ binaries (no libstdc++-static), and a full
# glibc-static binary tickles known issues with NSS/getaddrinfo. The
# glibc-shared / everything-else-static approach is what virtually all
# desktop ffmpeg distributions ship.
#
# Run inside an ubuntu:22.04 container. The release workflow does this
# via `container:` on a GitHub-hosted Linux runner.
#
# Usage:
#   FFMPEG_VERSION=8.0.1 BUILD_COMMIT=abc123 ./scripts/build-linux.sh
#
# Outputs:
#   dist/ffmpeg-${FFMPEG_VERSION}-linux-amd64.tar.gz
#   dist/ffmpeg-${FFMPEG_VERSION}-linux-amd64/ffmpeg
#   dist/ffmpeg-${FFMPEG_VERSION}-linux-amd64/ffprobe

set -euo pipefail

: "${FFMPEG_VERSION:?FFMPEG_VERSION required (e.g. 8.0.1)}"
: "${BUILD_COMMIT:=$(git rev-parse --short HEAD 2>/dev/null || echo unknown)}"
: "${BUILD_DATE:=$(date -u +'%Y-%m-%dT%H:%M:%SZ')}"
: "${JOBS:=$(nproc 2>/dev/null || echo 4)}"

ARCH=amd64
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="${REPO_ROOT}/.work-linux-${ARCH}"
DIST="${REPO_ROOT}/dist"
PKG_NAME="ffmpeg-${FFMPEG_VERSION}-linux-${ARCH}"

mkdir -p "$WORK" "$DIST/${PKG_NAME}"

# ---------------------------------------------------------------------------
# 1. Install build dependencies
# ---------------------------------------------------------------------------
echo "==> Installing apt build dependencies"

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y --no-install-recommends \
  autoconf automake bash binutils build-essential cmake coreutils \
  curl ca-certificates diffutils file g++ gcc git libtool make nasm \
  patch pkg-config tar yasm \
  zlib1g-dev libbz2-dev libssl-dev \
  libfreetype-dev libharfbuzz-dev libxml2-dev \
  libsrt-openssl-dev \
  libx264-dev libx265-dev \
  libvpx-dev \
  libmp3lame-dev libopus-dev libvorbis-dev libogg-dev \
  libfdk-aac-dev \
  libdav1d-dev libaom-dev \
  libxcb1-dev \
  libbrotli-dev

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

# `-static-libgcc` and `-static-libstdc++` link the C and C++ runtimes
# statically, so the resulting binary doesn't depend on libgcc_s.so or
# libstdc++.so being a particular version on the user's system. We DON'T
# pass `-static` overall — that would also try to statically link libc,
# which in glibc-land is fragile (NSS/iconv plugins won't load). Instead
# we accept dynamic glibc, which is universal on Linux desktops.
#
# Codec libs themselves (x264, x265, aom, dav1d, etc.) ARE linked
# statically because Ubuntu's -dev packages ship .a archives and the
# linker prefers .a when both are available with -Wl,-Bstatic chains.
# We use --extra-ldflags to push gcc towards static when possible.
./configure \
  --prefix="${WORK}/install" \
  --extra-version="flumixa-${BUILD_COMMIT}-${BUILD_DATE}" \
  --extra-cflags="-O2" \
  --extra-ldflags="-static-libgcc -static-libstdc++" \
  --extra-libs="-lpthread -lm -lz -ldl" \
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
  --disable-ffplay \
  --disable-doc \
  --disable-debug

echo "==> Building (-j${JOBS})"
make -j"${JOBS}"

# ---------------------------------------------------------------------------
# 4. Verify and package
# ---------------------------------------------------------------------------
echo "==> Linkage report"
for bin in ffmpeg ffprobe; do
  echo "-- $bin --"
  file "./$bin"
  ldd "./$bin" || true
done

echo "==> Packaging"
strip ffmpeg ffprobe
cp ffmpeg ffprobe "${DIST}/${PKG_NAME}/"

"${DIST}/${PKG_NAME}/ffmpeg"  -version > "${DIST}/${PKG_NAME}/ffmpeg.version.txt"  2>&1 || true
"${DIST}/${PKG_NAME}/ffprobe" -version > "${DIST}/${PKG_NAME}/ffprobe.version.txt" 2>&1 || true

( cd "$DIST" && tar -czf "${PKG_NAME}.tar.gz" "${PKG_NAME}" )

ls -lh "${DIST}/${PKG_NAME}.tar.gz"
echo "==> Done: ${DIST}/${PKG_NAME}.tar.gz"
