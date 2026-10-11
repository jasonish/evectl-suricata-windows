#!/usr/bin/env bash
# Stage a built Suricata tree into a self-contained directory and produce
# a .zip archive plus SHA256SUMS.
#
# Usage: package.sh <suricata-src-dir> <package-name> <dist-dir>
#
# The Npcap runtime (wpcap.dll, Packet.dll) is deliberately NOT included;
# Npcap must be installed separately on the target machine.
set -euo pipefail

src=${1:?usage: $0 <suricata-src-dir> <package-name> <dist-dir>}
name=${2:?usage: $0 <suricata-src-dir> <package-name> <dist-dir>}
dist=${3:?usage: $0 <suricata-src-dir> <package-name> <dist-dir>}

ROOT=$(cd "$(dirname "$0")/.." && pwd)
src=$(cd "$src" && pwd)
exe="$src/src/suricata.exe"
[[ -f "$exe" ]] || { echo "error: $exe not found (build first)" >&2; exit 1; }
command -v ldd >/dev/null || { echo "error: ldd is required" >&2; exit 1; }

mkdir -p "$dist"
dist=$(cd "$dist" && pwd)
stage="$ROOT/work/stage"
pkg="$stage/$name"
rm -rf "$stage"
mkdir -p "$pkg" "$dist"

# Runtime DLLs that must never be redistributed, or come from Windows.
is_excluded() {
    local lower=${1,,}
    case "$lower" in
        wpcap.dll|packet.dll) return 0 ;;
        api-ms-win-*|ext-ms-*) return 0 ;;
    esac
    return 1
}

is_windows_path() {
    local lower=${1,,}
    [[ $lower == /c/windows/* || $lower == c:\windows\* ]]
}

# Walk the dependency graph of the executable with ldd and collect every
# non-system DLL. ldd resolves against PATH, so make sure the UCRT64 bin
# directory is first.
export PATH="/ucrt64/bin:$PATH"
declare -A dlls=()
declare -A seen=()
queue=("$exe")
i=0
while (( i < ${#queue[@]} )); do
    file=${queue[$i]}; i=$((i + 1))
    [[ -n ${seen[$file]+x} ]] && continue
    seen[$file]=1
    while IFS= read -r line; do
        [[ $line == *"=>"* ]] || continue
        dllname=$(printf '%s' "${line%%=>*}" | xargs)
        target=${line#*=> }
        target=${target%% (*}
        target=$(printf '%s' "$target" | xargs)
        is_excluded "$dllname" && continue
        if [[ $target == "not found" ]]; then
            echo "error: $dllname needed by $(basename "$file") not found" >&2
            exit 1
        fi
        [[ $target == [A-Za-z]:\* ]] && target=$(cygpath -u "$target")
        is_windows_path "$target" && continue
        lower=${dllname,,}
        if [[ -z ${dlls[$lower]+x} ]]; then
            dlls[$lower]=$target
            queue+=("$target")
        fi
    done < <(ldd "$file")
done

cp "$exe" "$pkg/"
strip -s "$pkg/suricata.exe"
for lower in "${!dlls[@]}"; do
    cp "${dlls[$lower]}" "$pkg/"
done

# Belt and braces: the Npcap runtime must never be redistributed.
for forbidden in wpcap.dll Packet.dll; do
    if [[ -e "$pkg/$forbidden" ]]; then
        echo "error: $forbidden must not be packaged" >&2
        exit 1
    fi
done

cp "$src/suricata.yaml" "$pkg/"
cp "$src/etc/classification.config" "$src/etc/reference.config" "$pkg/"
cp "$src/threshold.config" "$pkg/"
cp "$src/COPYING" "$pkg/LICENSE"
mkdir -p "$pkg/rules"
cp "$src"/rules/*.rules "$pkg/rules/"

# Sanity check: the staged tree must run on its own, with only the DLLs
# we shipped (the Windows directory is implicitly on the search path).
# Logs go to a scratch dir so the staged tree stays clean.
smoke_log="$ROOT/work/smoke-log"
rm -rf "$smoke_log"
mkdir -p "$smoke_log"
# Suricata reads the CPU count from this Windows variable; some MSYS2
# login shells drop it.
export NUMBER_OF_PROCESSORS=${NUMBER_OF_PROCESSORS:-$(nproc)}
# The Npcap runtime dir (if any) is test-only: see fetch-npcap-runtime.sh.
smoke_path="${NPCAP_RUNTIME_DIR:+$NPCAP_RUNTIME_DIR:}/c/Windows/System32:/c/Windows"
(
    cd "$pkg"
    PATH="$smoke_path" ./suricata.exe -V
    PATH="$smoke_path" ./suricata.exe -c suricata.yaml -T \
        -l "$smoke_log" \
        -S rules/app-layer-events.rules \
        --set classification-file=./classification.config \
        --set reference-config-file=./reference.config \
        --set threshold-file=./threshold.config
)

{
    echo "Package:  $name"
    echo "Built:    $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "Source:   ${SURICATA_URL:-unknown}"
    echo "Npcap SDK: ${NPCAP_SDK_VERSION:-unknown} (link-time only, runtime not included)"
    echo "Patches:"
    if compgen -G "$ROOT/patches/*.patch" >/dev/null; then
        for p in "$ROOT"/patches/*.patch; do echo "  $(basename "$p")"; done
    else
        echo "  (none)"
    fi
    echo "Configure: ${CONFIGURE_ARGS:-unknown}"
    echo
    "$pkg/suricata.exe" --build-info
} > "$pkg/BUILD-INFO.txt"

rm -f "$dist/$name.zip"
(cd "$stage" && zip -q -r -9 "$dist/$name.zip" "$name")
(cd "$dist" && sha256sum "$name.zip" > SHA256SUMS)

echo
echo "Packaged files:"
(cd "$pkg" && find . -type f | sort | sed 's/^/  /')
echo
echo "Artifacts:"
cat "$dist/SHA256SUMS" | sed 's/^/  /'
