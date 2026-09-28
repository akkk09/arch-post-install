#!/usr/bin/env bash
set -euo pipefail

# Base laptop setup. Run after archinstall and reboot.
# This script does NOT partition disks or modify filesystems.

[[ $EUID -ne 0 ]] || { echo "Run as your normal user, not root."; exit 1; }

echo "==> Updating Arch"
sudo pacman -Syu --noconfirm

echo "==> Installing base tools"
sudo pacman -S --needed --noconfirm \
  base-devel git curl wget rsync unzip zip 7zip jq ripgrep fd fzf btop fastfetch \
  tree file which less man-db man-pages github-cli lazygit \
  usbutils pciutils lm_sensors smartmontools fwupd powertop \
  btrfs-progs snapper restic

echo "==> Networking"
sudo pacman -S --needed --noconfirm \
  networkmanager network-manager-applet iwd linux-firmware
sudo systemctl enable --now NetworkManager

echo "==> Bluetooth"
sudo pacman -S --needed --noconfirm bluez bluez-utils blueman
sudo systemctl enable --now bluetooth

echo "==> Audio"
sudo pacman -S --needed --noconfirm \
  pipewire pipewire-alsa pipewire-pulse wireplumber alsa-utils pavucontrol pamixer

echo "==> Laptop controls"
sudo pacman -S --needed --noconfirm brightnessctl upower acpi tlp tlp-rdw

# TLP and power-profiles-daemon should not both manage power.
if pacman -Q power-profiles-daemon >/dev/null 2>&1; then
  sudo systemctl disable --now power-profiles-daemon.service 2>/dev/null || true
  sudo pacman -Rns --noconfirm power-profiles-daemon
fi

sudo systemctl enable --now tlp.service

# Keep the laptop on the balanced platform profile by default.
sudo mkdir -p /etc/tlp.d
sudo tee /etc/tlp.d/01-arch-post-install.conf >/dev/null <<'EOF'
PLATFORM_PROFILE_ON_AC=balanced
PLATFORM_PROFILE_ON_BAT=balanced
PLATFORM_PROFILE_ON_SAV=low-power
EOF
sudo tlp start

sudo systemctl enable --now fwupd.service 2>/dev/null || true

echo "==> zram"
sudo mkdir -p /etc/systemd
sudo tee /etc/systemd/zram-generator.conf >/dev/null <<'EOF'
[zram0]
zram-size = ram
compression-algorithm = zstd
swap-priority = 100
EOF

echo "==> Fonts"
sudo pacman -S --needed --noconfirm \
  ttf-jetbrains-mono-nerd ttf-fira-code ttf-firacode-nerd \
  ttf-roboto ttf-roboto-mono noto-fonts noto-fonts-emoji \
  ttf-nerd-fonts-symbols ttf-nerd-fonts-symbols-common otf-font-awesome

fc-cache -f >/dev/null 2>&1 || true

echo "==> Installing yay"
if ! command -v yay >/dev/null 2>&1; then
  tmp="$(mktemp -d)"
  git clone --depth=1 https://aur.archlinux.org/yay.git "$tmp/yay"
  (cd "$tmp/yay" && makepkg -si --noconfirm)
  rm -rf "$tmp"
fi

echo
echo "Hardware:"
lspci | grep -Ei 'VGA|3D|Display|Network controller|Wireless' || true

echo
echo "Useful checks:"
echo "  nmcli device"
echo "  bluetoothctl"
echo "  wpctl status"
echo "  tlp-stat -s"
echo "  upower -i \"$(upower -e | grep BAT | head -n1)\""
echo
echo "==> System stage complete."
