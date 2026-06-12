# FFmpeg Base

FFmpeg base image for [flumixa](https://github.com/flumixa).

[![alpine](https://github.com/flumixa/ffmpeg/actions/workflows/build_base_alpine.yaml/badge.svg)](https://github.com/flumixa/ffmpeg/actions/workflows/build_base_alpine.yaml)
[![alpine-rpi](https://github.com/flumixa/ffmpeg/actions/workflows/build_base_alpine-rpi.yaml/badge.svg)](https://github.com/flumixa/ffmpeg/actions/workflows/build_base_alpine-rpi.yaml)
[![ubuntu-ffmpeg-vvapi](https://github.com/flumixa/ffmpeg/actions/workflows/build_base_ubuntu-vaapi.yaml/badge.svg)](https://github.com/flumixa/ffmpeg/actions/workflows/build_base_ubuntu-vaapi.yaml)
[![ubuntu-cuda](https://github.com/flumixa/ffmpeg/actions/workflows/build_base_ubuntu-cuda.yaml/badge.svg)](https://github.com/flumixa/ffmpeg/actions/workflows/build_base_ubuntu-cuda.yaml)
[![macos](https://github.com/flumixa/ffmpeg/actions/workflows/build_macos.yaml/badge.svg)](https://github.com/flumixa/ffmpeg/actions/workflows/build_macos.yaml)
[![windows](https://github.com/flumixa/ffmpeg/actions/workflows/build_windows.yaml/badge.svg)](https://github.com/flumixa/ffmpeg/actions/workflows/build_windows.yaml)

Branch: 8.0

## Config:

```sh
--enable-libv4l2
--enable-libfreetype
--enable-libharfbuzz
--enable-alsa
--enable-libsrt
--enable-libx264
--enable-libx265
--enable-libvpx
--enable-libmp3lame
--enable-libopus
--enable-libvorbis
```

_Additional information can be found in the Dockerfiles._

## Patches ([contrib](contrib/)):

- JSON-Stats (expands progress data per file in json format)
- HLS Bitrate (calculates bitrate estimate for HLS master playlist)

## Images and Platforms:

### Linux (Docker images)

| Dockerimage                                          | OS            | Plattform                                | GPU                                         |
|------------------------------------------------------|---------------|------------------------------------------|---------------------------------------------|
| docker.io/sharapov/flumixa-base:ffmpeg-latest        | Alpine 3.23.2 | linux/amd64, linux/arm64, linux/arm/v7   | -                                           |
| docker.io/sharapov/flumixa-base:ffmpeg-rpi-latest    | Alpine 3.23.2 | Raspberry Pi (linux/arm/v7, linux/arm64) | MMAL/OMX/V4L2-M2M (32bit), V4L2-M2M (64bit) |
| docker.io/sharapov/flumixa-base:ffmpeg-cuda12-latest | Ubuntu 24.04  | linux/amd64                              | Nvidia Cuda                                 |
| docker.io/sharapov/flumixa-base:ffmpeg-cuda13-latest | Ubuntu 24.04  | linux/amd64                              | Nvidia Cuda                                 |
| docker.io/sharapov/flumixa-base:ffmpeg-vaapi-latest  | Ubuntu 24.04  | linux/amd64                              | Intel VAAPI                                 |

More tags: https://hub.docker.com/repository/docker/sharapov/flumixa-base/general

### macOS / Windows (GitHub Releases)

Standalone binaries for desktop builds (used by [FlumixaApp](https://github.com/flumixa/FlumixaApp)).

| Asset                                       | Platform                  | HW acceleration                       |
|---------------------------------------------|---------------------------|---------------------------------------|
| `ffmpeg-X.Y.Z-darwin-arm64.tar.gz`          | macOS Apple Silicon       | VideoToolbox, AudioToolbox            |
| `ffmpeg-X.Y.Z-darwin-x86_64.tar.gz`         | macOS Intel               | VideoToolbox, AudioToolbox            |
| `ffmpeg-X.Y.Z-darwin-universal.tar.gz`      | macOS universal (lipo)    | VideoToolbox, AudioToolbox            |
| `ffmpeg-X.Y.Z-windows-x64.zip`              | Windows 10+ x64           | D3D11VA, MediaFoundation, AMF, DXVA2  |

Releases: https://github.com/flumixa/ffmpeg/releases

## Build & test

```sh
$ git clone github.com/flumixa/ffmpeg
$ ./Build.sh {arg}
```

Args:

- default (ffmpeg-latest)
- rpi (ffmpeg-rpi-latest)
- cuda12 (ffmpeg-cuda12-latest)
- cuda13 (ffmpeg-cuda13-latest)
- vaapi (ffmpeg-vaapi-latest)
- macos (native build, run on macOS host with Homebrew)
- windows (native build, run inside MSYS2 MINGW64 shell)

### Releasing macOS / Windows binaries

Push a tag like `v8.0.1-flumixa-1` to trigger the release workflow,
which runs the macOS (arm64 + x86_64 + universal) and Windows (x64)
builds in parallel and publishes the artifacts to a GitHub Release.

```sh
$ git tag v8.0.1-flumixa-1
$ git push origin v8.0.1-flumixa-1
```

## Known problems:

The libraries are currently not compiled due to errors caused by Docker virtualization.

## Feature requests:

Please create an issue with your use case and all the requirements.

## Licence

LGPL-licensed with optional components licensed under GPL. Please refer to the LICENSE file for detailed information.
