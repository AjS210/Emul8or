# Emul8or

**Two phones. Two screens. One handheld.**

Emul8or is an open-source Android application that turns a pair of Android phones into a
dual-screen Nintendo 3DS-style handheld. One phone runs the emulation and shows the bottom
touchscreen; a second phone, over Wi-Fi, becomes the top screen.

A single APK ships both roles. You pick the role when you launch the app.

> **Status: pre-alpha / documentation phase.** No emulator code has landed yet. This repository
> currently contains the design, research, and planning documents for the project. See
> [ROADMAP.md](ROADMAP.md) for what is being built and in what order.

---

## The two modes

### Primary Device mode

Runs everything.

- Runs the emulator core and the game.
- Displays the **3DS bottom touchscreen** locally, at full size.
- Handles touch input, virtual on-screen controls, audio, save files, and settings.
- Encodes and streams the **3DS top screen** to the secondary phone over Wi-Fi.
- If the secondary phone disconnects, the emulator **pauses** and the primary falls back to a
  local dual-screen layout so play can continue on one device.

### Secondary Screen mode

Runs nothing. It is a dumb display.

- Same APK, different role.
- Connects to the primary phone over the local network.
- Displays the **3DS top screen only**.
- Receives video. That's it.
- Does **not** run emulation.
- Does **not** handle touch or controls.

This asymmetry is deliberate. The secondary device needs almost no horsepower, which is what makes
an older phone a viable second screen.

---

## Display layouts

**Dual-phone mode**

| Device    | Shows                     |
| --------- | ------------------------- |
| Primary   | Bottom screen (touch)     |
| Secondary | Top screen (video only)   |

**Local fallback mode** — used when no secondary device is connected. Three layouts are required:

1. **Portrait** — top screen above, bottom screen below.
2. **Landscape A** — top screen left, bottom screen right.
3. **Landscape B** — bottom screen left, top screen right.

In every mode, the virtual controls are an **overlay drawn on top of the emulator screens** — never
a separate third panel that steals screen area.

---

## Target hardware

The first two devices Emul8or is being developed against:

| Role      | Device                  | Model      | Android |
| --------- | ----------------------- | ---------- | ------- |
| Primary   | Samsung Galaxy S24 Ultra| SM-S928U1  | 16      |
| Secondary | Samsung Galaxy Note 8   | SM-N950U   | 9       |

The Note 8 running Android 9 (API 28) is below upstream Azahar's `minSdk 29`. Emul8or plans to split
the minimum SDK by role so old phones can still serve as screens. See
[docs/testing-devices.md](docs/testing-devices.md) and
[docs/azahar-build-research.md](docs/azahar-build-research.md).

---

## Networking

Same-Wi-Fi LAN first. Wi-Fi Direct later. Hotspot avoided where possible. Discovery via NSD/mDNS,
control channel over TCP, video over UDP. Details in [docs/networking.md](docs/networking.md).

---

## Emulator base

Emul8or builds on **[Azahar](https://github.com/azahar-emu/azahar)**, the actively-maintained
open-source 3DS emulator that succeeded Citra (formed from the merge of PabloMK7's Citra fork and
Lime3DS). Azahar is GPL-2.0-or-later.

Azahar already contains a secondary-display subsystem — `SecondaryDisplay.kt`, the
`secondarySurfaceChanged(Surface)` JNI entry point, and `Layout::AndroidSecondaryLayout` — built for
physical external displays (HDMI/DeX/Presentation API). Emul8or's core insight is that **a phone
over Wi-Fi can be made to look like one more secondary surface**, which means the integration seam
already exists upstream and we do not need to invent one.

Full analysis: [docs/azahar-build-research.md](docs/azahar-build-research.md).

---

## Legal

**Emul8or ships no copyrighted content. Ever.**

This repository and every release of it contains **no** ROMs, games, BIOS images, firmware dumps,
encryption keys, system archives, Nintendo artwork, Nintendo logos, or any other console asset.
Users supply their own files, dumped from hardware they legally own.

Emul8or is an independent project. It is not affiliated with, endorsed by, or associated with
Nintendo. "Nintendo" and "Nintendo 3DS" are trademarks of Nintendo. Emul8or has its own independent
branding and does not use Azahar's or Citra's logos or marks.

Emul8or is licensed **GPL-2.0-or-later**, matching Azahar. Full details and contributor rules:
[docs/legal.md](docs/legal.md).

---

## Distribution

Sideloaded APK first. Google Play much later, if ever, and only if it is appropriate.

---

## Documentation

| Document | What's in it |
| --- | --- |
| [ROADMAP.md](ROADMAP.md) | Phased delivery plan, from unmodified Azahar build to dual-phone play |
| [docs/architecture.md](docs/architecture.md) | Roles, modules, video pipeline, state machine, layouts |
| [docs/legal.md](docs/legal.md) | GPL compliance, asset prohibitions, trademark policy, contributor rules |
| [docs/networking.md](docs/networking.md) | Discovery, handshake, transport, protocol, disconnect handling |
| [docs/testing-devices.md](docs/testing-devices.md) | Test matrix, device profiles, ADB workflow, what to measure |
| [docs/azahar-build-research.md](docs/azahar-build-research.md) | Upstream build system, minSdk analysis, integration seams |
| [docs/development-environment.md](docs/development-environment.md) | Exact toolchain versions and setup |

---

## Contributing

The project is in its planning phase. The most useful contributions right now are review of the
architecture and networking designs.

Note that upstream Azahar has a strict [AI use
policy](https://github.com/azahar-emu/azahar/blob/master/AI-POLICY.md). Any Emul8or change intended
to be upstreamed to Azahar must comply with it. See [docs/legal.md](docs/legal.md).
