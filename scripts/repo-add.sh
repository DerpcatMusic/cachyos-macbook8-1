#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO="${REPO:-$HOME/src/mb81-repo}"
PKGDEST="${PKGDEST:-$HOME/src/mb81-pkgs}"
mkdir -p "$REPO"
shopt -s nullglob
pkgs=("$PKGDEST"/linux-cachyos-mb81-*.pkg.tar.zst "$ROOT"/dist/linux-cachyos-mb81-*.pkg.tar.zst)
if (( ${#pkgs[@]} == 0 )); then
  echo "no packages in $PKGDEST or $ROOT/dist" >&2
  exit 1
fi
cp -v "${pkgs[@]}" "$REPO/"
cd "$REPO"
repo-add -n mb81.db.tar.zst linux-cachyos-mb81-*.pkg.tar.zst
cat <<EOF

Add to /etc/pacman.conf:

[mb81]
SigLevel = Optional TrustAll
Server = file://${REPO}

Then: sudo pacman -Sy linux-cachyos-mb81 linux-cachyos-mb81-headers
EOF
