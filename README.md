# evectl-suricata-windows

Builds [Suricata](https://suricata.io) for Windows (x86_64) from the
official release tarball and publishes it as a plain `.zip` / `.tar.gz`
package, so [evectl](https://github.com/jasonish/evectl) can unpack it
directly instead of running the MSI installer. It also gives us a place
to carry custom patches.

Only the `main-8.0.x` release series is tracked.

## What's in the package

```
suricata-<ver>-<rel>-windows-x86_64/
  suricata.exe           stripped, built with MSYS2 UCRT64 / GCC
  *.dll                  MinGW runtime deps (jansson, yaml, pcre2, ...)
  suricata.yaml          the configure-generated default config
  classification.config
  reference.config
  threshold.config
  rules/*.rules          the engine event rules shipped with Suricata
  LICENSE                GPLv2
  BUILD-INFO.txt         versions, patches, configure flags, --build-info
```

The binary is linked against the **Npcap SDK** for live capture, but the
Npcap runtime (`wpcap.dll`, `Packet.dll`, driver) is **never** included.
Npcap's free license does not permit redistribution. Install Npcap
separately on the target machine.

`suricata.yaml` contains the same `C:\Program Files\Suricata\...` default
paths as the upstream MSI (that's what `configure` generates on MinGW),
so anything that already rewrites or overrides those paths keeps working.

## Versions and releases

Everything is pinned in [`versions.env`](versions.env):

- `SURICATA_VERSION` / `SURICATA_SHA256`: the upstream release tarball.
- `PACKAGE_RELEASE`: bumped when the same Suricata version is re-packaged
  (new patch, dependency refresh, packaging fix). Reset to `1` on a new
  Suricata version.
- `NPCAP_SDK_VERSION` / `NPCAP_SDK_SHA256`.

A release is produced by pushing a tag named
`v${SURICATA_VERSION}-${PACKAGE_RELEASE}`, e.g. `v8.0.7-1`. CI refuses to
build a tag that does not match `versions.env`. The release carries:

- `suricata-<ver>-<rel>-windows-x86_64.zip`
- `suricata-<ver>-<rel>-windows-x86_64.tar.gz`
- `SHA256SUMS`

### Cutting a new release

1. Edit `versions.env` (new version + checksum, or bump `PACKAGE_RELEASE`).
2. Commit and push to `main`; wait for CI to go green.
3. Tag and push: `git tag v8.0.7-1 && git push origin v8.0.7-1`.

To get the checksum of a new tarball:

```
curl -sSfLO https://www.openinfosecfoundation.org/download/suricata-8.0.8.tar.gz
sha256sum suricata-8.0.8.tar.gz
```

## Patches

Drop `*.patch` files into [`patches/`](patches/). They are applied with
`patch -p1` in lexical order before `configure`. See `patches/README.md`.

## Building locally

From an MSYS2 **UCRT64** shell:

```
./scripts/install-deps.sh   # once
./build.sh
```

Output lands in `dist/`. Intermediate files (downloads, source tree,
Npcap SDK, staging) live in `work/`; both are git-ignored.

Useful environment variables for `build.sh`:

- `NPCAP_SDK_DIR`: reuse an existing SDK extraction (e.g. `/c/npcap`).
- `JOBS`: parallel make jobs (default `nproc`).
- `CONFIGURE_EXTRA`: extra `./configure` arguments.

## Layout

```
build.sh                    download, verify, patch, configure, make, package
versions.env                pinned versions and checksums
patches/                    *.patch applied before configure
scripts/install-deps.sh     pacman packages for UCRT64
scripts/fetch-npcap-sdk.sh  download + verify + extract the Npcap SDK
scripts/package.sh          stage exe + DLLs (via ldd) + configs, make archives
.github/workflows/build.yml CI build on every push; release on v* tags
```
