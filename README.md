# Arch Linux post-install setup

For a fresh Arch installation created with \`archinstall\`.

## Order

\`\`\`text
archinstall
    ↓
01-system.sh
    ↓
02-backups.sh
    ↓
03-desktop.sh
\`\`\`

\`archinstall\` owns partitioning, encryption, Btrfs, bootloader, and the initial Arch install.

These scripts **do not partition disks** and do not overwrite the filesystem layout.

## Recommended archinstall choices

Use archinstall for:

- UEFI
- LUKS2 encryption
- Btrfs
- a separate \`/home\` subvolume
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
- \`yay\`

It does not install Hyprland or SDRX-Dots.

## 02-backups.sh

This deliberately runs **before** desktop customization.

It sets up:

- Snapper snapshots for \`/\` and \`/home\`
- \`snap-pac\`
- a Git repository at \`~/.dotfiles\`
- optional Restic backups to an external drive

Snapshots are for rollback. They are **not** a substitute for an external backup.

The intended model is:

\`\`\`text
Btrfs snapshots
       +
Git
       +
Restic → external disk
\`\`\`

## 03-desktop.sh

Installs:

- Hyprland
- SDRX-Dots
- hypridle / hyprlock / hyprpaper / hyprsunset
- Waybar / swaync
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

The script keeps personal changes in a small override layer instead of rewriting the SDRX configuration.

### SDRX-Dots

The script clones:

\`\`\`text
https://github.com/Sadrach34/SDRX-Dots
\`\`\`

and runs its upstream \`install.sh\`.

Because upstream installer options can change, this script does not guess undocumented installer flags.

### Hyprsunset

The script creates:

\`\`\`text
~/.config/hypr/hyprsunset.conf
\`\`\`

with time-based profiles and starts \`hyprsunset\` from Hyprland.

## Notion

Notion and Notion Calendar are launched as Brave web apps.

## Battery life

No script can honestly promise a fixed battery-life result. Actual battery life depends on the laptop's CPU, GPU, display, firmware, Wi-Fi hardware, refresh rate, and suspend behavior.

Useful checks:

\`\`\`bash
tlp-stat -s
tlp-stat -p
upower -i "$(upower -e | grep BAT | head -n1)"
\`\`\`

## Recovery

Create snapshots:

\`\`\`bash
snapshot-now
\`\`\`

List snapshots:

\`\`\`bash
sudo snapper -c root list
sudo snapper -c home list
\`\`\`

List Btrfs subvolumes:

\`\`\`bash
sudo btrfs subvolume list /
\`\`\`

Run Restic:

\`\`\`bash
backup-now
\`\`\`

## Hardware-dependent setup

GPU configuration is intentionally not hard-coded.

Check the hardware first:

\`\`\`bash
lspci | grep -Ei 'VGA|3D|Display'
\`\`\`

The correct GPU setup differs between Intel, AMD, NVIDIA, and hybrid systems.

Secure Boot is also left outside these scripts so it can be configured deliberately after the base system works.
