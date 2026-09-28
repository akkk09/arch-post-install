#!/usr/bin/env bash
set -euo pipefail

# Hyprland + SDRX-Dots desktop stage.
# Run AFTER 02-backups.sh.

[[ $EUID -ne 0 ]] || { echo "Run as your normal user, not root."; exit 1; }
command -v yay >/dev/null || { echo "Run 01-system.sh first."; exit 1; }

echo "==> Pre-desktop snapshots"
sudo snapper -c root create --description "before desktop installation"
sudo snapper -c home create --description "before desktop installation"

echo "==> Hyprland"
sudo pacman -S --needed --noconfirm \
  hyprland hypridle hyprlock hyprpaper hyprsunset hyprpolkitagent \
  xdg-desktop-portal xdg-desktop-portal-hyprland polkit \
  waybar swaync wl-clipboard cliphist grim slurp swappy \
  brightnessctl playerctl pavucontrol pamixer nwg-displays nwg-look

echo "==> Terminal and file managers"
sudo pacman -S --needed --noconfirm \
  foot thunar thunar-archive-plugin thunar-volman tumbler \
  file-roller ffmpegthumbnailer chafa yazi 7zip

echo "==> PDF viewer"
sudo pacman -S --needed --noconfirm zathura zathura-pdf-mupdf

echo "==> Telegram"
sudo pacman -S --needed --noconfirm telegram-desktop

echo "==> Brave"
yay -S --needed --noconfirm brave-bin

echo "==> Signal"
if yay -Si signal-desktop >/dev/null 2>&1; then
  yay -S --needed --noconfirm signal-desktop
else
  echo "WARNING: signal-desktop is not available from the configured AUR sources."
fi

echo "==> SDRX-Dots"
SDRX_DIR="$HOME/.local/src/SDRX-Dots"
mkdir -p "$(dirname "$SDRX_DIR")"

if [[ -d "$SDRX_DIR/.git" ]]; then
  git -C "$SDRX_DIR" pull --ff-only
else
  git clone https://github.com/Sadrach34/SDRX-Dots.git "$SDRX_DIR"
fi

cd "$SDRX_DIR"

echo
echo "SDRX-Dots is at:"
echo "  $SDRX_DIR"
echo
echo "Starting its upstream installer."
echo "Choose the options that match your hardware."
echo "If it asks for a terminal, choose foot."
echo "Do not replace the bootloader from this stage."
echo

read -rp "Start SDRX-Dots installer? [Y/n]: " run_sdrx
run_sdrx="\${run_sdrx:-Y}"

if [[ "$run_sdrx" =~ ^[Yy]$ ]]; then
  [[ -f install.sh ]] || { echo "SDRX-Dots install.sh was not found."; exit 1; }
  bash install.sh
fi

echo "==> Personal Hyprland overrides"
mkdir -p \
  "$HOME/.config/hypr/conf.d" \
  "$HOME/.config/foot" \
  "$HOME/.config/yazi" \
  "$HOME/.local/share/applications" \
  "$HOME/.local/bin"

cat > "$HOME/.config/foot/foot.ini" <<'EOF'
[main]
term=xterm-256color
font=JetBrainsMono Nerd Font:size=11
pad=8x8

[scrollback]
lines=10000

[cursor]
style=beam
blink=yes

[mouse]
hide-when-typing=yes
EOF

cat > "$HOME/.config/hypr/hyprsunset.conf" <<'EOF'
# hyprsunset time profiles
max-gamma = 100

profile {
    time = 07:00
    identity = true
    gamma = 1.0
}

profile {
    time = 18:30
    temperature = 5000
    gamma = 0.95
}

profile {
    time = 21:00
    temperature = 4200
    gamma = 0.90
}
EOF

cat > "$HOME/.config/hypr/conf.d/90-personal.conf" <<'EOF'
# Personal overrides. Keep SDRX upstream files intact.

exec-once = hyprsunset

bindel = ,XF86MonBrightnessUp, exec, brightnessctl set +5%
bindel = ,XF86MonBrightnessDown, exec, brightnessctl set 5%-

bind = SUPER, RETURN, exec, foot
bind = SUPER, E, exec, thunar
bind = SUPER SHIFT, E, exec, foot -e yazi
EOF

cat > "$HOME/.config/yazi/yazi.toml" <<'EOF'
[manager]
show_hidden = true
sort_by = "natural"
sort_sensitive = false
sort_dir_first = true
linemode = "size"

[preview]
wrap = "yes"
tab_size = 2
max_width = 1200
max_height = 800
EOF

echo "==> Notion launchers"
cat > "$HOME/.local/share/applications/notion.desktop" <<'EOF'
[Desktop Entry]
Name=Notion
Comment=Notion workspace
Exec=brave --app=https://www.notion.so/
Icon=brave
Terminal=false
Type=Application
Categories=Office;Productivity;
EOF

cat > "$HOME/.local/share/applications/notion-calendar.desktop" <<'EOF'
[Desktop Entry]
Name=Notion Calendar
Comment=Notion Calendar
Exec=brave --app=https://calendar.notion.so/
Icon=brave
Terminal=false
Type=Application
Categories=Office;Calendar;Productivity;
EOF

echo "==> Updating dotfiles Git repository"
DOTS="$HOME/.dotfiles"
mkdir -p "$DOTS/config"

for d in hypr foot waybar yazi swaync; do
  if [[ -d "$HOME/.config/$d" ]]; then
    mkdir -p "$DOTS/config/$d"
    rsync -a --delete "$HOME/.config/$d/" "$DOTS/config/$d/"
  fi
done

cd "$DOTS"
git add .
git diff --cached --quiet || git commit -m "Add desktop configuration"

echo "==> Verification"
for cmd in hyprland foot thunar yazi zathura telegram-desktop brave hyprsunset brightnessctl git; do
  if command -v "$cmd" >/dev/null 2>&1; then
    printf '[OK] %s\n' "$cmd"
  else
    printf '[WARN] %s is missing\n' "$cmd"
  fi
done

fc-cache -f >/dev/null 2>&1 || true
update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true

sudo snapper -c root create --description "desktop installation complete"
sudo snapper -c home create --description "desktop installation complete"

echo
echo "==> Desktop stage complete."
echo
echo "Config:"
echo "  ~/.config/hypr/"
echo "  ~/.config/hypr/hyprsunset.conf"
echo "  ~/.config/hypr/conf.d/90-personal.conf"
echo "  ~/.config/foot/foot.ini"
echo "  ~/.config/yazi/yazi.toml"
echo
echo "Reboot before judging the final desktop behavior."
