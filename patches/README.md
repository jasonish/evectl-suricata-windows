# Patches

Any `*.patch` files in this directory are applied to the extracted
Suricata source tree, in lexical order, with `patch -p1` before
`configure` runs. Name them with a numeric prefix so the order is
explicit, e.g. `0001-fix-something.patch`.

Generate them from a Suricata git checkout with
`git format-patch -1 <commit>` or `git diff > NNNN-name.patch`.

After adding, removing, or changing a patch, bump `PACKAGE_RELEASE` in
`versions.env` so the next release gets a new tag.
