#!/usr/bin/env bash
# Build Suricata for Windows from the pinned release tarball and package it.
#
# Must run inside an MSYS2 UCRT64 shell with the packages from
# scripts/install-deps.sh installed. Output lands in dist/.
#
# Environment overrides:
#   NPCAP_SDK_DIR     use an existing SDK extraction instead of downloading
#   NPCAP_RUNTIME_DIR directory holding wpcap.dll/Packet.dll for running the
#                     built binary (test only; auto-fetched if Npcap is not
#                     installed)
#   JOBS            parallel make jobs (default: nproc)
#   CONFIGURE_EXTRA extra ./configure arguments
set -euo pipefail

ROOT=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=versions.env
source "$ROOT/versions.env"

if [[ ${MSYSTEM:-} != UCRT64 ]]; then
    echo "error: run this from an MSYS2 UCRT64 shell (MSYSTEM=${MSYSTEM:-unset})" >&2
    exit 1
fi

WORK="$ROOT/work"
DIST="$ROOT/dist"
DOWNLOADS="$WORK/downloads"
SRC="$WORK/src/suricata-${SURICATA_VERSION}"
PACKAGE_NAME="suricata-${SURICATA_VERSION}-${PACKAGE_RELEASE}-windows-x86_64"
JOBS=${JOBS:-$(nproc)}

mkdir -p "$DOWNLOADS" "$DIST"

# --- Source tarball ---------------------------------------------------------
tarball="$DOWNLOADS/suricata-${SURICATA_VERSION}.tar.gz"
if [[ ! -f "$tarball" ]]; then
    echo "Downloading $SURICATA_URL"
    curl -sSfL -o "$tarball.part" "$SURICATA_URL"
    mv "$tarball.part" "$tarball"
fi
echo "${SURICATA_SHA256} *${tarball}" | sha256sum -c -

rm -rf "$WORK/src"
mkdir -p "$WORK/src"
tar xzf "$tarball" -C "$WORK/src"
[[ -d "$SRC" ]] || { echo "error: expected $SRC after extraction" >&2; exit 1; }

# --- Patches ----------------------------------------------------------------
if compgen -G "$ROOT/patches/*.patch" >/dev/null; then
    for p in "$ROOT"/patches/*.patch; do
        echo "Applying $(basename "$p")"
        patch -p1 -d "$SRC" --no-backup-if-mismatch < "$p"
    done
fi

# --- Npcap SDK --------------------------------------------------------------
if [[ -z ${NPCAP_SDK_DIR:-} ]]; then
    NPCAP_SDK_DIR="$WORK/npcap-sdk"
    "$ROOT/scripts/fetch-npcap-sdk.sh" "$NPCAP_SDK_DIR"
fi
NPCAP_SDK_DIR=$(cd "$NPCAP_SDK_DIR" && pwd)

# --- Npcap runtime (test only) ---------------------------------------------
# suricata.exe links wpcap.dll directly, so it cannot even start on a machine
# without Npcap (e.g. the CI runner). For the post-build checks only, pull
# wpcap.dll/Packet.dll out of the Npcap installer. They are never packaged.
if [[ -z ${NPCAP_RUNTIME_DIR:-} ]] && [[ ! -f /c/Windows/System32/wpcap.dll ]]; then
    NPCAP_RUNTIME_DIR="$WORK/npcap-runtime"
    "$ROOT/scripts/fetch-npcap-runtime.sh" "$NPCAP_RUNTIME_DIR"
fi
if [[ -n ${NPCAP_RUNTIME_DIR:-} ]]; then
    NPCAP_RUNTIME_DIR=$(cd "$NPCAP_RUNTIME_DIR" && pwd)
    export NPCAP_RUNTIME_DIR
    export PATH="$NPCAP_RUNTIME_DIR:$PATH"
fi

# --- Configure and build ----------------------------------------------------
# Release tarballs ship vendored Rust crates, so cargo works offline.
# --disable-gccmarch-native keeps the binary portable across CPUs.
CONFIGURE_ARGS=(
    --prefix=/usr/local
    --disable-shared
    --disable-gccmarch-native
    --enable-gccprotect
    "--with-libpcap-includes=${NPCAP_SDK_DIR}/Include"
    "--with-libpcap-libraries=${NPCAP_SDK_DIR}/Lib/x64"
)
if [[ -n ${CONFIGURE_EXTRA:-} ]]; then
    # shellcheck disable=SC2206
    CONFIGURE_ARGS+=($CONFIGURE_EXTRA)
fi

cd "$SRC"
echo "Configuring: ./configure ${CONFIGURE_ARGS[*]}"
./configure "${CONFIGURE_ARGS[@]}"
make -j"$JOBS"

./src/suricata.exe -V
./src/suricata.exe --build-info | grep -iE 'npcap|pcap|rust|features' || true

# --- Package ----------------------------------------------------------------
export SURICATA_URL NPCAP_SDK_VERSION
export CONFIGURE_ARGS="${CONFIGURE_ARGS[*]}"
"$ROOT/scripts/package.sh" "$SRC" "$PACKAGE_NAME" "$DIST"
