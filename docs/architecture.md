# Emul8or Architecture

> Design document. Describes the intended system. Nothing here is implemented yet.

---

## 1. Core idea

A Nintendo 3DS has two screens. Emul8or splits them across two Android phones:

```
        ┌────────────────────────┐              ┌────────────────────────┐
        │   SECONDARY (Note 8)   │              │   PRIMARY (S24 Ultra)  │
        │                        │              │                        │
        │   ┌────────────────┐   │   ◄── Wi-Fi  │   ┌────────────────┐   │
        │   │  3DS TOP       │   │    H.264     │   │  3DS BOTTOM    │   │
        │   │  400 x 240     │   │    video     │   │  320 x 240     │   │
        │   │  (video only)  │   │              │   │  (touch)       │   │
        │   └────────────────┘   │              │   └────────────────┘   │
        │                        │              │   [virtual controls    │
        │   no emulation         │              │    overlaid on top]    │
        │   no input             │              │                        │
        └────────────────────────┘              └────────────────────────┘
                                                 runs emulator, audio,
                                                 saves, settings, input
```

Everything expensive happens on Primary. Secondary decodes video and nothing else. That asymmetry is
the whole point — it is what lets a 2017 phone be useful.

---

## 2. One APK, two roles

A single APK ships both roles. Role is chosen at launch and persisted; it can be changed later.

| | Primary Device | Secondary Screen |
| --- | --- | --- |
| Runs emulator core | Yes | **No** |
| Loads native `libcitra-android.so` | Yes | **No** |
| Displays | Bottom screen | Top screen |
| Touch input | Yes | **No** |
| Virtual controls | Yes | **No** |
| Audio | Yes | No |
| Saves / settings | Yes | No |
| Needs storage permission | Yes | **No** |
| Network role | Server / sender | Client / receiver |
| Minimum Android | 10 (API 29) | 9 (API 28) — target |

The critical structural requirement: **Secondary mode must never touch emulator initialisation.**
Not the native library load, not the ROM scan, not the settings-backed config. This is not an
optimisation — it is the mechanism by which Secondary mode can run on an OS version the emulator
itself cannot support. Any accidental coupling collapses that.

---

## 3. Module layout

Proposed structure, layered on the Azahar source tree:

```
emul8or/
├─ src/android/app/                     ← Azahar's Android app (upstream, modified)
│  └─ .../org/citra/citra_emu/          ← upstream packages, left in place for rebase sanity
│
└─ emul8or/                             ← new, Emul8or-owned code
   ├─ core/          role selection, persistence, app-wide state
   ├─ net/           discovery, control channel, transport abstraction
   ├─ stream/
   │  ├─ encoder/    MediaCodec H.264 encode  (Primary)
   │  └─ decoder/    MediaCodec H.264 decode  (Secondary)
   ├─ primary/       primary-mode UI, layout manager, overlay integration
   └─ secondary/     secondary-mode UI — a SurfaceView and a status overlay
```

Keeping Emul8or code in its own tree, rather than scattered through upstream packages, is what makes
rebasing onto new Azahar releases survivable. Upstream touch points should be few, small, and each
one documented.

The `emul8or/secondary` and `emul8or/stream/decoder` modules must compile and run against API 28.
Enforce this with a lint baseline or a dedicated Gradle module with its own `minSdk`, not with
discipline alone.

---

## 4. Where Emul8or hooks into Azahar

Azahar already ships a secondary-display subsystem intended for physical external displays — DeX,
HDMI, Chromecast-style Presentation targets. The relevant upstream pieces:

| Upstream file | What it does |
| --- | --- |
| `display/SecondaryDisplay.kt` | `Presentation` on a secondary `Display`, plus a `VirtualDisplay` |
| `display/ScreenLayout.kt` | `SecondaryDisplayLayout` enum — `TOP_SCREEN`, `BOTTOM_SCREEN`, … |
| `NativeLibrary.kt` | `secondarySurfaceChanged(Surface)` / `secondarySurfaceDestroyed()` |
| `jni/native.cpp` | `s_secondary_surface`, `secondary_window`, dual `EmuWindow_Android` |
| `core/frontend/framebuffer_layout.h` | `Layout::AndroidSecondaryLayout(w, h)` |

