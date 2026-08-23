#!/usr/bin/env bash
# Build a CachyOS live ISO that boots and installs linux-cachyos-mb81.
# Work tree is under $HOME (ext4), not the NTFS git checkout.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ISO_SRC="${ISO_SRC:-$HOME/src/CachyOS-Live-ISO}"
REPO_HOST="${REPO_HOST:-$HOME/src/mb81-iso-repo}"
OUT="${OUT:-$HOME/src/mb81-iso-out}"

if [[ ! -d "$ISO_SRC/.git" ]]; then
    git clone --depth 1 https://github.com/CachyOS/CachyOS-Live-ISO.git "$ISO_SRC"
fi
git -C "$ISO_SRC" fetch origin
git -C "$ISO_SRC" checkout -f origin/master
git -C "$ISO_SRC" clean -fdx -e out -e build

bash "$ROOT/scripts/apply-iso-overlay.sh" "$ISO_SRC" "$REPO_HOST"

mkdir -p "$OUT"
# buildiso writes to $ISO_SRC/out
cd "$ISO_SRC"
# disk build (no -r). -w removes work dir after success.
sudo ./buildiso.sh -p desktop -v -w

mkdir -p "$OUT" "$ROOT/dist"
shopt -s nullglob
isos=("$ISO_SRC"/out/*.iso)
if (( ${#isos[@]} == 0 )); then
    echo "no ISO produced in $ISO_SRC/out" >&2
    exit 1
fi
cp -v "${isos[@]}" "$OUT/"
cp -v "${isos[@]}" "$ROOT/dist/"
ls -lh "${isos[@]}"
echo "ISO ready. Flash with: sudo dd if=${isos[0]} of=/dev/sdX bs=4M status=progress conv=fsync"
