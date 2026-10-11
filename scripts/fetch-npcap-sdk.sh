#!/usr/bin/env bash
# Download and verify the Npcap SDK, extracting it to the given directory.
# Usage: fetch-npcap-sdk.sh <dest-dir>
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
# shellcheck source=../versions.env
source "$ROOT/versions.env"

dest=${1:?usage: $0 <dest-dir>}
downloads="$ROOT/work/downloads"
zipfile="$downloads/npcap-sdk-${NPCAP_SDK_VERSION}.zip"

mkdir -p "$downloads"
if [[ ! -f "$zipfile" ]]; then
    echo "Downloading $NPCAP_SDK_URL"
    curl -sSfL -o "$zipfile.part" "$NPCAP_SDK_URL"
    mv "$zipfile.part" "$zipfile"
fi
echo "${NPCAP_SDK_SHA256} *${zipfile}" | sha256sum -c -

rm -rf "$dest"
mkdir -p "$dest"
unzip -q "$zipfile" -d "$dest"
test -f "$dest/Include/pcap.h"
test -f "$dest/Lib/x64/wpcap.lib"
echo "Npcap SDK ${NPCAP_SDK_VERSION} extracted to $dest"
