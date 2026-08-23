#!/usr/bin/env bash
# Usage: scripts/sync-from-cachy.sh
# Download the latest CachyOS linux-cachyos PKGBUILD + config into
# kernel/linux-cachyos-mb81/, keep PKGBUILD.upstream, and re-apply the
# MacBook8,1 overlay. Updates kernel/upstream.pin. Does not commit.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PIN="$REPO/kernel/upstream.pin"
PKGDIR="$REPO/kernel/linux-cachyos-mb81"
PATCH="$PKGDIR/0001-spi-pxa2xx-pci-disable-dma-macbook8-1.patch"

if [[ ! -f "$PIN" ]]; then
    echo "error: missing $PIN" >&2
    exit 1
fi
if [[ ! -f "$PATCH" ]]; then
    echo "error: missing kernel patch $PATCH" >&2
    exit 1
fi
command -v python3 >/dev/null 2>&1 || {
    echo "error: python3 is required for the PKGBUILD overlay" >&2
    exit 1
}

# shellcheck disable=SC1090
source "$PIN"

: "${CACHYOS_PKGBUILD_URL:?CACHYOS_PKGBUILD_URL unset in upstream.pin}"
: "${CACHYOS_CONFIG_URL:?CACHYOS_CONFIG_URL unset in upstream.pin}"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "Downloading CachyOS PKGBUILD..."
curl -fsSL --retry 3 --retry-delay 1 "$CACHYOS_PKGBUILD_URL" -o "$tmp/PKGBUILD.upstream"

echo "Downloading CachyOS config..."
curl -fsSL --retry 3 --retry-delay 1 "$CACHYOS_CONFIG_URL" -o "$tmp/config"

echo "Applying MacBook8,1 overlay..."
python3 - "$tmp/PKGBUILD.upstream" "$tmp/PKGBUILD" "$tmp/verinfo" <<'PY'
import re
import sys
from pathlib import Path

PATCH = "0001-spi-pxa2xx-pci-disable-dma-macbook8-1.patch"
PKGDESC = (
    "CachyOS kernel for MacBook8,1 with SPI PIO quirk (keyboard/trackpad)"
)
URL = "https://github.com/DerpcatMusic/cachyos-macbook8-1"


class OverlayError(Exception):
    pass


def once(text: str, old: str, new: str, name: str) -> str:
    n = text.count(old)
    if n == 0:
        raise OverlayError(
            f"{name}: expected snippet not found (upstream PKGBUILD drifted)\n"
            f"--- looking for ---\n{old}"
        )
    if n != 1:
        raise OverlayError(
            f"{name}: snippet matched {n} times (expected 1); refusing to patch"
        )
    return text.replace(old, new, 1)


def sub_once(text: str, pattern: str, repl: str, name: str, flags: int = 0) -> str:
    matches = list(re.finditer(pattern, text, flags))
    if len(matches) != 1:
        raise OverlayError(
            f"{name}: expected 1 match for /{pattern}/, found {len(matches)}"
        )
    return re.sub(pattern, repl, text, count=1, flags=flags)


def assigns(text: str) -> dict[str, str]:
    out: dict[str, str] = {}
    for m in re.finditer(r"^([A-Za-z_][A-Za-z0-9_]*)=(.*)$", text, re.M):
        name, val = m.group(1), m.group(2).strip()
        if (val.startswith("'") and val.endswith("'")) or (
            val.startswith('"') and val.endswith('"')
        ):
            val = val[1:-1]
        out[name] = val
    return out


def expand(s: str | None, env: dict[str, str], depth: int = 0) -> str:
    if not s or depth > 10:
        return s or ""

    def repl(m: re.Match[str]) -> str:
        key = m.group(1)
        if key not in env:
            return m.group(0)
        return expand(env[key], env, depth + 1)

    s = re.sub(r"\$\{([A-Za-z_][A-Za-z0-9_]*)\}", repl, s)
    s = re.sub(r"\$([A-Za-z_][A-Za-z0-9_]*)", repl, s)
    return s


