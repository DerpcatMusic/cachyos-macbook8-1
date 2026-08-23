---
name: CachyOS rebase
about: Rebase linux-cachyos-mb81 onto a newer CachyOS kernel
title: "Rebase linux-cachyos-mb81 onto CachyOS "
labels: rebase
---

CachyOS `linux-cachyos` moved; this overlay needs a rebase.

- Pinned version (`kernel/upstream.pin`):
- New CachyOS version:

```bash
./scripts/sync-from-cachy.sh
```

Keep all of:

- `_pkgsuffix=cachyos-mb81`
- `_processor_opt:=GENERIC_V3`
- `0001-spi-pxa2xx-pci-disable-dma-macbook8-1.patch`
- no `replaces=(linux-cachyos)` / `replaces=(linux-cachyos-lto)`

Do not drop the SPI PIO patch unless mainline `spi-pxa2xx-pci.c` already contains `MacBook8,1`.
