#!/usr/bin/env bash
set -euo pipefail

# Hyprland desktop stage.
# Run AFTER 02-backups.sh.
#
# Hyprland 0.55+ uses Lua configuration. This stage installs a small,
# working baseline first. SDRX-Dots is cloned for later migration, but its
# upstream installer is intentionally not run because its current config tree
# still targets the older hyprlang layout.

[[ $EUID -ne 0 ]] || { echo "Run as your normal user, not root."; exit 1; }
command -v yay >/dev/null || { echo "Run 01-system.sh first."; exit 1; }

echo "==> Pre-desktop snapshots"
sudo snapper -c root create --description "before desktop installation"
sudo snapper -c home create --description "before desktop installation"

echo "==> Hyprland"
sudo pacman -S --needed --noconfirm \
  hyprland hypridle hyprlock hyprpaper hyprsunset hyprpolkitagent \
  xdg-desktop-portal xdg-desktop-portal-hyprland polkit \
  waybar swaync wl-clipboard cliphist grim slurp swappy fuzzel \
  brightnessctl playerctl pavucontrol pamixer nwg-displays nwg-look

echo "==> Terminal and file managers"
sudo pacman -S --needed --noconfirm \
  foot thunar thunar-archive-plugin thunar-volman gvfs udisks2 tumbler \
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

echo "==> SDRX-Dots source"
SDRX_DIR="$HOME/.local/src/SDRX-Dots"
mkdir -p "$(dirname "$SDRX_DIR")"

if [[ -d "$SDRX_DIR/.git" ]]; then
  git -C "$SDRX_DIR" pull --ff-only
else
  git clone https://github.com/Sadrach34/SDRX-Dots.git "$SDRX_DIR"
fi

echo "SDRX-Dots cloned to:"
echo "  $SDRX_DIR"
echo "Its upstream installer is intentionally skipped for now."

echo "==> Personal configuration"
mkdir -p \
  "$HOME/.config/hypr" \
  "$HOME/.config/foot" \
  "$HOME/.config/yazi" \
  "$HOME/.config/waybar" \
  "$HOME/.local/share/applications"

# Preserve an existing Hyprland Lua config instead of silently overwriting it.
HYPR_CONFIG="$HOME/.config/hypr/hyprland.lua"
if [[ -f "$HYPR_CONFIG" ]] && ! grep -q "ARCH_POST_INSTALL_BASELINE" "$HYPR_CONFIG"; then
  cp -n "$HYPR_CONFIG" "$HYPR_CONFIG.pre-arch-post-install"
fi

cat > "$HYPR_CONFIG" <<'EOF'
-- ARCH_POST_INSTALL_BASELINE
-- Small, boring, working baseline for Hyprland 0.55+.
-- SDRX-Dots is kept separate until its config is migrated to Lua.

local terminal = "foot"
local file_manager = "thunar"
local launcher = "fuzzel"

hl.config({
    general = {
        gaps_in = 5,
        gaps_out = 10,
        border_size = 2,
        layout = "dwindle",
    },

    decoration = {
        rounding = 6,
        shadow = {
            enabled = false,
        },
        blur = {
            enabled = false,
        },
    },

    animations = {
        enabled = false,
    },

    input = {
        kb_layout = "us",
        follow_mouse = 1,
        sensitivity = 0,
    },

    dwindle = {
        preserve_split = true,
    },

    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
    },
})

-- Use integer 1x scaling on every monitor.
hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    scale = 1,
})

-- Start desktop helpers once per Hyprland session.
hl.on("hyprland.start", function()
    hl.exec_cmd("waybar")
    hl.exec_cmd("swaync")
    hl.exec_cmd("hyprsunset")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
end)

-- Applications.
hl.bind("SUPER + RETURN", hl.dsp.exec_cmd(terminal), {
    description = "Open terminal",
})
hl.bind("SUPER + E", hl.dsp.exec_cmd(file_manager), {
    description = "Open file manager",
})
hl.bind("SUPER + SHIFT + E", hl.dsp.exec_cmd(terminal .. " -e yazi"), {
    description = "Open Yazi",
})
hl.bind("SUPER + D", hl.dsp.exec_cmd(launcher), {
    description = "Open application launcher",
})

-- Notifications.
hl.bind("SUPER + N", hl.dsp.exec_cmd("swaync-client -t"), {
    description = "Toggle notifications",
})

