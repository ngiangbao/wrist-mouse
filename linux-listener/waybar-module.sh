#!/usr/bin/env bash
# Prints one JSON line for a Waybar `custom/wristmouse` module, reading the
# status file that listener.py keeps up to date. Safe to poll frequently —
# it only reads a small local file, no network calls.
set -euo pipefail

STATUS_PATH="${WRIST_MOUSE_STATUS_PATH:-$HOME/.cache/wrist-mouse/status.json}"

python3 - "$STATUS_PATH" <<'PY'
import json
import sys
import time

path = sys.argv[1]

try:
    with open(path) as f:
        data = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    data = {"connected": False, "peer": None, "updated": 0}

connected = data.get("connected", False)
peer = data.get("peer")
updated = data.get("updated", 0)
age = time.time() - updated if updated else None

if connected:
    text = "⌚ "
    tooltip = f"wrist-mouse: connected ({peer})" if peer else "wrist-mouse: connected"
    cls = "connected"
else:
    text = "⌚"
    if updated:
        mins = int((age or 0) // 60)
        tooltip = f"wrist-mouse: disconnected (last seen {mins}m ago)"
    else:
        tooltip = "wrist-mouse: listener not running or never connected"
    cls = "disconnected"

print(json.dumps({"text": text, "tooltip": tooltip, "class": cls}))
PY
