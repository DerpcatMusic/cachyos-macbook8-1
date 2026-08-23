#!/usr/bin/env bash
# Usage: scripts/install-on-macbook.sh [package-dir]
# Install linux-cachyos-mb81 + headers on the MacBook, drop in the
# mkinitcpio SPI modules file, and regenerate initramfs. Must run as root.
# Keep official linux-cachyos installed as a fallback.

set -euo pipefail

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    echo "Usage: scripts/install-on-macbook.sh [package-dir]"
    exit 0
fi

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    echo "error: must run as root" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKGDIR="${1:-.}"

shopt -s nullglob
kernel=("$PKGDIR"/linux-cachyos-mb81-[0-9]*.pkg.tar.zst)
headers=("$PKGDIR"/linux-cachyos-mb81-headers-*.pkg.tar.zst)

if (( ${#kernel[@]} == 0 || ${#headers[@]} == 0 )); then
    echo "error: need linux-cachyos-mb81-*.pkg.tar.zst and linux-cachyos-mb81-headers-*.pkg.tar.zst in $PKGDIR" >&2
    exit 1
fi

echo "WARNING: Keep official linux-cachyos installed as a fallback boot entry."
echo "Installing:"
printf '  %s\n' "${kernel[@]}" "${headers[@]}"

pacman -U "${kernel[@]}" "${headers[@]}"

dropin_src="$SCRIPT_DIR/../packaging/mb81-spi.conf"
dropin_dst=/etc/mkinitcpio.conf.d/mb81-spi.conf
mkdir -p /etc/mkinitcpio.conf.d
if [[ -f "$dropin_src" ]]; then
    install -Dm644 "$dropin_src" "$dropin_dst"
else
    cat > "$dropin_dst" <<'EOF'
MODULES=(spi_pxa2xx_pci spi_pxa2xx_platform spi_pxa2xx_core applespi)
EOF
fi
echo "Wrote $dropin_dst (built-in modules listed as a harmless backup)"

mkinitcpio -P

if [[ -f /etc/default/limine ]]; then
    echo
    echo "Limine detected (/etc/default/limine)."
    echo "Set the default boot entry to linux-cachyos-mb81; this script will not rewrite it."
    echo "# suggested cmdline addition (not applied): mem_sleep_default=s2idle"
fi
