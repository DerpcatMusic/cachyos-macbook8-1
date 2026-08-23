#!/usr/bin/env bash
# Usage: scripts/build.sh
# Build linux-cachyos-mb81 with makepkg. Sources/build/packages live under
# /home/derpcat — never in this NTFS git tree. Typical runtime: 1-3 hours.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PKGDIR="$REPO/kernel/linux-cachyos-mb81"

SRCDEST=/home/derpcat/src/mb81-cache
BUILDDIR=/home/derpcat/build/mb81
PKGDEST=/home/derpcat/src/mb81-pkgs

inside_repo() {
    local p="$1"
    [[ "$p" == "$REPO" || "$p" == "$REPO"/* ]]
}

if inside_repo "$SRCDEST" || inside_repo "$BUILDDIR" || inside_repo "$PKGDEST"; then
    echo "error: SRCDEST/BUILDDIR/PKGDEST must not be inside the git repo (NTFS)" >&2
    exit 1
fi

if [[ ! -f "$PKGDIR/PKGBUILD" ]]; then
    echo "error: missing $PKGDIR/PKGBUILD" >&2
    exit 1
fi

command -v makepkg >/dev/null 2>&1 || {
    echo "error: makepkg not found" >&2
    exit 1
}

export SRCDEST BUILDDIR PKGDEST
mkdir -p "$SRCDEST" "$BUILDDIR" "$PKGDEST" "$REPO/dist"

echo "Building linux-cachyos-mb81 (1-3 hours typical; nice -n 10)..."
echo "SRCDEST=$SRCDEST"
echo "BUILDDIR=$BUILDDIR"
echo "PKGDEST=$PKGDEST"

cd "$PKGDIR"
# Import CachyOS kernel signing keys when present; still skip if offline.
gpg --list-keys E8B9AA39F054E30E8290D492C3C4820857F654FE >/dev/null 2>&1 || \
  gpg --keyserver keys.openpgp.org --recv-keys \
    E18447AC260021D31F3FF6C4C8A2A4774B8B63C4 \
    E8B9AA39F054E30E8290D492C3C4820857F654FE || true
nice -n 10 makepkg -sf --noconfirm --skippgpcheck

shopt -s nullglob
pkgs=("$PKGDEST"/linux-cachyos-mb81-*.pkg.tar.zst)
if (( ${#pkgs[@]} == 0 )); then
    echo "error: makepkg succeeded but no packages in $PKGDEST" >&2
    exit 1
fi

cp -v "${pkgs[@]}" "$REPO/dist/"

echo
echo "Built packages:"
printf '  %s\n' "${pkgs[@]}"
echo "Copied to $REPO/dist/"
echo "Not installed."
