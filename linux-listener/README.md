# wrist-mouse — Linux listener

Turns your Omarchy (or any Wayland/Hyprland) machine into something the
WristMouse watch app can drive like a Bluetooth mouse, over your local
network, using [`ydotool`](https://github.com/ReimuNotMoe/ydotool) to inject
real input events via `uinput` — so it works regardless of compositor.

## Install

```bash
./setup.sh
```

This will:
1. Install `ydotool` via pacman if missing
2. Add you to the `input` group (needed for `/dev/uinput`)
3. Enable & start `ydotoold`
4. Generate a random pairing token in `~/.config/wrist-mouse/env`
5. Install and start the `wrist-mouse` user systemd service

At the end it prints your **IP, port and token** — enter those three values
in the WristMouse watch app's pairing screen.

## Manual run (for testing)

```bash
export WRIST_MOUSE_TOKEN=devtoken
python3 listener.py --port 43117 -v
```

## Useful commands

```bash
systemctl --user status wrist-mouse     # is it running?
journalctl --user -u wrist-mouse -f     # live logs
systemctl --user restart wrist-mouse    # after editing config
```

## Protocol

Newline-delimited JSON over a single persistent TCP connection:

| Message | Meaning |
|---|---|
| `{"type":"auth","token":"..."}` | must be the first message |
| `{"type":"move","dx":N,"dy":N}` | relative pointer move |
| `{"type":"click","button":"left"\|"right"\|"middle"}` | press+release |
| `{"type":"down","button":"..."}` / `{"type":"up","button":"..."}` | for drag gestures |
| `{"type":"ping"}` | server replies `{"type":"pong"}` |

## Waybar module (status indicator on the bar)

<img src="../assets/icon-24.png" width="24" valign="middle" alt="" /> — the icon that ships with the module.

`waybar-module.sh` reads the status file `listener.py` keeps updated and
prints it in the JSON format Waybar's `custom` module type expects.

Add to `~/.config/waybar/config.jsonc`:

```jsonc
"custom/wristmouse": {
  "exec": "~/.local/share/wrist-mouse/waybar-module.sh",
  "return-type": "json",
  "interval": 5,
  "tooltip": true
},
```

...and add `"custom/wristmouse"` to one of the `modules-left` /
`modules-center` / `modules-right` arrays in that same file.

Add to `~/.config/waybar/style.css` for the connected/disconnected states
(uses the generated icon — see [`../assets`](../assets)):

```css
#custom-wristmouse {
  padding: 0 8px;
  background-image: url("file:///home/YOURUSER/.local/share/wrist-mouse/icon-24.png");
  background-repeat: no-repeat;
  background-position: center left 4px;
  padding-left: 26px;
}
#custom-wristmouse.connected   { color: #8fd3c7; }
#custom-wristmouse.disconnected { color: #6b6b6b; }
```

`setup.sh` copies `waybar-module.sh` and `../assets/icon-24.png` next to
`listener.py` in `~/.local/share/wrist-mouse/`, so the paths above work
out of the box (just swap `YOURUSER` for your username, or use `$HOME` if
your Waybar build resolves it). Reload Waybar with `killall -SIGUSR2 waybar`
or your Omarchy keybind for "reload bar" to pick up the config change.

## Notes

- Works over your home WiFi. For control when you're out and about, put
  both the watch (via your iPhone's connection) and this machine on the
  same [Tailscale](https://tailscale.com) network and use the Tailscale IP
  instead.
- The token is a shared secret, not real crypto — fine for a trusted LAN,
  not meant to be exposed to the internet. Don't port-forward 43117.
