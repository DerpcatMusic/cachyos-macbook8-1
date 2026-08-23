#!/usr/bin/env bash
# Run on the MacBook as root after copying packages into the current directory.
set -euo pipefail
if [[ ${EUID} -ne 0 ]]; then
  echo "run as root" >&2
  exit 1
fi
shopt -s nullglob
pkgs=(linux-cachyos-mb81-[0-9]*.pkg.tar.zst linux-cachyos-mb81-headers-*.pkg.tar.zst)
if (( ${#pkgs[@]} < 2 )); then
  echo "place linux-cachyos-mb81 and -headers packages in $(pwd)" >&2
  exit 1
fi
pacman -U --noconfirm "${pkgs[@]}"
echo ">>> keep official linux-cachyos installed as USB-keyboard rescue"
install -Dm644 /dev/stdin /etc/mkinitcpio.conf.d/mb81-spi.conf <<'EOF'
MODULES+=(spi_pxa2xx_pci spi_pxa2xx_platform spi_pxa2xx_core applespi)
EOF
mkinitcpio -P
if [[ -f /etc/default/limine ]]; then
  echo ">>> Limine: pick linux-cachyos-mb81 as the default entry"
  echo ">>> optional cmdline until S3 is proven: mem_sleep_default=s2idle"
fi
echo ">>> reboot, then: dmesg | grep -Ei 'forcing SPI PIO|applespi|timeout|-110'"
