# Arch OS Bootable Device Creator

**[ ➜ Run One-line POSIX Executable](#create-bootable-usb-device)**
<br><sub></sub>

<div align="center">
<p><img src="./screenshot.png"></p>
  <p>
    <img src="https://img.shields.io/badge/MAINTAINED-YES-green?style=for-the-badge">
    <img src="https://img.shields.io/badge/License-GPL_v2-blue?style=for-the-badge">
  </p>
  <p><sub>100% shellcheck approved</sub></p>
  <p><sub>powered by <a href="https://github.com/murkl/arch-os">Arch OS</a></sub></p>
</div>

## Create Bootable USB Device

This POSIX script downloads the latest official [Arch Linux ISO](https://archlinux.org/download/) and creates a bootable USB device on Linux.

```
curl -Ls https://raw.githubusercontent.com/murkl/arch-os-creator/refs/heads/main/creator.sh | bash
```

Afterwards install: **[ ➜ Arch OS](https://github.com/murkl/arch-os)**

### Dependencies

```
sh curl lsblk sha256sum dd grep
```

### Environment Variables

The default variables can be overwritten with `export`. The script checks whether the variables are already set at startup.

```
export ARCH_ISO_DOWNLOAD_DIR="~/Downloads"
export ARCH_ISO_DOWNLOAD_MIRROR="https://mirrors.xtom.de/archlinux/iso/latest"
```
