#!/usr/bin/env bash
# Patch a CachyOS-Live-ISO tree so the live+installed default kernel is linux-cachyos-mb81.
set -euo pipefail
ISO="${1:?usage: apply-iso-overlay.sh /path/to/CachyOS-Live-ISO}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_HOST="${2:-$HOME/src/mb81-iso-repo}"

test -d "$ISO/archiso"
mkdir -p "$REPO_HOST" "$ISO/archiso/airootfs/opt/mb81-repo"

# --- local package repo (build host + live airootfs) ---
shopt -s nullglob
pkgs=("$HOME"/src/mb81-pkgs/linux-cachyos-mb81-*.pkg.tar.zst)
if (( ${#pkgs[@]} == 0 )); then
    pkgs=("$ROOT"/dist/linux-cachyos-mb81-*.pkg.tar.zst)
fi
if (( ${#pkgs[@]} == 0 )); then
    echo "no linux-cachyos-mb81 packages in $HOME/src/mb81-pkgs or $ROOT/dist" >&2
    exit 1
fi
cp -f "${pkgs[@]}" "$REPO_HOST/"
cp -f "${pkgs[@]}" "$ISO/archiso/airootfs/opt/mb81-repo/"
(
    cd "$REPO_HOST"
    rm -f mb81.db* mb81.files*
    repo-add mb81.db.tar.zst linux-cachyos-mb81-*.pkg.tar.zst
)
cp -f "$REPO_HOST"/mb81.db* "$REPO_HOST"/mb81.files* "$ISO/archiso/airootfs/opt/mb81-repo/" 2>/dev/null || true
# repo-add also writes the db into the airootfs copy
(
    cd "$ISO/archiso/airootfs/opt/mb81-repo"
    rm -f mb81.db* mb81.files*
    repo-add mb81.db.tar.zst linux-cachyos-mb81-*.pkg.tar.zst
)

inject_repo() {
    local f="$1" server="$2"
    if grep -q '^\[mb81\]' "$f"; then
        return 0
    fi
    python3 - "$f" "$server" << 'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
server = sys.argv[2]
block = f"""
[mb81]
SigLevel = Optional TrustAll
Server = {server}
"""
t = p.read_text()
# insert before first repo header
idx = t.find("\n[cachyos]")
if idx < 0:
    idx = t.find("\n[core]")
if idx < 0:
    raise SystemExit(f"no repo header in {p}")
p.write_text(t[:idx] + "\n" + block + t[idx:])
PY
}

inject_repo "$ISO/archiso/pacman.conf" "file://${REPO_HOST}"
inject_repo "$ISO/archiso/airootfs/etc/pacman.conf" "file:///opt/mb81-repo"
if [[ -f "$ISO/archiso/airootfs/etc/pacman-more.conf" ]]; then
    inject_repo "$ISO/archiso/airootfs/etc/pacman-more.conf" "file:///opt/mb81-repo" || true
fi

# --- live package list ---
pkglist="$ISO/archiso/packages_desktop.x86_64"
python3 - "$pkglist" << 'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
lines = p.read_text().splitlines(True)
drop = {
    "linux-cachyos",
    "linux-cachyos-headers",
    "linux-cachyos-nvidia-open",
    "linux-cachyos-zfs",
    "linux-cachyos-lts-zfs",
    "linux-cachyos-lts-nvidia-open",
}
out = []
inserted = False
for line in lines:
    name = line.strip()
    if name in drop:
        if not inserted:
            out.append("linux-cachyos-mb81\n")
            inserted = True
        continue
    if name == "linux-cachyos-lts" and not inserted:
        out.append("linux-cachyos-mb81\n")
        inserted = True
    out.append(line)
if not inserted:
    out.append("linux-cachyos-mb81\n")
p.write_text("".join(out))
print("packages_desktop.x86_64 now has:")
for l in p.read_text().splitlines():
    if "linux" in l:
        print(" ", l)
PY

# --- bootloader: live default is mb81, leave -lts entries alone ---
python3 - "$ISO" << 'PY'
from pathlib import Path
import sys
iso = Path(sys.argv[1])
files = [
    iso / "archiso/grub/grub.cfg",
    iso / "archiso/grub/loopback.cfg",
    iso / "archiso/efiboot/loader/entries/02-archiso-linux-cachyos.conf",
]
for f in files:
    if not f.exists():
        continue
    t = f.read_text()
    t = t.replace("vmlinuz-linux-cachyos-lts", "VMLINUZ_LTS")
    t = t.replace("initramfs-linux-cachyos-lts.img", "INITRD_LTS")
    t = t.replace("vmlinuz-linux-cachyos", "vmlinuz-linux-cachyos-mb81")
    t = t.replace("initramfs-linux-cachyos.img", "initramfs-linux-cachyos-mb81.img")
    t = t.replace("VMLINUZ_LTS", "vmlinuz-linux-cachyos-lts")
    t = t.replace("INITRD_LTS", "initramfs-linux-cachyos-lts.img")
    f.write_text(t)
    print("boot:", f)
PY

# Title the default GRUB entry
sed -i 's/menuentry "CachyOS"/menuentry "CachyOS MacBook8,1"/' "$ISO/archiso/grub/grub.cfg" || true

# ISO identity
sed -i \
    -e 's/^iso_name=.*/iso_name="cachyos-macbook81"/' \
    -e 's/^iso_label=.*/iso_label="COS_MB81"/' \
    -e 's|^iso_application=.*|iso_application="CachyOS MacBook8,1 Live"|' \
    "$ISO/archiso/profiledef.sh"

# Calamares launcher
install -Dm755 "$ROOT/iso/calamares-online.sh" \
    "$ISO/archiso/airootfs/usr/local/bin/calamares-online.sh"

echo "overlay applied to $ISO"
echo "build-host repo: $REPO_HOST"
echo "live repo: /opt/mb81-repo"
