#!/usr/bin/env bash
# Usage: scripts/check-upstream.sh
# Fetch mainline spi-pxa2xx-pci.c and the CachyOS linux-cachyos PKGBUILD.
# Exit 2 if mainline already has the MacBook8,1 quirk (drop our patch).
# Exit 1 if CachyOS is newer than kernel/upstream.pin (rebase needed).
# Exit 0 if the pin is current.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PIN="$REPO/kernel/upstream.pin"

if [[ ! -f "$PIN" ]]; then
    echo "error: missing $PIN" >&2
    exit 1
fi

# shellcheck disable=SC1090
source "$PIN"

: "${MAINLINE_SPI_PCI:?MAINLINE_SPI_PCI unset in upstream.pin}"
: "${CACHYOS_PKGBUILD_URL:?CACHYOS_PKGBUILD_URL unset in upstream.pin}"
: "${CACHYOS_KERNEL_VER:?CACHYOS_KERNEL_VER unset in upstream.pin}"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "Fetching mainline spi-pxa2xx-pci.c..."
curl -fsSL --retry 3 --retry-delay 1 "$MAINLINE_SPI_PCI" -o "$tmp/spi-pxa2xx-pci.c"

if grep -F -q 'MacBook8,1' "$tmp/spi-pxa2xx-pci.c"; then
    echo "DROP PATCH — mainline has the quirk"
    exit 2
fi
echo "Mainline spi-pxa2xx-pci.c: no MacBook8,1 quirk (patch still needed)"

echo "Fetching CachyOS PKGBUILD..."
curl -fsSL --retry 3 --retry-delay 1 "$CACHYOS_PKGBUILD_URL" -o "$tmp/PKGBUILD"

extract_ver="$(python3 - "$tmp/PKGBUILD" <<'PY'
import re
import sys

path = sys.argv[1]
text = open(path, encoding="utf-8").read()
assigns: dict[str, str] = {}
for m in re.finditer(r"^([A-Za-z_][A-Za-z0-9_]*)=(.*)$", text, re.M):
    name, val = m.group(1), m.group(2).strip()
    if (val.startswith("'") and val.endswith("'")) or (
        val.startswith('"') and val.endswith('"')
    ):
        val = val[1:-1]
    assigns[name] = val


def expand(s: str | None, depth: int = 0) -> str:
    if not s or depth > 10:
        return s or ""

    def repl(m: re.Match[str]) -> str:
        key = m.group(1)
        if key not in assigns:
            return m.group(0)
        return expand(assigns[key], depth + 1)

    s = re.sub(r"\$\{([A-Za-z_][A-Za-z0-9_]*)\}", repl, s)
    s = re.sub(r"\$([A-Za-z_][A-Za-z0-9_]*)", repl, s)
    return s

pkgver = expand(assigns.get("pkgver"))
pkgrel = expand(assigns.get("pkgrel"))
if not pkgver or not pkgrel:
    sys.stderr.write("error: failed to extract pkgver-pkgrel from CachyOS PKGBUILD\n")
    sys.exit(1)
print(f"{pkgver}-{pkgrel}")
PY
)"

echo "Pinned:   $CACHYOS_KERNEL_VER"
echo "Upstream: $extract_ver"

if [[ "$extract_ver" == "$CACHYOS_KERNEL_VER" ]]; then
    echo "Current — no rebase needed"
    exit 0
fi

if command -v vercmp >/dev/null 2>&1; then
    cmp="$(vercmp "$extract_ver" "$CACHYOS_KERNEL_VER")"
else
    cmp="$(python3 - "$extract_ver" "$CACHYOS_KERNEL_VER" <<'PY'
import re
import sys

def key(v: str):
    parts = []
    for p in re.split(r"[^A-Za-z0-9]+", v):
        if not p:
            continue
        parts.append((0, int(p)) if p.isdigit() else (1, p))
    return parts

a, b = sys.argv[1], sys.argv[2]
ka, kb = key(a), key(b)
print((ka > kb) - (ka < kb))
PY
)"
fi

if (( cmp > 0 )); then
    echo "CachyOS $extract_ver is newer than pin $CACHYOS_KERNEL_VER — needs rebase"
    echo "Run: scripts/sync-from-cachy.sh"
    exit 1
fi

echo "Pin $CACHYOS_KERNEL_VER is ahead of CachyOS $extract_ver"
exit 0
