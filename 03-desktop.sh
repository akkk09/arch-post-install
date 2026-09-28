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
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Pre-desktop snapshots"
sudo snapper -c root create --description "before desktop installation"
sudo snapper -c home create --description "before desktop installation"

echo "==> Hyprland"
sudo pacman -S --needed --noconfirm \
  hyprland hypridle hyprlock hyprpaper hyprsunset hyprpolkitagent \
  xdg-desktop-portal xdg-desktop-portal-hyprland xdg-desktop-portal-gtk polkit \
  waybar swaync wl-clipboard cliphist grim slurp swappy fuzzel \
  brightnessctl playerctl pavucontrol pamixer libnotify nwg-displays nwg-look

echo "==> Terminal and file managers"
sudo pacman -S --needed --noconfirm \
  foot thunar thunar-archive-plugin thunar-volman gvfs udisks2 tumbler \
  file-roller ffmpegthumbnailer chafa yazi 7zip qt5ct qt6ct

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
  "$HOME/.config/fuzzel" \
  "$HOME/.config/gtk-3.0" \
  "$HOME/.config/gtk-4.0" \
  "$HOME/.config/qt5ct" \
  "$HOME/.config/qt6ct" \
  "$HOME/.config/environment.d" \
  "$HOME/.local/share/applications"

# System-wide desktop appearance defaults for this user session.
# GTK: dark appearance + no toolkit animations.
cat > "$HOME/.config/gtk-3.0/settings.ini" <<'EOF'
[Settings]
gtk-theme-name=Adwaita
gtk-icon-theme-name=Adwaita
gtk-application-prefer-dark-theme=true
gtk-enable-animations=false
gtk-enable-event-sounds=false
gtk-enable-input-feedback-sounds=false
EOF

cat > "$HOME/.config/gtk-4.0/settings.ini" <<'EOF'
[Settings]
gtk-theme-name=Adwaita
gtk-icon-theme-name=Adwaita
gtk-enable-animations=false
gtk-enable-event-sounds=false
gtk-enable-input-feedback-sounds=false
EOF

if command -v gsettings >/dev/null 2>&1; then
  gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita'
  gsettings set org.gnome.desktop.interface icon-theme 'Adwaita'
  gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
  gsettings set org.gnome.desktop.interface enable-animations false 2>/dev/null || true
fi

cat > "$HOME/.config/qt5ct/qt5ct.conf" <<'EOF'
[Appearance]
color_scheme_path=/usr/share/qt5ct/colors/darker.conf
custom_palette=true
standard_dialogs=default
style=Fusion

[Interface]
gui_effects=@Invalid()
EOF

cat > "$HOME/.config/qt6ct/qt6ct.conf" <<'EOF'
[Appearance]
color_scheme_path=/usr/share/qt6ct/colors/darker.conf
custom_palette=true
standard_dialogs=default
style=Fusion

[Interface]
gui_effects=@Invalid()
EOF

cat > "$HOME/.config/environment.d/90-arch-post-install-desktop.conf" <<'EOF'
# Toolkit-wide appearance defaults.
GTK_THEME=Adwaita:dark
QT_QPA_PLATFORMTHEME=qt5ct:qt6ct
QT_STYLE_OVERRIDE=Fusion
QT_QUICK_CONTROLS_STYLE=Fusion
EOF

# Brave/Chromium: dark mode + reduced motion + zero-duration UI animations.
cat > "$HOME/.config/brave-flags.conf" <<'EOF'
--force-dark-mode
--force-prefers-reduced-motion
--animation-duration-scale=0
--wm-window-animations-disabled
--disable-modal-animations
EOF

# Preserve an existing Hyprland Lua config instead of silently overwriting it.
HYPR_CONFIG="$HOME/.config/hypr/hyprland.lua"

