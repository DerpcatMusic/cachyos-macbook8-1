#!/usr/bin/env bash
# Exit 0: current. Exit 1: CachyOS kernel moved. Exit 2: mainline has the quirk (drop patch).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/kernel/upstream.pin"

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

curl -fsSL "$MAINLINE_SPI_PCI" -o "$tmp"
if grep -q 'MacBook8,1' "$tmp"; then
  echo "DROP PATCH — mainline spi-pxa2xx-pci.c already mentions MacBook8,1"
  exit 2
fi
echo "mainline: no MacBook8,1 quirk yet"

up=$(mktemp)
trap 'rm -f "$tmp" "$up"' EXIT
curl -fsSL "$CACHYOS_PKGBUILD_URL" -o "$up"
major=$(grep -E '^_major=' "$up" | head -1 | cut -d= -f2)
minor=$(grep -E '^_minor=' "$up" | head -1 | cut -d= -f2)
rel=$(grep -E '^pkgrel=' "$up" | head -1 | cut -d= -f2)
ver="${major}.${minor}-${rel}"
echo "pinned:  $CACHYOS_KERNEL_VER"
echo "cachyos: $ver"
if [[ "$ver" != "$CACHYOS_KERNEL_VER" ]]; then
  echo "REBASE NEEDED: run scripts/sync-from-cachy.sh"
  exit 1
fi
echo "in sync with CachyOS $ver"