-- Window management.
hl.bind("SUPER + Q", hl.dsp.window.close(), {
    description = "Close active window",
})
hl.bind("SUPER + F", hl.dsp.window.fullscreen({
    mode = "maximized",
    action = "toggle",
}), {
    description = "Toggle fullscreen",
})
hl.bind("SUPER + SHIFT + F", hl.dsp.window.float({
    action = "toggle",
}), {
    description = "Toggle floating",
})
hl.bind("SUPER + M", hl.dsp.exit(), {
    description = "Exit Hyprland",
})

-- Focus.
hl.bind("SUPER + LEFT", hl.dsp.focus({ direction = "l" }))
hl.bind("SUPER + RIGHT", hl.dsp.focus({ direction = "r" }))
hl.bind("SUPER + UP", hl.dsp.focus({ direction = "u" }))
hl.bind("SUPER + DOWN", hl.dsp.focus({ direction = "d" }))

-- Move windows.
hl.bind("SUPER + SHIFT + LEFT", hl.dsp.window.move({ direction = "l" }))
hl.bind("SUPER + SHIFT + RIGHT", hl.dsp.window.move({ direction = "r" }))
hl.bind("SUPER + SHIFT + UP", hl.dsp.window.move({ direction = "u" }))
hl.bind("SUPER + SHIFT + DOWN", hl.dsp.window.move({ direction = "d" }))

-- Workspaces.
for i = 1, 9 do
    hl.bind("SUPER + " .. i, hl.dsp.focus({ workspace = i }))
    hl.bind("SUPER + SHIFT + " .. i, hl.dsp.window.move({
        workspace = i,
    }))
end

-- Audio.
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), {
    locked = true,
})
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%-"), {
    locked = true,
})
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"), {
    locked = true,
})
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), {
    locked = true,
})
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), {
    locked = true,
})
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), {
    locked = true,
})

-- Brightness.
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set +5%"), {
    locked = true,
})
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"), {
    locked = true,
})

-- Screenshots.
hl.bind("SUPER + SHIFT + S", hl.dsp.exec_cmd("sh -c 'grim -g \"$(slurp)\" - | wl-copy'"), {
    description = "Screenshot region",
})
EOF

cat > "$HOME/.config/waybar/config.jsonc" <<'EOF'
{
    "layer": "top",
    "position": "top",
    "height": 28,
    "spacing": 4,
    "modules-left": [
        "hyprland/workspaces"
    ],
    "modules-center": [
        "clock"
    ],
    "modules-right": [
        "tray"
    ],

    "hyprland/workspaces": {
        "disable-scroll": true,
        "all-outputs": true,
        "format": "{icon}",
        "format-icons": {
            "active": "●",
            "default": "○",
            "urgent": "!"
        }
    },

    "clock": {
        "format": "{:%a %d %b  %H:%M}",
        "tooltip-format": "<big>{:%A, %d %B %Y}</big>\\n<tt>{calendar}</tt>"
    },

    "tray": {
        "icon-size": 16,
        "spacing": 8
    }
}
EOF

cat > "$HOME/.config/waybar/style.css" <<'EOF'
* {
    font-family: "JetBrainsMono Nerd Font";
    font-size: 12px;
}

window#waybar {
    background: rgba(20, 20, 20, 0.92);
}

#workspaces button {
    padding: 0 7px;
    margin: 2px 1px;
    border-radius: 4px;
    color: #888888;
}

#workspaces button.active {
    color: #ffffff;
}

#clock,
#tray {
    padding: 0 8px;
}
EOF

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
if ! git diff --cached --quiet; then
  if git config user.name >/dev/null 2>&1 && git config user.email >/dev/null 2>&1; then
    git commit -m "Add desktop configuration"
  else
    echo "WARNING: Git identity is not configured for ~/.dotfiles; leaving the changes staged."
    echo 'Configure it later with:'
    echo '  git -C ~/.dotfiles config user.name "Your Name"'
    echo '  git -C ~/.dotfiles config user.email "you@example.com"'
  fi
fi

echo "==> Verification"
for cmd in hyprland foot thunar yazi zathura telegram-desktop brave hyprsunset brightnessctl fuzzel git; do
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
echo "Hyprland baseline:"
echo "  ~/.config/hypr/hyprland.lua"
echo "  ~/.config/hypr/hyprsunset.conf"
echo "  ~/.config/foot/foot.ini"
echo "  ~/.config/yazi/yazi.toml"
echo
echo "SDRX-Dots source:"
echo "  $SDRX_DIR"
echo
echo "Reboot before judging the final desktop behavior."