def overlay(text: str) -> str:
    if f'"{PATCH}"' in text:
        raise OverlayError(
            "PKGBUILD already references the MacBook8,1 patch; "
            "refusing to overlay an already-overlaid file"
        )

    text = sub_once(
        text,
        r': "\$\{_processor_opt:=[^}]*\}"',
        r': "${_processor_opt:=GENERIC_V3}"',
        "_processor_opt",
    )

    text = once(
        text,
        'pkgbase="linux-$_pkgsuffix"',
        "# MacBook8,1: never collide with official linux-cachyos\n"
        "_pkgsuffix=cachyos-mb81\n"
        'pkgbase="linux-$_pkgsuffix"',
        "force _pkgsuffix=cachyos-mb81",
    )

    text = sub_once(
        text,
        r"^pkgdesc='[^']*'$",
        f"pkgdesc='{PKGDESC}'",
        "pkgdesc",
        flags=re.M,
    )

    text = sub_once(
        text,
        r'^url="[^"]*"$',
        f'url="{URL}"',
        "url",
        flags=re.M,
    )

    text = once(
        text,
        '    "config"\n)',
        f'    "config"\n    "{PATCH}"\n)',
        'source=() insert patch after "config"',
    )

    text = once(
        text,
        "export KBUILD_BUILD_HOST=cachyos",
        "export KBUILD_BUILD_HOST=macbook81",
        "KBUILD_BUILD_HOST",
    )

    text = once(
        text,
        "    cp ../config .config\n",
        "    cp ../config .config\n"
        "\n"
        '    echo "MacBook8,1: built-in SPI keyboard/trackpad (LUKS-safe)..."\n'
        "    scripts/config -e SPI -e SPI_MASTER \\\n"
        "        -e SPI_PXA2XX -e SPI_PXA2XX_PCI \\\n"
        "        -e KEYBOARD_APPLESPI\n",
        "SPI scripts/config after cp ../config .config",
    )

    text = once(
        text,
        "    # Replace LTO kernel with the default kernel\n"
        "    if _is_lto_kernel; then\n"
        "        provides+=(linux-cachyos-lto=$_kernver)\n"
        "        replaces=(linux-cachyos-lto)\n"
        "    fi\n",
        "    # Do not replaces= official linux-cachyos / linux-cachyos-lto\n",
        "remove linux-cachyos-lto provides/replaces from _package()",
    )

    text = once(
        text,
        "    if _is_lto_kernel; then\n"
        "        provides+=(linux-cachyos-lto-headers=$_kernver)\n"
        "        replaces=(linux-cachyos-lto-headers)\n"
        "        depends+=(clang llvm lld)\n"
        "    fi\n",
        "    if _is_lto_kernel; then\n"
        "        depends+=(clang llvm lld)\n"
        "    fi\n",
        "remove linux-cachyos-lto-headers provides/replaces",
    )

    m = re.search(r"^b2sums=\((.*?)\)", text, re.S | re.M)
    if not m:
        raise OverlayError("b2sums: array not found")
    entries = re.findall(r"'([^']*)'", m.group(1))
    if len(entries) < 3:
        raise OverlayError(
            f"b2sums: expected at least 3 entries "
            f"(tarball, SKIP, config), found {len(entries)}"
        )
    if entries[1] != "SKIP":
        raise OverlayError(
            f"b2sums: expected 2nd entry SKIP (tarball.asc), found {entries[1]!r}"
        )
    if entries[2] == "SKIP":
        raise OverlayError("b2sums: 3rd entry is SKIP; expected config hash")
    if len(entries) > 3 and entries[3] == "SKIP":
        raise OverlayError(
            "b2sums: 4th checksum is already SKIP; refusing to double-insert"
        )
    entries.insert(3, "SKIP")
    lines = [f"b2sums=('{entries[0]}'"]
    for e in entries[1:]:
        lines.append(f"        '{e}'")
    lines[-1] += ")"
    text = text[: m.start()] + "\n".join(lines) + text[m.end() :]

    checks = [
        ("_pkgsuffix=cachyos-mb81" in text, "missing forced _pkgsuffix=cachyos-mb81"),
        (f'"{PATCH}"' in text, "patch not in source=()"),
        ("SPI_PXA2XX_PCI" in text, "missing SPI_PXA2XX_PCI scripts/config"),
        ("KEYBOARD_APPLESPI" in text, "missing KEYBOARD_APPLESPI scripts/config"),
        ("KBUILD_BUILD_HOST=macbook81" in text, "missing KBUILD_BUILD_HOST=macbook81"),
        (PKGDESC in text, "pkgdesc not applied"),
        (URL in text, "url not applied"),
        (
            "replaces=(linux-cachyos-lto)" not in text,
            "still has replaces=(linux-cachyos-lto)",
        ),
        (
            "linux-cachyos-lto=$_kernver" not in text,
            "still provides linux-cachyos-lto",
        ),
        (
            "linux-cachyos-lto-headers=$_kernver" not in text,
            "still provides linux-cachyos-lto-headers",
        ),
        (
            ": \"${_processor_opt:=GENERIC_V3}\"" in text,
            "missing _processor_opt:=GENERIC_V3",
        ),
    ]
    for ok, msg in checks:
        if not ok:
            raise OverlayError(f"post-check failed: {msg}")
    return text