# Small OSD helper. swaync is the notification daemon; this script only
# reads the value after the change and sends the resulting state.
cat > "$HOME/.local/bin/desktop-notify" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
  volume)
    line="$(wpctl get-volume @DEFAULT_AUDIO_SINK@)"
    value="$(printf '%s\n' "$line" | awk '{printf "%d", $2 * 100 + 0.5}')"
    if grep -q '\[MUTED\]' <<< "$line"; then
      notify-send -a "Desktop Controls" -u low -h string:x-canonical-private-synchronous:desktop-volume "Volume" "Muted"
    else
      notify-send -a "Desktop Controls" -u low -h string:x-canonical-private-synchronous:desktop-volume "Volume" "${value}%"
    fi
    ;;
  mic)
    line="$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@)"
    if grep -q '\[MUTED\]' <<< "$line"; then
      notify-send -a "Desktop Controls" -u low -h string:x-canonical-private-synchronous:desktop-mic "Microphone" "Muted"
    else
      notify-send -a "Desktop Controls" -u low -h string:x-canonical-private-synchronous:desktop-mic "Microphone" "On"
    fi
    ;;
  brightness)
    current="$(brightnessctl get)"
    maximum="$(brightnessctl max)"
    value=$(( (current * 100 + maximum / 2) / maximum ))
    notify-send -a "Desktop Controls" -u low -h string:x-canonical-private-synchronous:desktop-brightness "Brightness" "${value}%"
    ;;
  *)
    echo "Usage: desktop-notify {volume|brightness}" >&2
    exit 2
    ;;
esac
EOF
chmod +x "$HOME/.local/bin/desktop-notify"


if [[ -f "$HYPR_CONFIG" ]] && ! grep -q "ARCH_POST_INSTALL_BASELINE" "$HYPR_CONFIG"; then
  cp -n "$HYPR_CONFIG" "$HYPR_CONFIG.pre-arch-post-install"
fi

cat > "$HYPR_CONFIG" <<'EOF'
-- ARCH_POST_INSTALL_BASELINE
-- Small, boring, working baseline for Hyprland 0.55+.
-- SDRX-Dots is kept separate until its config is migrated to Lua.

local terminal = 'foot -D "$HOME"'
local file_manager = "thunar"
local launcher = "fuzzel"

