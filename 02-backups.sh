#!/usr/bin/env bash
set -euo pipefail

# Backup layer. Run BEFORE installing/modifying desktop dotfiles.
# Requires a Btrfs root and /home, as configured by archinstall.

[[ $EUID -ne 0 ]] || { echo "Run as your normal user, not root."; exit 1; }
command -v snapper >/dev/null || { echo "Run 01-system.sh first."; exit 1; }

echo "==> Configuring Snapper"

if [[ ! -f /etc/snapper/configs/root ]]; then
  sudo snapper -c root create-config /
fi

if [[ ! -f /etc/snapper/configs/home ]]; then
  sudo snapper -c home create-config /home
fi

sudo mkdir -p /etc/snapper/configs.d

sudo tee /etc/snapper/configs.d/root.conf >/dev/null <<'EOF'
TIMELINE_CREATE="yes"
TIMELINE_CLEANUP="yes"
NUMBER_CLEANUP="yes"
NUMBER_MIN_AGE="1800"
NUMBER_LIMIT="20"
NUMBER_LIMIT_IMPORTANT="10"
TIMELINE_MIN_AGE="1800"
TIMELINE_LIMIT_HOURLY="6"
TIMELINE_LIMIT_DAILY="7"
TIMELINE_LIMIT_WEEKLY="4"
TIMELINE_LIMIT_MONTHLY="3"
TIMELINE_LIMIT_YEARLY="1"
EOF

sudo tee /etc/snapper/configs.d/home.conf >/dev/null <<'EOF'
TIMELINE_CREATE="yes"
TIMELINE_CLEANUP="yes"
NUMBER_CLEANUP="yes"
NUMBER_MIN_AGE="1800"
NUMBER_LIMIT="12"
NUMBER_LIMIT_IMPORTANT="6"
TIMELINE_MIN_AGE="1800"
TIMELINE_LIMIT_HOURLY="4"
TIMELINE_LIMIT_DAILY="7"
TIMELINE_LIMIT_WEEKLY="4"
TIMELINE_LIMIT_MONTHLY="2"
TIMELINE_LIMIT_YEARLY="1"
EOF

sudo systemctl enable --now snapper-timeline.timer
sudo systemctl enable --now snapper-cleanup.timer

echo "==> Installing snap-pac"
sudo pacman -S --needed --noconfirm snap-pac

echo "==> Creating initial snapshots"
sudo snapper -c root create --description "before desktop setup"
sudo snapper -c home create --description "before desktop setup"

echo "==> Creating dotfiles Git repository"
DOTS="$HOME/.dotfiles"
mkdir -p "$DOTS/config"
cd "$DOTS"

if [[ ! -d .git ]]; then
  git init
fi

cat > .gitignore <<'EOF'
# Secrets
**/credentials
**/secrets
**/*.key
**/*.pem
**/*.token

# Caches/runtime data
.cache/
.local/share/
.local/state/

# Large/private app profiles
.config/BraveSoftware/
.config/Signal/
.config/telegram-desktop/
EOF

for d in hypr foot waybar yazi swaync gtk-3.0 gtk-4.0; do
  if [[ -d "$HOME/.config/$d" ]]; then
    mkdir -p "$DOTS/config/$d"
    rsync -a --delete "$HOME/.config/$d/" "$DOTS/config/$d/"
  fi
done

for f in .bashrc .zshrc .profile; do
  [[ -f "$HOME/$f" ]] && cp "$HOME/$f" "$DOTS/$f"
done

git add .
git diff --cached --quiet || git commit -m "Initial dotfiles backup"

echo "==> Installing backup helper commands"
mkdir -p "$HOME/.local/bin"

cat > "$HOME/.local/bin/snapshot-now" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
sudo snapper -c root create --description "manual root snapshot"
sudo snapper -c home create --description "manual home snapshot"
echo "Snapshots created."
EOF
chmod +x "$HOME/.local/bin/snapshot-now"

echo
echo "External Restic backup:"
echo "  Snapshots are NOT a substitute for an external backup."
echo
read -rp "Configure a Restic repository now? [y/N]: " answer

if [[ "$answer" =~ ^[Yy]$ ]]; then
  read -rp "Mounted backup directory (example: /run/media/$USER/Backup): " backup_mount
  [[ -d "$backup_mount" ]] || { echo "Directory does not exist."; exit 1; }

  repo="$backup_mount/restic"
  mkdir -p "$HOME/.config/restic" "$HOME/.local/bin"

  if [[ ! -f "$repo/config" ]]; then
    restic -r "$repo" init
  fi

  printf '%s\n' "$repo" > "$HOME/.config/restic/repository"
  chmod 600 "$HOME/.config/restic/repository"

  cat > "$HOME/.local/bin/backup-now" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
repo="$(cat "$HOME/.config/restic/repository")"

restic -r "$repo" backup \
  "$HOME/.dotfiles" \
  "$HOME/Documents" \
  "$HOME/Pictures" \
  "$HOME/Videos" \
  "$HOME/Downloads" \
  --exclude-caches

restic -r "$repo" forget \
  --keep-daily 7 \
  --keep-weekly 4 \
  --keep-monthly 6 \
  --prune
EOF
  chmod +x "$HOME/.local/bin/backup-now"
fi

echo
echo "==> Backup verification"
findmnt -t btrfs
sudo snapper list-configs
sudo snapper -c root list
sudo snapper -c home list
sudo btrfs subvolume list /

echo
echo "==> Backup stage complete."
echo "Before major changes: snapshot-now"
echo "After configuring Restic: backup-now"
echo "Dotfiles repo: $DOTS"
