# wrist-mouse — watchOS app

A watch-only SwiftUI app: the screen is a relative trackpad (drag to move,
tap to click), Digital Crown reserved for scroll. Talks to the
[linux-listener](../linux-listener) over TCP on your LAN.

## Project generation

The `.xcodeproj` is **not** checked in — it's generated from
[`project.yml`](project.yml) with [XcodeGen](https://github.com/yonaskolb/XcodeGen),
so it never goes stale or merge-conflicts. This needs a Mac with Xcode.

```bash
brew install xcodegen
cd watch-app
xcodegen generate
open WristMouse.xcodeproj
```

In Xcode: select the `WristMouse` target → **Signing & Capabilities** → pick
your own Team (needs an Apple Developer account, free tier is enough to run
on your own watch via Xcode; the paid $99/yr Program is only required for
TestFlight — see below).

Run it: with your Apple Watch paired to Xcode (Window → Devices and
Simulators), select it as the run destination and hit ▶.

## Using the app

1. On Omarchy, run `linux-listener/setup.sh` — it prints a host, port and token.
2. On the watch, enter those three values on the pairing screen.
3. Drag anywhere to move the cursor, tap to click.

## Don't have a Mac?

You don't need to build this yourself at all — see
[`../.github/workflows/build-and-upload.yml`](../.github/workflows/build-and-upload.yml):
GitHub Actions has free macOS runners with Xcode preinstalled, so the whole
XcodeGen → build → upload-to-TestFlight pipeline runs in the cloud on every
push. See the top-level README for the one-time setup (Apple Developer
enrollment + a few GitHub secrets) needed to turn that on.
