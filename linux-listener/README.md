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

## Notes

- Works over your home WiFi. For control when you're out and about, put
  both the watch (via your iPhone's connection) and this machine on the
  same [Tailscale](https://tailscale.com) network and use the Tailscale IP
  instead.
- The token is a shared secret, not real crypto — fine for a trusted LAN,
  not meant to be exposed to the internet. Don't port-forward 43117.
