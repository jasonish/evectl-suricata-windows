#!/usr/bin/env bash
# Install the MSYS2 packages needed to build and package Suricata.
# Run from an MSYS2 UCRT64 shell (or the msys2 shell in CI).
set -euo pipefail

pacman -S --needed --noconfirm \
    autoconf \
    automake \
    git \
    make \
    p7zip \
    patch \
    unzip \
    zip \
    mingw-w64-ucrt-x86_64-cbindgen \
    mingw-w64-ucrt-x86_64-file \
    mingw-w64-ucrt-x86_64-jansson \
    mingw-w64-ucrt-x86_64-libpcap \
    mingw-w64-ucrt-x86_64-libtool \
    mingw-w64-ucrt-x86_64-libyaml \
    mingw-w64-ucrt-x86_64-pcre2 \
    mingw-w64-ucrt-x86_64-pkgconf \
    mingw-w64-ucrt-x86_64-rust \
    mingw-w64-ucrt-x86_64-toolchain
