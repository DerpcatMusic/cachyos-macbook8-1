#!/usr/bin/env bash
# Build linux-cachyos-mb81. Never run this inside the NTFS git checkout.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PKGDIR="$ROOT/kernel/linux-cachyos-mb81"
SRCDEST="${SRCDEST:-$HOME/src/mb81-cache}"
BUILDDIR="${BUILDDIR:-$HOME/build/mb81}"
PKGDEST="${PKGDEST:-$HOME/src/mb81-pkgs}"
DIST="$ROOT/dist"

mkdir -p "$SRCDEST" "$BUILDDIR" "$PKGDEST" "$DIST"

if [[ ! -f "$PKGDIR/PKGBUILD" ]]; then
  echo "missing $PKGDIR/PKGBUILD" >&2
  exit 1
fi
if [[ ! -f "$PKGDIR/0001-spi-pxa2xx-pci-disable-dma-macbook8-1.patch" ]]; then
  echo "missing PIO patch" >&2
  exit 1
fi

# Pre-seed the CachyOS tarball if we already fetched it under the pin name
pin="$ROOT/kernel/upstream.pin"
# shellcheck disable=SC1090
source "$pin"
if [[ -f "$SRCDEST/${CACHYOS_SRC}.tar.gz" ]]; then
  echo "using cached $SRCDEST/${CACHYOS_SRC}.tar.gz"
fi

export SRCDEST BUILDDIR PKGDEST
echo "SRCDEST=$SRCDEST"
echo "BUILDDIR=$BUILDDIR"
echo "PKGDEST=$PKGDEST"

cd "$PKGDIR"
# NTFS checkouts often lack exec bits; makepkg only needs to read PKGBUILD
nice -n 10 makepkg -sf --noconfirm --skippgpcheck

shopt -s nullglob
pkgs=("$PKGDEST"/linux-cachyos-mb81-*.pkg.tar.zst)
if (( ${#pkgs[@]} == 0 )); then
  echo "makepkg finished but no packages in $PKGDEST" >&2
  exit 1
fi
cp -v "${pkgs[@]}" "$DIST/"
echo "packages:"
ls -lh "$DIST"/linux-cachyos-mb81-*.pkg.tar.zst
