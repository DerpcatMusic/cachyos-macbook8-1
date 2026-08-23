# cachyos-macbook8-1

CachyOS hardware enablement for **MacBook8,1** (12-inch Retina, Early 2015).

This is not a distro. Official CachyOS stays official. We ship one extra kernel package:

```text
linux-cachyos-mb81
linux-cachyos-mb81-headers
```

`pacman -Syu` keeps Plasma, Mesa, firmware, and `linux-cachyos`. It does not overwrite this kernel.

## What is broken, and what we change

Built-in keyboard and trackpad sit on Intel LPSS SPI (`00:15.4`, `8086:9ce6`) behind in-tree `applespi`. Mainline `spi-pxa2xx-pci.c` always sets `enable_dma = 1`. On this board EFI holds the LPSS DMA block in reset, macOS never enables those DMA channels, and Linux SPI transfers time out (`-110`) with IRQ 21 stuck at 0.

The only kernel delta is a DMI quirk:

```text
MacBook8,1 → enable_dma = 0  (PIO)
```

SPI + applespi are built-in so the internal keyboard works at a LUKS prompt.

Not in this kernel (on purpose):

- the unmerged July 2026 v16 LPSS S3 series
- speaker DKMS
- Bluetooth ACPI overlays
- FaceTime HD
- a forked CachyOS ISO

## Requirements

| | |
|---|---|
| Machine | MacBook8,1 only |
| Distro | CachyOS, **x86-64-v3** repos (not v4) |
| Rescue kernel | keep official `linux-cachyos` installed |
| Build CPU | anything; PKGBUILD forces `GENERIC_V3` (never `-march=native`) |

USB-C hub + USB keyboard for the first install. Stock CachyOS ISO is enough.

## Live ISO (keyboard and trackpad from USB boot)

Flash the MacBook ISO. It boots `linux-cachyos-mb81` in the live session, so the
internal keyboard and trackpad work in Calamares. The installer installs that
same kernel as the default. Official `linux-cachyos` is not used.

```bash
./scripts/build-iso.sh
# ISO lands in ~/src/mb81-iso-out/ and dist/
```

## Install (packages only, if you already have CachyOS)

```bash
# copy the two packages over, then:
sudo pacman -U linux-cachyos-mb81-*.pkg.tar.zst linux-cachyos-mb81-headers-*.pkg.tar.zst
sudo cp packaging/mb81-spi.conf /etc/mkinitcpio.conf.d/mb81-spi.conf
sudo mkinitcpio -P
```

Keep `linux-cachyos` installed. Limine/GRUB will show both. Boot `linux-cachyos-mb81`.

Cold-boot check:

```bash
dmesg | grep -Ei 'MacBook8,1: forcing SPI PIO|applespi|pxa2xx|timeout|-110'
```

You want the PIO line and no `-110` timeouts. Then lid-suspend. Start with `mem_sleep_default=s2idle` until deep S3 is proven.

## Build (on a CachyOS desktop)

Do not build on the NTFS git checkout. `scripts/build.sh` uses `/home/derpcat/build/mb81`.

```bash
./scripts/build.sh          # 1–3 hours, Clang ThinLTO
./scripts/repo-add.sh       # local pacman repo
```

Rebuild after a CachyOS kernel bump:

```bash
./scripts/check-upstream.sh
./scripts/sync-from-cachy.sh
# review the diff, then
./scripts/build.sh
```

When `check-upstream.sh` says mainline has `MacBook8,1` in `spi-pxa2xx-pci.c`, delete the patch and switch the MacBook back to `linux-cachyos`.

## Layout

```text
kernel/linux-cachyos-mb81/   PKGBUILD, Cachy config, PIO patch
kernel/upstream.pin          Cachy version we last rebased onto
scripts/                     sync, build, repo, MacBook install
packaging/                   mkinitcpio drop-in, pacman.conf example
.github/workflows/           patch-apply CI, Monday upstream watch
```

## License

Kernel patch: GPL-2.0-only (same as Linux). Packaging scripts: MIT.
