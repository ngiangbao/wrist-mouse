#!/usr/bin/env bash
# One-time setup for the wrist-mouse listener on Arch/Omarchy.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$HOME/.local/share/wrist-mouse"
CONF_DIR="$HOME/.config/wrist-mouse"
UNIT_DIR="$HOME/.config/systemd/user"

echo "==> Installing ydotool (if missing)"
if ! command -v ydotool >/dev/null 2>&1; then
  sudo pacman -S --needed --noconfirm ydotool
fi

echo "==> Making sure you're in the 'input' group (needed for uinput)"
if ! id -nG "$USER" | grep -qw input; then
  sudo usermod -aG input "$USER"
  echo "    Added $USER to 'input' group. You must log out/in (or reboot) for this to take effect."
fi

echo "==> Enabling ydotoold (user service)"
systemctl --user enable --now ydotoold.service 2>/dev/null || {
  echo "    No user-level ydotoold.service found; enabling the system-wide one instead."
  sudo systemctl enable --now ydotoold.service
}

mkdir -p "$DATA_DIR" "$CONF_DIR" "$UNIT_DIR"
cp "$SCRIPT_DIR/listener.py" "$DATA_DIR/listener.py"
cp "$SCRIPT_DIR/waybar-module.sh" "$DATA_DIR/waybar-module.sh"
chmod +x "$DATA_DIR/waybar-module.sh"
if [ -d "$SCRIPT_DIR/../assets" ]; then
  cp "$SCRIPT_DIR"/../assets/icon-*.png "$DATA_DIR/" 2>/dev/null || true
fi

if [ ! -f "$CONF_DIR/env" ]; then
  TOKEN="$(python3 -c 'import secrets; print(secrets.token_hex(16))')"
  cat > "$CONF_DIR/env" <<EOF
WRIST_MOUSE_TOKEN=$TOKEN
WRIST_MOUSE_PORT=43117
EOF
  echo "==> Generated a new pairing token in $CONF_DIR/env"
else
  echo "==> Reusing existing token in $CONF_DIR/env"
fi

sed "s#%h#$HOME#g" "$SCRIPT_DIR/wrist-mouse.service" > "$UNIT_DIR/wrist-mouse.service"

systemctl --user daemon-reload
systemctl --user enable --now wrist-mouse.service

TOKEN_VALUE="$(grep WRIST_MOUSE_TOKEN "$CONF_DIR/env" | cut -d= -f2)"
IP="$(ip -4 addr show scope global | awk '/inet/{print $2}' | cut -d/ -f1 | head -n1)"

echo
echo "================================================================"
echo " wrist-mouse listener is running."
echo "   Host (enter in the watch app): $IP"
echo "   Port: 43117"
echo "   Token: $TOKEN_VALUE"
echo "================================================================"
echo
echo "Check status with:  systemctl --user status wrist-mouse"
echo "Watch logs with:    journalctl --user -u wrist-mouse -f"
echo
echo "Waybar module script installed at: $DATA_DIR/waybar-module.sh"
echo "See linux-listener/README.md for the config.jsonc / style.css snippets."
