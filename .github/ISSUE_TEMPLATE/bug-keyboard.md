---
name: Keyboard / trackpad
about: Built-in keyboard or trackpad still dead on MacBook8,1
title: "[keyboard] "
labels: bug
---

MacBook8,1 only. USB keyboard works for reporting this.

- CachyOS version:
- `linux-cachyos-mb81` package version:
- Official `linux-cachyos` still installed (rescue)?
- Cold boot or resume from sleep?

```bash
uname -r
dmesg | grep -Ei 'MacBook8,1: forcing SPI PIO|applespi|pxa2xx|timeout|-110'
```

Paste that output. You want the PIO line and no `-110` timeouts.

What failed: keyboard, trackpad, both, LUKS prompt, after lid close?
