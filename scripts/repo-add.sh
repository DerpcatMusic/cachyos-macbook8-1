#!/usr/bin/env bash
# Usage: scripts/repo-add.sh
# Create a local pacman repo at /home/derpcat/src/mb81-repo from packages
# in PKGDEST (/home/derpcat/src/mb81-pkgs) or $REPO/dist/.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PKGDEST="${PKGDEST:-/home/derpcat/src/mb81-pkgs}"
REPODIR=/home/derpcat/src/mb81-repo

command -v repo-add >/dev/null 2>&1 || {
    echo "error: repo-add not found (install pacman-contrib)" >&2
    exit 1
}

shopt -s nullglob
pkgs=("$PKGDEST"/linux-cachyos-mb81-*.pkg.tar.zst)
if (( ${#pkgs[@]} == 0 )); then
    pkgs=("$REPO"/dist/linux-cachyos-mb81-*.pkg.tar.zst)
fi
if (( ${#pkgs[@]} == 0 )); then
    echo "error: no linux-cachyos-mb81 packages in $PKGDEST or $REPO/dist" >&2
    exit 1
fi

mkdir -p "$REPODIR"

copied=()
for p in "${pkgs[@]}"; do
    dest="$REPODIR/$(basename "$p")"
    cp -v "$p" "$dest"
    copied+=("$dest")
done

cd "$REPODIR"
repo-add mb81.db.tar.zst "${copied[@]##*/}"

echo
echo "Local repo ready at $REPODIR"
echo "Add to /etc/pacman.conf:"
echo
cat <<'EOF'
[mb81]
SigLevel = Optional TrustAll
Server = file:///home/derpcat/src/mb81-repo
EOF
