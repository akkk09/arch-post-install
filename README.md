# Arch Linux post-install setup

For a fresh Arch installation created with `archinstall`.

## Order

```text
archinstall
    ↓
01-system.sh
    ↓
02-backups.sh
    ↓
03-desktop.sh
```

`archinstall` owns partitioning, encryption, Btrfs, bootloader, and the initial Arch install.

These scripts **do not partition disks** and do not overwrite the filesystem layout.

## Recommended archinstall choices

Use archinstall for:

- UEFI
- LUKS2 encryption
- Btrfs
- a separate `/home` subvolume
- zstd compression
- no swap partition if you plan to use zram
- your preferred bootloader

If you want hibernation, choose and size swap deliberately instead of blindly using zram-only.

## 01-system.sh

Installs:

- NetworkManager
- Wi-Fi tooling
- Bluetooth / BlueZ / Blueman
- PipeWire + WirePlumber
- brightnessctl
- TLP
- fwupd
- zram
- fonts
- Git / GitHub CLI / lazygit
- useful CLI tools
- `yay`

It does not install Hyprland or SDRX-Dots.

## 02-backups.sh

This deliberately runs **before** desktop customization.

It sets up:

- Snapper snapshots for `/` and `/home`
- `snap-pac`
- a Git repository at `~/.dotfiles`
- optional Restic backups to an external drive

Snapshots are for rollback. They are **not** a substitute for an external backup.

The intended model is:

```text
Btrfs snapshots
       +
Git
       +
Restic → external disk
```

## 03-desktop.sh

Installs:

- Hyprland
- hypridle / hyprlock / hyprpaper / hyprsunset
- Hyprland policy agent
- Waybar / swaync
- fuzzel application launcher
- foot
- Thunar
- Yazi
- Zathura + PDF support
- Brave
- Signal
- Telegram
- Notion web app
- Notion Calendar web app
- Wayland utilities
- brightness controls

### Hyprland baseline

Hyprland 0.55+ uses Lua configuration. The post-install script now creates a small working baseline at:

```text
~/.config/hypr/hyprland.lua
```

It provides:

- foot terminal
- Thunar and Yazi
- fuzzel launcher
- Waybar and swaync startup
- workspace switching
- window focus/movement
- close/fullscreen/floating controls
- audio and brightness keys
- clipboard history
- screenshots

If an existing `hyprland.lua` is present, the script preserves a copy as:

```text
~/.config/hypr/hyprland.lua.pre-arch-post-install
```

The baseline deliberately avoids hardware-specific monitor/GPU settings.

### SDRX-Dots

The script clones:

```text
https://github.com/Sadrach34/SDRX-Dots
```

but **does not run its upstream installer yet**.

The current SDRX tree still contains a traditional `hyprland.conf` configuration alongside some Lua files, while the installed Hyprland version expects Lua. Running the upstream installer blindly could replace or conflict with the working baseline.

SDRX-Dots is therefore kept at:

```text
~/.local/src/SDRX-Dots
```

We can migrate the useful SDRX pieces into the Lua configuration later, after the base desktop is verified.

### Hyprsunset

The script creates:

```text
~/.config/hypr/hyprsunset.conf
```

with time-based profiles and starts `hyprsunset` from Hyprland.

## Notion

Notion and Notion Calendar are launched as Brave web apps.

## Battery life

No script can honestly promise a fixed battery-life result. Actual battery life depends on the laptop's CPU, GPU, display, firmware, Wi-Fi hardware, refresh rate, and suspend behavior.

Useful checks:

```bash
tlp-stat -s
tlp-stat -p
upower -i "$(upower -e | grep BAT | head -n1)"
```

## Recovery

Create snapshots:

```bash
snapshot-now
```

List snapshots:

```bash
sudo snapper -c root list
sudo snapper -c home list
```

List Btrfs subvolumes:

```bash
sudo btrfs subvolume list /
```

Run Restic:

```bash
backup-now
```

## Hardware-dependent setup

GPU configuration is intentionally not hard-coded.

Check the hardware first:

```bash
lspci | grep -Ei 'VGA|3D|Display'
```

The correct GPU setup differs between Intel, AMD, NVIDIA, and hybrid systems.

Secure Boot is also left outside these scripts so it can be configured deliberately after the base system works.
