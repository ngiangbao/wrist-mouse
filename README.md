# wrist-mouse

<img src="assets/icon-128.png" width="96" align="right" alt="wrist-mouse icon" />

Apple Watch as a wireless trackpad for Omarchy (Hyprland / Wayland Linux),
since Apple doesn't let a third-party watchOS app advertise itself as a
real Bluetooth HID peripheral — so this goes over WiFi instead.

```
┌─────────────┐   drag / tap on screen   ┌──────────────────┐   relative   ┌────────────┐
│ Apple Watch │ ───────────────────────▶ │  watch-app        │ ───TCP/────▶│  linux-     │ ──ydotool──▶  uinput
│  (watchOS)  │                          │  (SwiftUI)         │   JSON      │  listener   │              (real cursor
└─────────────┘                          └──────────────────┘             └────────────┘               movement)
```

- [`linux-listener/`](linux-listener) — Python TCP server that runs on
  Omarchy and replays incoming move/click events with `ydotool`. No build
  step, works today. Includes a Waybar status module (`waybar-module.sh`)
  so the bar shows whether the watch is currently connected.
- [`assets/`](assets) — the wrist-mouse icon (SVG + PNG at a few sizes),
  used by the Waybar module.
- [`watch-app/`](watch-app) — SwiftUI watchOS app: the screen is a drag
  trackpad, tap = click. Needs to be built with Xcode (or let CI do it —
  see below).
- [`.github/workflows/build-and-upload.yml`](.github/workflows/build-and-upload.yml) —
  builds the watch app on GitHub's macOS runners and uploads it straight to
  TestFlight on every push, so you never need your own Mac.

## Quick start (Linux side — works right now)

```bash
cd linux-listener
./setup.sh
```

It prints a host/port/token — that's everything the watch app needs.

## Getting the watch app onto your wrist, without owning a Mac

This repo can build itself in CI and ship straight to TestFlight. You only
need to do a few things **once**, all in the browser, under your own Apple
ID — none of it is something I can or should do on your behalf (it needs
your Apple ID login and your own $99/yr Developer Program payment):

1. **Enroll in the Apple Developer Program** (if you haven't):
   https://developer.apple.com/programs/enroll/
2. **Register an App ID** matching `com.ngiangbao.wristmouse` (or edit the
   bundle id in `watch-app/project.yml` to whatever you prefer first) at
   https://developer.apple.com/account/resources/identifiers/list
3. **Create the app record in App Store Connect** (My Apps → + → New App),
   same bundle id, platform watchOS/iOS. This is a one-time manual step —
   TestFlight uploads fail until the app record exists.
4. **Create an App Store Connect API key**:
   Users and Access → Integrations → App Store Connect API → Generate a key
   with **App Manager** role. Note down:
   - Issuer ID
   - Key ID
   - the downloaded `AuthKey_XXXXXXXXXX.p8` file's contents
   - your Team ID (top right of the Developer account page)
5. **Add these as GitHub repo secrets** (Settings → Secrets and variables →
   Actions → New repository secret):

   | Secret name | Value |
   |---|---|
   | `ASC_API_KEY_P8` | full contents of the `.p8` file |
   | `ASC_API_KEY_ID` | the Key ID |
   | `ASC_ISSUER_ID` | the Issuer ID |
   | `ASC_TEAM_ID` | your Team ID |

6. Push to `main` (or run the workflow manually from the Actions tab). CI
   builds and uploads a build to TestFlight automatically.
7. In App Store Connect → TestFlight, add yourself as an internal tester,
   install the **TestFlight** app on your iPhone, and install WristMouse
   from there — it'll sync to your paired Apple Watch.

If you'd rather build locally with your own Xcode instead of CI, see
[`watch-app/README.md`](watch-app/README.md).

## Status / honesty note

I wrote and pushed all of the code above, but I have no macOS/Xcode
environment to actually compile or run it, so treat the watch app and the
CI workflow as a solid first draft rather than verified-working — expect to
need a small fix or two (most likely signing-related flags) the first time
the GitHub Action runs. The Linux listener's logic is straightforward
Python and more likely to just work; `ydotool`'s exact CLI flags can still
vary by version, so double-check `ydotool --help` if `move`/`click` don't
do anything.

Scroll (Digital Crown) is wired up on the watch side but intentionally
left as a stub on the Linux side — see the `TODO` in `listener.py`.
