#!/usr/bin/env bash
# Pull latest CachyOS linux-cachyos PKGBUILD+config and re-apply the mb81 overlay.
# Does not commit.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIR="$ROOT/kernel/linux-cachyos-mb81"
# shellcheck disable=SC1091
source "$ROOT/kernel/upstream.pin"

curl -fsSL "$CACHYOS_PKGBUILD_URL" -o "$DIR/PKGBUILD.upstream"
curl -fsSL "$CACHYOS_CONFIG_URL" -o "$DIR/config"
cp "$DIR/PKGBUILD.upstream" "$DIR/PKGBUILD"

python3 - "$DIR/PKGBUILD" << 'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
t = p.read_text()

def must(old, new, label):
    global t
    if old not in t:
        raise SystemExit(f"overlay failed: {label}")
    t = t.replace(old, new, 1)

must(': "${_processor_opt:=}"', ': "${_processor_opt:=GENERIC_V3}"', "processor_opt")
must(
'''else
    _pkgsuffix=cachyos
fi

pkgbase="linux-$_pkgsuffix"
''',
'''else
    _pkgsuffix=cachyos
fi

# MacBook8,1: never collide with official linux-cachyos
_pkgsuffix=cachyos-mb81
pkgbase="linux-$_pkgsuffix"
''',
    "pkgsuffix",
)
must(
    "pkgdesc='Linux EEVDF + LTO + AutoFDO + Propeller Cachy Sauce Kernel by CachyOS with other patches and improvements.'",
    "pkgdesc='CachyOS kernel for MacBook8,1 with SPI PIO quirk (keyboard/trackpad)'",
    "pkgdesc",
)
must(
    'url="https://github.com/CachyOS/linux-cachyos"',
    'url="https://github.com/DerpcatMusic/cachyos-macbook8-1"',
    "url",
)
must(
'''source=(
    "https://github.com/CachyOS/linux/releases/download/${_srcname}/${_srcname}.tar.gz"{,.asc}
    "config"
)
''',
'''source=(
    "https://github.com/CachyOS/linux/releases/download/${_srcname}/${_srcname}.tar.gz"{,.asc}
    "config"
    "0001-spi-pxa2xx-pci-disable-dma-macbook8-1.patch"
)
''',
    "source",
)
must("export KBUILD_BUILD_HOST=cachyos", "export KBUILD_BUILD_HOST=macbook81", "build host")
must(
'''    echo "Setting config..."
    cp ../config .config
''',
'''    echo "Setting config..."
    cp ../config .config

    echo "MacBook8,1: built-in SPI keyboard/trackpad (LUKS-safe)..."
    scripts/config -e SPI -e SPI_MASTER \\
        -e SPI_PXA2XX -e SPI_PXA2XX_PCI \\
        -e KEYBOARD_APPLESPI
''',
    "kconfig",
)
t = t.replace(
'''    provides=(VIRTUALBOX-GUEST-MODULES WIREGUARD-MODULE KSMBD-MODULE V4L2LOOPBACK-MODULE NTSYNC-MODULE VHBA-MODULE ADIOS-MODULE)
    # Replace LTO kernel with the default kernel
    if _is_lto_kernel; then
        provides+=(linux-cachyos-lto=$_kernver)
        replaces=(linux-cachyos-lto)
    fi
''',
'''    provides=(VIRTUALBOX-GUEST-MODULES WIREGUARD-MODULE KSMBD-MODULE V4L2LOOPBACK-MODULE NTSYNC-MODULE VHBA-MODULE ADIOS-MODULE)
    # Do not replaces= official linux-cachyos / linux-cachyos-lto
'''
)
t = t.replace(
'''    provides=(LINUX-HEADERS)

    if _is_lto_kernel; then
        provides+=(linux-cachyos-lto-headers=$_kernver)
        replaces=(linux-cachyos-lto-headers)
        depends+=(clang llvm lld)
    fi
''',
'''    provides=(LINUX-HEADERS)

    if _is_lto_kernel; then
        depends+=(clang llvm lld)
    fi
'''
)
# Insert SKIP checksum for our patch as the 4th b2sums entry when possible
t = t.replace(
"""        'SKIP'
        '",
"""        'SKIP'
        'SKIP'
        '",
    1,
)
p.write_text(t)
print("overlay applied")
PY

major=$(grep -E '^_major=' "$DIR/PKGBUILD" | head -1 | cut -d= -f2)
minor=$(grep -E '^_minor=' "$DIR/PKGBUILD" | head -1 | cut -d= -f2)
rel=$(grep -E '^pkgrel=' "$DIR/PKGBUILD" | head -1 | cut -d= -f2)
src=$(grep -E '^_srcname=' "$DIR/PKGBUILD" | head -1 | cut -d= -f2)
src=${src//\$\{_major\}/$major}
src=${src//\$\{_minor\}/$minor}
src=${src//\$\{_tagrel\}/1}
cat > "$ROOT/kernel/upstream.pin" <<EOF
# Pin against CachyOS/linux-cachyos. Bump when rebasing.
CACHYOS_KERNEL_PKG=linux-cachyos
CACHYOS_KERNEL_VER=${major}.${minor}-${rel}
CACHYOS_SRC=cachyos-${major}.${minor}-1
CACHYOS_PKGBUILD_URL=https://raw.githubusercontent.com/CachyOS/linux-cachyos/master/linux-cachyos/PKGBUILD
CACHYOS_CONFIG_URL=https://raw.githubusercontent.com/CachyOS/linux-cachyos/master/linux-cachyos/config
MAINLINE_SPI_PCI=https://raw.githubusercontent.com/torvalds/linux/master/drivers/spi/spi-pxa2xx-pci.c
EOF
echo "updated pin to ${major}.${minor}-${rel}"
echo "review kernel/linux-cachyos-mb81/PKGBUILD then ./scripts/build.sh"