Azahar therefore already renders the top screen to a **second independent surface**, with a second
`EmuWindow_Android` and its own framebuffer layout, driven by `SecondaryDisplayLayout::TOP_SCREEN`.

**This is the integration seam, and it is a gift.** Emul8or does not need to fork the renderer. It
needs to hand the emulator a surface that happens to be a video encoder's input surface rather than
a physical display's:

```
 Azahar renders top screen ──► secondary Surface
                                     │
        (upstream: Presentation on a physical display)
        (Emul8or:  MediaCodec encoder input surface)
                                     │
                                     ▼
                          H.264 ──► UDP ──► Wi-Fi
                                                │
                                                ▼
                      Secondary: MediaCodec decode ──► SurfaceView
```

`MediaCodec.createInputSurface()` yields exactly the kind of `Surface` that
`NativeLibrary.secondarySurfaceChanged()` already accepts. The encode path then stays entirely on
the GPU — no readback to CPU memory, which is the difference between a viable latency budget and an
unusable one.

**This must be validated early in phase 6.** The assumption to test: that the native side accepts an
encoder input surface as readily as a display surface, and that EGL/Vulkan context creation against
it succeeds. If it does not, the fallback is a `SurfaceTexture` intermediary or a readback path —
both worse, so find out early.

---

## 5. Video pipeline

**Primary (encode)**

1. Emulator renders the top screen to the secondary surface (see above).
2. `MediaCodec` in surface-input mode, H.264 (`video/avc`).
3. Config: realtime priority, no B-frames, short keyframe interval (1–2 s), baseline or main profile.
4. Output buffers → packetiser → UDP.

**Secondary (decode)**

1. UDP receive → jitter buffer (small — a few frames at most; a big buffer trades exactly the thing
   we are optimising for).
2. `MediaCodec` decode directly to a `SurfaceView`.
3. Present.

**Resolution.** The 3DS top screen is 400×240. Streaming at native resolution keeps bandwidth
trivial and encode cheap. Higher internal resolutions (Azahar renders at scaled resolution) should
be downscaled before encode unless the user opts into more. Bandwidth at native is on the order of
2–8 Mbit/s, which any 5 GHz network handles comfortably.

**Latency budget** — target under 50 ms added, glass to glass:

| Stage | Budget |
| --- | --- |
| Encode | 8–16 ms |
| Network (5 GHz LAN) | 2–10 ms |
| Jitter buffer | 0–16 ms |
| Decode | 8–16 ms |
| Compose / present | ~16 ms |

Tight but achievable on a 5 GHz network. On 2.4 GHz, or a congested access point, expect worse — the
app should surface this rather than silently degrading.

**Codec choice.** H.264 first: universally hardware-accelerated, including on a 2017 Note 8. HEVC
and AV1 are better compressors but the encode/decode latency and device support are worse. This
project optimises for latency, not bitrate.

---

## 6. Connection state machine

Shared by both roles; see [networking.md](networking.md) for the wire protocol.

```
      IDLE
        │  user selects role
        ▼
   DISCOVERING ──────────► (no peer found) ──► IDLE / manual IP entry
        │  peer found
        ▼
   CONNECTING  ──────────► (handshake fails) ──► ERROR
        │  handshake ok
        ▼
    CONNECTED ◄───────────┐
        │                 │ heartbeat recovers
        │ heartbeat late  │
        ▼                 │
     DEGRADED ────────────┘
        │  timeout exceeded
        ▼
  DISCONNECTED ──► Primary: PAUSE, then local dual-screen layout
                   Secondary: "waiting to reconnect"
```

**On disconnect, Primary pauses emulation first, then changes layout.** The ordering matters: the
player has just lost half their screen, and the game must not continue while they work out what
happened.

---

## 7. Display layouts

### Dual-phone mode

- **Primary:** bottom screen only, filling the display, with the control overlay above it.
- **Secondary:** top screen only, letterboxed to preserve the 5:3 aspect ratio.

### Local fallback layouts

Used when no secondary is connected. Three required layouts:

