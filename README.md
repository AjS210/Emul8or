# Emul8or

**Two phones. Two screens. One handheld.**

Emul8or is an open-source Android application that turns a pair of Android phones into a
dual-screen Nintendo 3DS-style handheld. One phone runs the emulation and shows the bottom
touchscreen; a second phone, over Wi-Fi, becomes the top screen.

A single APK ships both roles. You pick the role when you launch the app.

> **Status: pre-alpha / evaluation phase.** No emulator code has landed yet. An existing
> proof-of-concept ([Azahar PR #2343](https://github.com/azahar-emu/azahar/pull/2343) plus a companion
> viewer app) already demonstrates phone-to-phone 3DS streaming. **Before building anything, that
> should be tried** — see [docs/try-existing-solution-first.md](docs/try-existing-solution-first.md).
> If it turns out to be good enough, this project is unnecessary and that is a good outcome. See
> [ROADMAP.md](ROADMAP.md) for the plan if it is not.

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

**This has been verified on the target hardware.** On 2026-09-22, stock Azahar on the S24 Ultra was
confirmed rendering the 3DS top screen to a TV while the bottom screen stayed on the phone — both
full-screen, each with its own independently configurable layout, controls overlaid on the bottom
screen. Details and design consequences:
[docs/secondary-display-test.md](docs/secondary-display-test.md).

Full analysis: [docs/azahar-build-research.md](docs/azahar-build-research.md).

Upstream is tracked as a git remote pinned to a tested release tag (currently **`2126.1.2`**). Set it
up with:

```bash
./scripts/setup-upstream.sh
```

The integration plan — including the rule that unmodified Azahar must build and run on real hardware
before any Emul8or code is written — is in
[docs/upstream-integration.md](docs/upstream-integration.md).

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
| **[docs/try-existing-solution-first.md](docs/try-existing-solution-first.md)** | **Do this first.** A 20-minute test of the existing proof-of-concept. It may make this project unnecessary |
| [docs/secondary-display-test.md](docs/secondary-display-test.md) | ✅ **Core assumption validated on hardware** — top screen on TV, bottom on phone, confirmed 2026-09-22 |
| **[docs/getting-started-windows.md](docs/getting-started-windows.md)** | **Then start here.** Beginner step-by-step: build the app on Windows and install it on your phone |
| [ROADMAP.md](ROADMAP.md) | Phased delivery plan, from unmodified Azahar build to dual-phone play |
| [docs/architecture.md](docs/architecture.md) | Roles, modules, video pipeline, state machine, layouts |
| [docs/legal.md](docs/legal.md) | GPL compliance, asset prohibitions, trademark policy, contributor rules |
| [docs/networking.md](docs/networking.md) | Discovery, handshake, transport, protocol, disconnect handling |
| [docs/testing-devices.md](docs/testing-devices.md) | Test matrix, device profiles, ADB workflow, what to measure |
| [docs/azahar-build-research.md](docs/azahar-build-research.md) | Upstream build system, minSdk analysis, integration seams |
| [docs/upstream-integration.md](docs/upstream-integration.md) | Baseline pin, vendoring strategy, phase-1 build checklist |
| [docs/feature-auto-hide-overlay.md](docs/feature-auto-hide-overlay.md) | Spec: hide touch controls automatically when a gamepad connects |
| [docs/feature-touch-gestures.md](docs/feature-touch-gestures.md) | Spec: 3-finger tap to toggle the overlay, and other multi-touch gestures |
| [docs/prior-art-pr2343.md](docs/prior-art-pr2343.md) | Existing phone-to-phone streaming PR against Azahar — proves the core mechanism, hands us two bug fixes |
| [docs/ds-support-research.md](docs/ds-support-research.md) | Why Azahar's dual-screen code can't be reused for DS, and what already exists (DualMelon, melonDS) |
| [docs/development-environment.md](docs/development-environment.md) | Exact toolchain versions and setup |

---

## Contributing

The project is in its planning phase. The most useful contributions right now are review of the
architecture and networking designs.

**AI-assisted contributions are welcome, with disclosure and human review.** A human must own the
change and be able to answer questions about it; the licensing and content rules in
[docs/legal.md](docs/legal.md) apply in full either way.

### Relationship to Azahar

Upstream Azahar has a much stricter [AI use
policy](https://github.com/azahar-emu/azahar/blob/master/AI-POLICY.md) for their own repository. That
is a contribution rule for Azahar, not a licence restriction — it does not limit Emul8or's GPL rights
to use, modify, and distribute their code.

Because our policy is incompatible with theirs, **Emul8or is a downstream-only fork. We do not open
pull requests, file issues, or request support on the Azahar repository.** Their project, their
rules; the GPL gives us the code, not their maintainers' time. Please do not report Emul8or bugs to
Azahar. If you hit something that reproduces on a stock Azahar build, report it there yourself, in
your own words — not on Emul8or's behalf.

We credit Azahar and Citra prominently and gratefully. Full reasoning in
[docs/legal.md](docs/legal.md).