hl.config({
    general = {
        gaps_in = 5,
        gaps_out = 10,
        border_size = 0,
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
        touchpad = {
            natural_scroll = true,
        },
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
    scale = 1.2,
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

-- Clipboard history.
-- cliphist stores both text and image clipboard entries; fuzzel selects one.
hl.bind("SUPER + V", hl.dsp.exec_cmd("sh -c 'cliphist list | fuzzel --dmenu --prompt=\"Clipboard ❯ \" | cliphist decode | wl-copy'"), {
    description = "Open clipboard history",
})

-- Commandlets.
hl.bind("SUPER + BACKSLASH", hl.dsp.exec_cmd("sh -c 'cmd=$(printf \"%s\\n\" rename-camel arch-post-install-update pdf-search | fuzzel --dmenu --prompt=\"Commandlet ❯ \"); [ -n \"$cmd\" ] && foot -D \"$HOME\" -e bash -lc \"\\\"$HOME/.local/bin/$cmd\\\"; exec bash\"'"), {
    description = "Open commandlet menu",
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

hl.bind("SUPER + P", hl.dsp.window.float({
    action = "toggle",
}), {
    description = "Toggle floating window",
})
hl.bind("SUPER + M", hl.dsp.exit(), {
    description = "Exit Hyprland",
})

-- Mouse controls.
-- Hold Super + left/right mouse button to move/resize the active window.
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), {
    mouse = true,
})
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), {
    mouse = true,
})

-- Hold Super and scroll to switch workspaces.
hl.bind("SUPER + mouse_up", hl.dsp.focus({ workspace = "e+1" }), {
    mouse = true,
})
hl.bind("SUPER + mouse_down", hl.dsp.focus({ workspace = "e-1" }), {
    mouse = true,
})

-- Vim-style focus: h/j/k/l = left/down/up/right.
for key, direction in pairs({
    h = "l",
    j = "d",
    k = "u",
    l = "r",
}) do
    hl.bind("SUPER + " .. key, hl.dsp.focus({ direction = direction }), {
        description = "Focus " .. direction,
    })
end

-- Vim-style window movement: Super+Shift+h/j/k/l.
for key, direction in pairs({
    h = "l",
    j = "d",
    k = "u",
    l = "r",
}) do
    hl.bind("SUPER + SHIFT + " .. key, hl.dsp.window.move({ direction = direction }), {
        description = "Move window " .. direction,
    })
end

-- Resize mode: Super+R, then h/j/k/l. Escape exits the mode.
hl.bind("SUPER + R", hl.dsp.submap("resize"), {
    description = "Enter window resize mode",
})
hl.define_submap("resize", function()
    hl.bind("h", hl.dsp.window.resize({ x = -10, y = 0, relative = true }), { repeating = true })
    hl.bind("j", hl.dsp.window.resize({ x = 0, y = 10, relative = true }), { repeating = true })
    hl.bind("k", hl.dsp.window.resize({ x = 0, y = -10, relative = true }), { repeating = true })
    hl.bind("l", hl.dsp.window.resize({ x = 10, y = 0, relative = true }), { repeating = true })
    hl.bind("escape", hl.dsp.submap("reset"), {
        description = "Exit resize mode",
    })
end)

-- Group mode: Super+G, then use Vim keys.
hl.bind("SUPER + G", hl.dsp.submap("group_management"), {
    description = "Enter window group mode",
})

local function group_map(key, action, description)
    hl.bind(key, function()
        hl.dispatch(action)
        hl.dispatch(hl.dsp.submap("reset"))
    end, {
        description = description,
    })
end

hl.define_submap("group_management", function()
    group_map("g", hl.dsp.group.toggle(), "Toggle window group")
    group_map("h", hl.dsp.window.move({ into_group = "l" }), "Group with window on the left")
    group_map("j", hl.dsp.window.move({ into_group = "d" }), "Group with window below")
    group_map("k", hl.dsp.window.move({ into_group = "u" }), "Group with window above")
    group_map("l", hl.dsp.window.move({ into_group = "r" }), "Group with window on the right")
    group_map("e", hl.dsp.window.move({ out_of_group = true }), "Remove window from group")
    group_map("n", hl.dsp.group.next(), "Next window in group")
    group_map("p", hl.dsp.group.prev(), "Previous window in group")
    group_map("f", hl.dsp.group.move_window(), "Move window forward in group")
    group_map("b", hl.dsp.group.move_window({ forward = false }), "Move window backward in group")
    group_map("t", hl.dsp.group.lock_active(), "Toggle group lock")
    hl.bind("escape", hl.dsp.submap("reset"), {
        description = "Exit group mode",
    })
end)

-- Workspaces.
for i = 1, 9 do
    hl.bind("SUPER + " .. i, hl.dsp.focus({ workspace = i }))
    hl.bind("SUPER + SHIFT + " .. i, hl.dsp.window.move({
        workspace = i,
    }))
end

-- Audio.
hl.bind("F1", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle && desktop-notify volume"), {
    locked = true,
})
hl.bind("F2", hl.dsp.exec_cmd("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%- && desktop-notify volume"), {
    locked = true,
})
hl.bind("F3", hl.dsp.exec_cmd("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+ && desktop-notify volume"), {
    locked = true,
})
hl.bind("F4", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle && desktop-notify mic"), {
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
hl.bind("F6", hl.dsp.exec_cmd("brightnessctl set +5% && desktop-notify brightness"), {
    locked = true,
})
hl.bind("F5", hl.dsp.exec_cmd("brightnessctl set 5%- && desktop-notify brightness"), {
    locked = true,
})

-- Screenshots.
hl.bind("SUPER + SHIFT + S", hl.dsp.exec_cmd("sh -c 'grim -g \"$(slurp)\" - | wl-copy'"), {
    description = "Screenshot region",
})
EOF

cat > "$HOME/.config/fuzzel/fuzzel.ini" <<'EOF'
[main]
font=JetBrainsMono Nerd Font:size=11
terminal=foot
prompt=❯
icons-enabled=yes
lines=12
width=45
horizontal-pad=16
vertical-pad=10
inner-pad=6
layer=overlay

[colors]
background=141414ee
text=eeeeeeff
match=ffffffFF
selection=303030ff
selection-text=ffffffff
border=303030ff

[border]
width=0
radius=6
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
        "hyprland/submap",
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
    },

    "hyprland/submap": {
        "format": "MODE: {submap}",
        "default-submap": "NORMAL",
        "always-on": true,
        "tooltip": false
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
#tray,
#submap {
    padding: 0 8px;
}

