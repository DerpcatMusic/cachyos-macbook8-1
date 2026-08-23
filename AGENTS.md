# Agent notes

This repo is a **CachyOS kernel overlay**, not a distro.

- Package name must stay `linux-cachyos-mb81`. Never `replaces=` official `linux-cachyos`.
- Always `_processor_opt=GENERIC_V3`. Empty default enables `X86_NATIVE_CPU` on the builder.
- One kernel patch unless a second, isolated S3 patch is added later.
- Drop the PIO patch when mainline `spi-pxa2xx-pci.c` contains `MacBook8,1`.
- Build under `/home/.../build`, not the NTFS checkout.
- Do not vendor speaker/Bluetooth/camera into the kernel package.
