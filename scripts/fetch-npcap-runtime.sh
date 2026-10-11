#!/usr/bin/env bash
# Extract wpcap.dll and Packet.dll from the Npcap installer into the given
# directory so the built suricata.exe can be executed on a machine without
# Npcap installed (CI smoke tests). These files are for testing only and
# must never end up in the package.
# Usage: fetch-npcap-runtime.sh <dest-dir>
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
# shellcheck source=../versions.env
source "$ROOT/versions.env"

dest=${1:?usage: $0 <dest-dir>}
downloads="$ROOT/work/downloads"
exe="$downloads/npcap-${NPCAP_RUNTIME_VERSION}.exe"

mkdir -p "$downloads"
if [[ ! -f "$exe" ]]; then
    echo "Downloading $NPCAP_RUNTIME_URL"
    curl -sSfL -o "$exe.part" "$NPCAP_RUNTIME_URL"
    mv "$exe.part" "$exe"
fi
echo "${NPCAP_RUNTIME_SHA256} *${exe}" | sha256sum -c -

tmp="$ROOT/work/npcap-runtime-extract"
rm -rf "$tmp" "$dest"
mkdir -p "$dest"
7z -y x -o"$tmp" "$exe" >/dev/null
cp "$tmp/wpcap.dll" "$tmp/Packet.dll" "$dest/"
rm -rf "$tmp"
echo "Npcap ${NPCAP_RUNTIME_VERSION} runtime DLLs (test only) extracted to $dest"
