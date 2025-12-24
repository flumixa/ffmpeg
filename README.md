# FFmpeg Base

FFmpeg base image for [flumixa](https://github.com/flumixa).

[![alpine](https://github.com/flumixa/ffmpeg/actions/workflows/build_base_alpine.yaml/badge.svg)](https://github.com/flumixa/ffmpeg/actions/workflows/build_base_alpine.yaml)
[![alpine-rpi](https://github.com/flumixa/ffmpeg/actions/workflows/build_base_alpine-rpi.yaml/badge.svg)](https://github.com/flumixa/ffmpeg/actions/workflows/build_base_alpine-rpi.yaml)
[![ubuntu-ffmpeg-vvapi](https://github.com/flumixa/ffmpeg/actions/workflows/build_base_ubuntu-vaapi.yaml/badge.svg)](https://github.com/flumixa/ffmpeg/actions/workflows/build_base_ubuntu-vaapi.yaml)
[![ubuntu-cuda](https://github.com/flumixa/ffmpeg/actions/workflows/build_base_ubuntu-cuda.yaml/badge.svg)](https://github.com/flumixa/ffmpeg/actions/workflows/build_base_ubuntu-cuda.yaml)

Branch: 8.0

## Config:

```sh
--enable-libv4l2
--enable-libfreetype
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

| Dockerimage                                          | OS            | Plattform                                | GPU                                         |
|------------------------------------------------------|---------------|------------------------------------------|---------------------------------------------|
| docker.io/sharapov/flumixa-base:ffmpeg-latest        | Alpine 3.23.2 | linux/amd64, linux/arm64, linux/arm/v7   | -                                           |
| docker.io/sharapov/flumixa-base:ffmpeg-rpi-latest    | Alpine 3.23.2 | Raspberry Pi (linux/arm/v7, linux/arm64) | MMAL/OMX/V4L2-M2M (32bit), V4L2-M2M (64bit) |
| docker.io/sharapov/flumixa-base:ffmpeg-cuda12-latest | Ubuntu 24.04  | linux/amd64                              | Nvidia Cuda                                 |
| docker.io/sharapov/flumixa-base:ffmpeg-cuda13-latest | Ubuntu 24.04  | linux/amd64                              | Nvidia Cuda                                 |
| docker.io/sharapov/flumixa-base:ffmpeg-vaapi-latest  | Ubuntu 24.04  | linux/amd64                              | Intel VAAPI                                 |

More tags: https://hub.docker.com/repository/docker/sharapov/flumixa-base/general

## Build & test

```sh
$ git clone github.com/flumixa/ffmpeg
$ ./Build.sh {arg}
```

Args:

- default (alpine-ffmpeg-latest)
- rpi (alpine-ffmpeg-rpi-latest)
- cuda (ubuntu-ffmpeg-cuda-latest)
- vaapi (ubuntu-ffmpeg-vaapi-latest)

## Known problems:

The libraries are currently not compiled due to errors caused by Docker virtualization.

## Feature requests:

Please create an issue with your use case and all the requirements.

## Licence

LGPL-licensed with optional components licensed under GPL. Please refer to the LICENSE file for detailed information.
