#!/usr/bin/env sh
#
# Build a fully-static ffmpeg + ffprobe for Linux x86_64. Uses Alpine's
# musl libc as the C runtime so the resulting binaries have NO dynamic
# library dependencies and run on any glibc-based distro (Debian, Ubuntu,
# Fedora, RHEL, etc.) as well as Alpine.
#
# Run inside an alpine:3.23+ container. The release workflow does this
# via `container:` on a GitHub-hosted Linux runner.
#
# Usage:
#   FFMPEG_VERSION=8.0.1 BUILD_COMMIT=abc123 ./scripts/build-linux.sh
#
# Outputs:
#   dist/ffmpeg-${FFMPEG_VERSION}-linux-amd64.tar.gz
#   dist/ffmpeg-${FFMPEG_VERSION}-linux-amd64/ffmpeg
#   dist/ffmpeg-${FFMPEG_VERSION}-linux-amd64/ffprobe

set -eu

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
# 1. Install build dependencies (Alpine .dev packages bring in static .a libs)
# ---------------------------------------------------------------------------
echo "==> Installing Alpine build dependencies"

apk add --no-cache \
  autoconf \
  automake \
  bash \
  binutils \
  build-base \
  cmake \
  coreutils \
  curl \
  diffutils \
  g++ \
  gcc \
  git \
  libtool \
  linux-headers \
  make \
  musl-dev \
  nasm \
  openssl-dev openssl-libs-static \
  patch \
  pkgconfig \
  tar \
  yasm \
  zlib-dev zlib-static \
  bzip2-dev bzip2-static \
  freetype-dev freetype-static \
  harfbuzz-dev harfbuzz-static \
  libxml2-dev libxml2-static \
  libsrt-dev libsrt-static \
  x264-dev x264-static \
  x265-dev x265-static \
  libvpx-dev \
  lame-dev lame-static \
  opus-dev \
  libvorbis-dev libvorbis-static \
  libogg-dev libogg-static \
  fdk-aac-dev \
  dav1d-dev dav1d-static \
  aom-dev \
  libxcb-dev libxcb-static \
  brotli-dev brotli-static \
  graphite2-dev graphite2-static \
  libpng-dev \
  expat-dev expat-static \
  pcre2-dev

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
# 3. Configure & build (fully static)
# ---------------------------------------------------------------------------
echo "==> Configuring"

cd "$SRC_DIR"

# `-static` on extra-ldflags forces every link step (including the final
# ffmpeg/ffprobe links) to resolve against .a archives, not .so. Combined
# with musl, this produces self-contained binaries. The extra-libs list
# pulls in transitive C/system dependencies that pkg-config sometimes
# misses for static builds (notably the math/atomic/socket bits).
./configure \
  --prefix="${WORK}/install" \
  --extra-version="flumixa-${BUILD_COMMIT}-${BUILD_DATE}" \
  --pkg-config-flags="--static" \
  --extra-cflags="-O2" \
  --extra-ldflags="-static" \
  --extra-libs="-lpthread -lm -lz -ldl" \
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
  --disable-ffplay \
  --disable-doc \
  --disable-debug

echo "==> Building (-j${JOBS})"
make -j"${JOBS}"

# ---------------------------------------------------------------------------
# 4. Verify static + package
# ---------------------------------------------------------------------------
echo "==> Verifying static linkage"
for bin in ffmpeg ffprobe; do
  if ldd "./$bin" 2>&1 | grep -qE "=>|not a dynamic"; then
    if ldd "./$bin" 2>&1 | grep -q "=>"; then
      echo "build-linux: $bin still has dynamic dependencies:" >&2
      ldd "./$bin" >&2
      exit 1
    fi
  fi
  file "./$bin"
done

echo "==> Packaging"
strip ffmpeg ffprobe
cp ffmpeg ffprobe "${DIST}/${PKG_NAME}/"

"${DIST}/${PKG_NAME}/ffmpeg"  -version > "${DIST}/${PKG_NAME}/ffmpeg.version.txt"  2>&1 || true
"${DIST}/${PKG_NAME}/ffprobe" -version > "${DIST}/${PKG_NAME}/ffprobe.version.txt" 2>&1 || true

( cd "$DIST" && tar -czf "${PKG_NAME}.tar.gz" "${PKG_NAME}" )

ls -lh "${DIST}/${PKG_NAME}.tar.gz"
echo "==> Done: ${DIST}/${PKG_NAME}.tar.gz"
