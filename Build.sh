#!/bin/bash

set -au

function build_default_native() {
  export OS_NAME=alpine
  export OS_VERSION=3.21
  export FFMPEG_VERSION=7.1.1

  docker build \
    --progress=plain \
    --build-arg BUILD_IMAGE=$OS_NAME:$OS_VERSION \
    --build-arg FFMPEG_VERSION=$FFMPEG_VERSION \
    --build-arg BUILD_DATE="$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
    --build-arg BUILD_COMMIT="$(git rev-parse --short HEAD || echo "unknown")" \
    -f Dockerfile.alpine \
    -t sharapov/flumixa-base:ffmpeg${FFMPEG_VERSION}-${OS_NAME}${OS_VERSION} .
  docker tag sharapov/flumixa-base:ffmpeg${FFMPEG_VERSION}-${OS_NAME}${OS_VERSION} sharapov/flumixa-base:alpine-ffmpeg-latest
}

function build_default() {
  export OS_NAME=alpine
  export OS_VERSION=3.21
  export FFMPEG_VERSION=7.1.1

  docker buildx build \
    --load \
    --progress=plain \
    --build-arg BUILD_IMAGE=$OS_NAME:$OS_VERSION \
    --build-arg FFMPEG_VERSION=$FFMPEG_VERSION \
    --build-arg BUILD_DATE="$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
    --build-arg BUILD_COMMIT="$(git rev-parse --short HEAD || echo "unknown")" \
    --platform linux/amd64 \
    -f Dockerfile.alpine \
    -t sharapov/flumixa-base:ffmpeg${FFMPEG_VERSION}-${OS_NAME}${OS_VERSION} .
  docker tag sharapov/flumixa-base:ffmpeg${FFMPEG_VERSION}-${OS_NAME}${OS_VERSION} sharapov/flumixa-base:ffmpeg-latest
}

function build_rpi() {
  export OS_NAME=alpine
  export OS_VERSION=3.21
  export FFMPEG_VERSION=7.1.1

  docker build \
    --progress=plain \
    --build-arg BUILD_IMAGE=$OS_NAME:$OS_VERSION \
    --build-arg FFMPEG_VERSION=$FFMPEG_VERSION \
    --build-arg BUILD_DATE="$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
    --build-arg BUILD_COMMIT="$(git rev-parse --short HEAD || echo "unknown")" \
    -f Dockerfile.alpine.rpi \
    -t sharapov/flumixa-base:ffmpeg${FFMPEG_VERSION}-rpi-${OS_NAME}${OS_VERSION} .
  docker tag sharapov/flumixa-base:ffmpeg${FFMPEG_VERSION}-rpi-${OS_NAME}${OS_VERSION} sharapov/flumixa-base:ffmpeg-latest
}

function build_cuda12() {
  export OS_NAME=ubuntu
  export OS_VERSION=24.04
  export FFMPEG_VERSION=7.1.1
  export CUDA_VERSION=12.8.0
  export FFNVCODEC_VERSION=12.2.72.0

  docker build \
    --progress=plain \
    --build-arg BUILD_IMAGE=nvidia/cuda:$CUDA_VERSION-devel-ubuntu$OS_VERSION \
    --build-arg DEPLOY_IMAGE=nvidia/cuda:$CUDA_VERSION-runtime-ubuntu$OS_VERSION \
    --build-arg FFNVCODEC_VERSION=$FFNVCODEC_VERSION \
    --build-arg FFMPEG_VERSION=$FFMPEG_VERSION \
    --build-arg BUILD_DATE="$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
    --build-arg BUILD_COMMIT="$(git rev-parse --short HEAD || echo "unknown")" \
    -f Dockerfile.ubuntu.cuda12 \
    -t sharapov/flumixa-base:ffmpeg${FFMPEG_VERSION}-cuda-$OS_NAME$OS_VERSION-cuda${CUDA_VERSION} .
  docker tag sharapov/flumixa-base:ffmpeg${FFMPEG_VERSION}-cuda-$OS_NAME$OS_VERSION-cuda${CUDA_VERSION} sharapov/flumixa-base:ffmpeg-cuda${CUDA_VERSION}-latest
}

function build_vaapi() {
  export OS_NAME=ubuntu
  export OS_VERSION=24.04
  export FFMPEG_VERSION=7.1.1

  docker buildx build \
    --load \
    --progress=plain \
    --build-arg BUILD_IMAGE=$OS_NAME:$OS_VERSION \
    --build-arg DEPLOY_IMAGE=$OS_NAME:$OS_VERSION \
    --build-arg FFMPEG_VERSION=$FFMPEG_VERSION \
    --build-arg BUILD_DATE="$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
    --build-arg BUILD_COMMIT="$(git rev-parse --short HEAD || echo "unknown")" \
    --platform linux/amd64 \
    -f Dockerfile.ubuntu.vaapi \
    -t sharapov/flumixa-base:ffmpeg${FFMPEG_VERSION}-vaapi-${OS_NAME}${OS_VERSION} .
  docker tag sharapov/flumixa-base:ffmpeg${FFMPEG_VERSION}-vaapi-${OS_NAME}${OS_VERSION} sharapov/flumixa-base:ffmpeg-vaapi-latest
}

main() {
  if [[ $# == 0 ]]; then
    echo "Options available: default, default_native, rpi, cuda12, vaapi"
    exit 0
  else
    if [[ $1 == "default" ]]; then
      build_default
    elif [[ $1 == "default_native" ]]; then
      build_default_native
    elif [[ $1 == "rpi" ]]; then
      build_rpi
    elif [[ $1 == "cuda12" ]]; then
      build_cuda12
    elif [[ $1 == "vaapi" ]]; then
      build_vaapi
    fi
  fi
}

main $@

exit 0