in_path, out_path, ver_path = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3])
original = in_path.read_text(encoding="utf-8")
try:
    overlaid = overlay(original)
except OverlayError as e:
    print(f"error: overlay failed: {e}", file=sys.stderr)
    print(
        "Aborting without writing PKGBUILD (tree left unchanged).",
        file=sys.stderr,
    )
    sys.exit(1)

env = assigns(overlaid)
pkgver = expand(env.get("pkgver"), env)
pkgrel = expand(env.get("pkgrel"), env)
srcname = expand(env.get("_srcname"), env)
if not pkgver or not pkgrel or not srcname:
    print("error: overlay succeeded but failed to extract versions", file=sys.stderr)
    sys.exit(1)

out_path.write_text(overlaid, encoding="utf-8")
ver_path.write_text(f"{pkgver}-{pkgrel}\n{srcname}\n", encoding="utf-8")
PY

mapfile -t verinfo < "$tmp/verinfo"
if (( ${#verinfo[@]} < 2 )); then
    echo "error: overlay did not print pkgver/srcname" >&2
    exit 1
fi
new_ver="${verinfo[0]}"
new_src="${verinfo[1]}"

cp -f "$tmp/PKGBUILD.upstream" "$PKGDIR/PKGBUILD.upstream"
cp -f "$tmp/config" "$PKGDIR/config"
cp -f "$tmp/PKGBUILD" "$PKGDIR/PKGBUILD"

python3 - "$PIN" "$new_ver" "$new_src" <<'PY'
import re
import sys
from pathlib import Path

path, ver, src = Path(sys.argv[1]), sys.argv[2], sys.argv[3]
text = path.read_text(encoding="utf-8")


def repl_field(text: str, key: str, val: str) -> str:
    new, n = re.subn(
        rf"^{re.escape(key)}=.*$",
        f"{key}={val}",
        text,
        count=1,
        flags=re.M,
    )
    if n != 1:
        raise SystemExit(f"error: failed to update {key} in upstream.pin (matches={n})")
    return new


text = repl_field(text, "CACHYOS_KERNEL_VER", ver)
text = repl_field(text, "CACHYOS_SRC", src)
path.write_text(text, encoding="utf-8")
PY

echo "Updated pin: CACHYOS_KERNEL_VER=$new_ver CACHYOS_SRC=$new_src"
echo
if git -C "$REPO" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C "$REPO" --no-pager diff --stat -- \
        kernel/linux-cachyos-mb81 kernel/upstream.pin
else
    echo "(not a git repo; skipping diffstat)"
fi
echo
echo "Not committed."