#submap {
    font-weight: bold;
    background: rgba(255, 255, 255, 0.12);
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

echo "==> PDF search command"
install -Dm755 "$SCRIPT_DIR/bin/pdf-search" "$HOME/.local/bin/pdf-search"
echo "==> Commandlets"
install -d "$HOME/.local/bin"

cat > "$HOME/.local/bin/rename-camel" <<'EOF'
#!/usr/bin/env python3
import os
import re
import sys

root = os.getcwd()
apply = len(sys.argv) == 2 and sys.argv[1] == "--apply"

if len(sys.argv) > 1 and not apply:
    print("Usage: rename-camel [--apply]", file=sys.stderr)
    raise SystemExit(2)

def to_camel(name):
    if name.startswith(".") and name.count(".") == 1:
        return name
    stem, ext = os.path.splitext(name)
    words = [w for w in re.split(r"[ _-]+", stem.strip()) if w]
    if not words:
        return name
    result = words[0].lower()
    result += "".join(w[:1].upper() + w[1:].lower() for w in words[1:])
    return result + ext

changes = []
for directory, dirnames, filenames in os.walk(root, topdown=False):
    dirnames[:] = [d for d in dirnames if d != ".git"]
    for name in filenames + dirnames:
        old = os.path.join(directory, name)
        if os.path.basename(directory) == ".git":
            continue
        new_name = to_camel(name)
        if new_name != name:
            changes.append((old, os.path.join(directory, new_name)))

if not changes:
    print(f"No names need changing under: {root}")
    raise SystemExit(0)

print("Changes:")
for old, new in changes:
    print(f"  {old} -> {new}")

if not apply:
    print("\nPreview only. Run 'rename-camel --apply' to apply these changes.")
    raise SystemExit(0)

for old, new in changes:
    if os.path.exists(new):
        print(f"ERROR: target already exists: {new}", file=sys.stderr)
        raise SystemExit(1)
    os.rename(old, new)

print("Rename complete.")
EOF
chmod +x "$HOME/.local/bin/rename-camel"

cat > "$HOME/.local/bin/arch-post-install-update" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

REPO="$HOME/arch-post-install"
cd "$REPO"

echo "==> Checking local changes"
STASHED=false

if ! git diff --quiet || ! git diff --cached --quiet || [[ -n "$(git ls-files --others --exclude-standard)" ]]; then
    echo "==> Stashing local changes"
    git stash push -u -m "arch-post-install pre-pull"
    STASHED=true
else
    echo "==> Working tree is clean"
fi

echo "==> Pulling latest changes"
git pull --ff-only

if [[ "$STASHED" == true ]]; then
    echo "==> Restoring stashed changes"
    git stash pop
fi

echo "==> Making shell scripts executable"
chmod +x ./*.sh

echo "==> Done"
git status --short
EOF
chmod +x "$HOME/.local/bin/arch-post-install-update"

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

for d in hypr foot waybar yazi swaync gtk-3.0 gtk-4.0 qt5ct qt6ct environment.d; do
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
