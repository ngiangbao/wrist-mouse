#!/usr/bin/env python3
"""
wrist-mouse listener
---------------------
Runs on the Linux machine (Omarchy / Hyprland / any Wayland compositor with
uinput access). Listens for a persistent TCP connection from the WristMouse
watchOS app and replays the incoming pointer events using `ydotool`.

Protocol (newline-delimited JSON over TCP):

    {"type": "auth", "token": "<shared-secret>"}
    {"type": "move", "dx": 4.2, "dy": -1.1}
    {"type": "down", "button": "left"}
    {"type": "up",   "button": "left"}
    {"type": "click","button": "left"}      # convenience: down+up
    {"type": "ping"}

The client must send `auth` as the first message or the connection is
dropped. Everything else is a no-op until auth succeeds.

Requires:
  - ydotool + ydotoold running (https://github.com/ReimuNotMoe/ydotool)
  - the user running this script must be able to reach the ydotoold socket
    (usually /tmp/.ydotool_socket, or set $YDOTOOL_SOCKET)
"""

from __future__ import annotations

import argparse
import json
import logging
import os
import socket
import socketserver
import subprocess
import threading
import time

log = logging.getLogger("wrist-mouse")

# ydotool click codes: low byte = button index, high nibble = DOWN(0x40)/UP(0x80)
BUTTON_INDEX = {"left": 0x00, "right": 0x01, "middle": 0x02}
DOWN_FLAG = 0x40
UP_FLAG = 0x80


class YdotoolBackend:
    """Thin wrapper around the `ydotool` CLI."""

    def __init__(self, ydotool_bin: str = "ydotool"):
        self.ydotool_bin = ydotool_bin
        self._lock = threading.Lock()

    def _run(self, *args: str) -> None:
        try:
            subprocess.run(
                [self.ydotool_bin, *args],
                check=True,
                capture_output=True,
                timeout=2,
            )
        except FileNotFoundError:
            log.error("`%s` not found on PATH. Is ydotool installed?", self.ydotool_bin)
        except subprocess.CalledProcessError as e:
            log.warning("ydotool %s failed: %s", args, e.stderr.decode(errors="replace"))
        except subprocess.TimeoutExpired:
            log.warning("ydotool %s timed out", args)

    def move(self, dx: float, dy: float) -> None:
        if dx == 0 and dy == 0:
            return
        with self._lock:
            self._run("mousemove", "--relative", "--", str(int(round(dx))), str(int(round(dy))))

    def button(self, name: str, flag: int) -> None:
        idx = BUTTON_INDEX.get(name, BUTTON_INDEX["left"])
        code = f"0x{(flag | idx):02X}"
        with self._lock:
            self._run("click", code)

    def down(self, name: str) -> None:
        self.button(name, DOWN_FLAG)

    def up(self, name: str) -> None:
        self.button(name, UP_FLAG)

    def click(self, name: str) -> None:
        idx = BUTTON_INDEX.get(name, BUTTON_INDEX["left"])
        code = f"0x{(DOWN_FLAG | UP_FLAG | idx):02X}"
        with self._lock:
            self._run("click", code)


class Handler(socketserver.StreamRequestHandler):
    def handle(self) -> None:
        backend: YdotoolBackend = self.server.backend  # type: ignore[attr-defined]
        token: str = self.server.token  # type: ignore[attr-defined]
        peer = self.client_address[0]
        authed = False
        last_seen = time.time()
        log.info("connection from %s", peer)

        try:
            while True:
                line = self.rfile.readline()
                if not line:
                    break
                line = line.strip()
                if not line:
                    continue
                try:
                    msg = json.loads(line)
                except json.JSONDecodeError:
                    log.warning("bad json from %s: %r", peer, line)
                    continue

                mtype = msg.get("type")

                if not authed:
                    if mtype == "auth" and msg.get("token") == token:
                        authed = True
                        self.wfile.write(b'{"ok":true}\n')
                        log.info("%s authenticated", peer)
                    else:
                        log.warning("%s failed auth, dropping", peer)
                        self.wfile.write(b'{"ok":false}\n')
                        break
                    continue

                last_seen = time.time()
                if mtype == "move":
                    backend.move(float(msg.get("dx", 0)), float(msg.get("dy", 0)))
                elif mtype == "click":
                    backend.click(msg.get("button", "left"))
                elif mtype == "down":
                    backend.down(msg.get("button", "left"))
                elif mtype == "up":
                    backend.up(msg.get("button", "left"))
                elif mtype == "ping":
                    self.wfile.write(b'{"type":"pong"}\n')
                else:
                    log.debug("unknown message type: %s", mtype)
        except (ConnectionResetError, BrokenPipeError):
            pass
        finally:
            log.info("connection from %s closed (last activity %.1fs ago)", peer, time.time() - last_seen)


class Server(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True


def main() -> None:
    parser = argparse.ArgumentParser(description="wrist-mouse listener for Linux/Wayland")
    parser.add_argument("--host", default="0.0.0.0", help="bind address (default: 0.0.0.0)")
    parser.add_argument("--port", type=int, default=43117, help="TCP port (default: 43117)")
    parser.add_argument(
        "--token",
        default=os.environ.get("WRIST_MOUSE_TOKEN", ""),
        help="shared secret the watch app must send; also read from $WRIST_MOUSE_TOKEN",
    )
    parser.add_argument("--ydotool-bin", default="ydotool", help="path to the ydotool binary")
    parser.add_argument("-v", "--verbose", action="store_true")
    args = parser.parse_args()

    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
    )

    if not args.token:
        log.error("No token set. Pass --token or set $WRIST_MOUSE_TOKEN. Refusing to start.")
        raise SystemExit(1)

    backend = YdotoolBackend(args.ydotool_bin)
    server = Server((args.host, args.port), Handler)
    server.backend = backend  # type: ignore[attr-defined]
    server.token = args.token  # type: ignore[attr-defined]

    log.info("wrist-mouse listening on %s:%d", args.host, args.port)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