```
  1. PORTRAIT              2. LANDSCAPE A            3. LANDSCAPE B
  ┌───────────────┐        ┌─────────┬─────────┐     ┌─────────┬─────────┐
  │  TOP  (400x240)│       │  TOP    │ BOTTOM  │     │ BOTTOM  │  TOP    │
  ├───────────────┤        │         │         │     │         │         │
  │ BOTTOM(320x240)│       └─────────┴─────────┘     └─────────┴─────────┘
  └───────────────┘
   controls overlaid       controls overlaid          controls overlaid
```

Landscape A and B are mirror images so the player can put the touch screen under their dominant
hand. That is the entire reason both exist.

Azahar's existing `ScreenLayout` enum covers similar ground (`LARGE_SCREEN`, `SIDE_SCREEN`,
`PortraitScreenLayout.TOP_FULL_WIDTH`). Where upstream layouts satisfy a requirement, use them —
do not reimplement. The gap to fill is explicit left/right swap control and Emul8or's own layout
selection UI.

### Control overlay

**Non-negotiable:** virtual controls are drawn *over* the emulator screens, in a transparent layer.
They never occupy a reserved band that shrinks the game view.

Azahar's `overlay/InputOverlay.kt` already works this way. Preserve that behaviour and resist any
layout approach that reserves space for controls.

---

## 8. Threading

**Primary**

| Thread | Work |
| --- | --- |
| Emulator core | Azahar's existing threads — untouched |
| Encoder output | Drain `MediaCodec` output buffers |
| Network send | Packetise and transmit |
| Control channel | Heartbeat and messages |
| UI | Bottom screen, overlay, status |

**Secondary**

| Thread | Work |
| --- | --- |
| Network receive | UDP receive → jitter buffer |
| Decoder | Feed `MediaCodec`, release to surface |
| Control channel | Heartbeat |
| UI | Surface, status overlay |

Nothing on the emulator's critical path may block on the network. Encoder input is a surface, so the
renderer never waits for the encoder; the send path must be similarly decoupled. If the network
stalls, **drop frames** — never stall the emulator. A stuttering top screen is survivable; a
stuttering emulator is not.

---

## 9. Failure modes

| Failure | Response |
| --- | --- |
| Secondary disconnects | Pause emulation, switch to local layout, offer reconnect |
| Network congestion | Lower bitrate, then resolution; surface a warning |
| Encoder init fails | Refuse dual-phone mode with a clear message; stay local |
| Decoder init fails | Secondary reports incompatibility to Primary, which stays local |
| Primary backgrounded | Pause emulation; tell Secondary |
| Secondary backgrounded | Notify Primary; treat as degraded, not disconnected |
| Version mismatch | Reject at handshake with a version-specific message |
| Wi-Fi AP isolation | Discovery fails; fall back to manual IP, explain the likely cause |
| Primary on API 28 | Blocked at role selection with an explanation |

---

## 10. Open questions

Unresolved, to be answered by prototyping:

0. **Does the secondary-display feature work at all on the target hardware?** Testable *today* on a
   stock Play Store Azahar install, with no build required — see
   [secondary-display-test.md](secondary-display-test.md). Notably, upstream describes the feature as
   supporting a secondary screen "wired or wireless (Chromecast, Miracast)", which means Azahar
   already tolerates a second display with network latency in the path. Encouraging for §4.
1. Does `NativeLibrary.secondarySurfaceChanged()` accept a `MediaCodec` input surface without
   modification? **Highest-risk unknown in the project.** Test first.
2. Does the secondary `EmuWindow_Android` render at the encoder's requested resolution, or at the
   emulator's internal scale? Determines whether a scaling stage is needed.
3. Can the Note 8's decoder sustain 60 fps at 400×240 with acceptable latency? Likely yes; measure.
4. Is upstream's `SecondaryDisplayLayout::TOP_SCREEN` sufficient, or is a new layout mode needed?
5. How should Azahar's own Presentation-based secondary-display feature and Emul8or's network
   secondary coexist? Probably mutually exclusive — pick one target.
6. Should the control channel be TCP, or a reliable-ordered lane inside the same UDP socket? TCP
   is simpler; a single socket is friendlier to NAT and firewalls. Start with TCP.
