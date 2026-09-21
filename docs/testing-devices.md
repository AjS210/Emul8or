# Test Devices

The devices Emul8or is developed and validated against.

---

## Primary reference device

**Samsung Galaxy S24 Ultra** — `SM-S928U1`

| | |
| --- | --- |
| Model | SM-S928U1 (US unlocked) |
| Android | 16 |
| SoC | Snapdragon 8 Gen 3 for Galaxy |
| CPU | 1× Cortex-X4 3.39 GHz, 3× A720 3.1 GHz, 2× A720 2.9 GHz, 2× A520 2.2 GHz |
| GPU | Adreno 750 — Vulkan 1.3, OpenGL ES 3.2 |
| RAM | 12 GB |
| Display | 6.8" 3120×1440 (~19.5:9), 120 Hz LTPO AMOLED |
| Wi-Fi | Wi-Fi 7, 2.4 / 5 / 6 GHz |
| ABI | arm64-v8a |

**Why this device.** Comfortably exceeds Azahar's requirements (Snapdragon 835 or better, OpenGL ES
3.2 / Vulkan 1.1), so emulation performance will not confound streaming measurements. Adreno 750
supports `libadrenotools` custom driver loading, which Azahar uses. Wi-Fi 7 with 6 GHz gives the
best-case network.

**Watch for:**
- **Android 16 is newer than Azahar's `targetSdk 37` era assumptions.** Expect background-execution
  and permission-model surprises, particularly around holding a foreground service while streaming.
- The very tall 19.5:9 aspect ratio makes layout bugs obvious — good for catching them, and a strict
  test of the "controls overlay must not steal screen area" rule.
- 120 Hz display vs. 60 fps stream: verify the compositor does not add a frame of latency.
- Samsung's aggressive battery optimisation may kill background sockets. Test with the app both
  foregrounded and briefly backgrounded.

---

## Secondary reference device

**Samsung Galaxy Note 8** — `SM-N950U`

| | |
| --- | --- |
| Model | SM-N950U (US, Snapdragon) |
| Android | 9 (Pie) — **API 28** |
| SoC | Snapdragon 835 |
| CPU | 4× Kryo 280 2.35 GHz, 4× Kryo 280 1.9 GHz |
| GPU | Adreno 540 — Vulkan 1.0, OpenGL ES 3.2 |
| RAM | 6 GB |
| Display | 6.3" 2960×1440 (18.5:9) Super AMOLED |
| Wi-Fi | Wi-Fi 5 (802.11ac), 2.4 / 5 GHz |
| ABI | arm64-v8a |

**Why this device.** It is the phone in the drawer. That is the point: the value proposition of
Emul8or is that a retired phone becomes a second screen. If it needed a good phone, the project would
be pointless.

**The central compatibility problem.** Upstream Azahar is `minSdk 29` (Android 10). The Note 8 is
API 28. This device therefore **cannot run Primary mode** without lowering the floor, and lowering
it for the emulator is not worth attempting.

The plan is a role split: lower the manifest `minSdk` to 28 so the app installs, and gate Primary
mode behind a runtime API-level check. Secondary mode only decodes video and draws a surface —
`MediaCodec`, `SurfaceView`, and `NsdManager` all predate API 28 comfortably. Analysis in
[azahar-build-research.md](azahar-build-research.md), work items in roadmap phase 4.

**Watch for:**
- **Adreno 540 H.264 decode latency.** 400×240 is a tiny stream, so it should be far inside the
  hardware's capability, but this is the number to measure first on this device.
- Android 9 Wi-Fi power saving is more aggressive than modern releases and may add jitter. Check
  whether a `WifiLock` in high-performance mode helps.
- 6 GB RAM, 2017 hardware — keep the Secondary path lean. It should be a handful of megabytes of
  buffers.
- Battery health on a phone this old will be poor; test with it plugged in, then unplugged, and
  report expected runtime honestly.
- Android 9 predates scoped storage. Secondary mode should request **no** storage permissions,
  sidestepping the issue entirely.

---

## Test matrix

### Role coverage

| Device | Primary | Secondary |
| --- | --- | --- |
| Galaxy S24 Ultra (Android 16) | Required | Required |
| Galaxy Note 8 (Android 9) | Blocked by design — verify the block is graceful | Required |

Testing the S24 Ultra as Secondary matters too: it isolates whether a problem is protocol-level or
Note-8-specific.

### Network conditions

| Condition | Both devices |
| --- | --- |
| 5 GHz, same AP, uncongested | Baseline — record the best-case latency here |
| 5 GHz, congested | Adaptive bitrate must hold |
| 2.4 GHz | Degraded but usable; warning shown |
| Mixed bands (S24 on 6 GHz, Note 8 on 5 GHz) | Works; measure the penalty |
| Mesh network with band steering | Works or fails with a clear message |
| AP with client isolation | Discovery fails with an explanatory message |

Note the asymmetry: the S24 Ultra supports 6 GHz, the Note 8 does not. Mixed-band operation is the
realistic everyday case, not an edge case.

### Layouts (Primary, single-device fallback)

| Layout | S24 Ultra |
| --- | --- |
| Portrait — top above bottom | Required |
| Landscape A — top left, bottom right | Required |
| Landscape B — bottom left, top right | Required |
| Rotation mid-game | No crash, no lost frames |
| Controls overlay above screens | Verify no reserved band appears |

### Disconnect and recovery

| Event | Expected |
| --- | --- |
| Secondary Wi-Fi off | Primary pauses within 2 s, switches to local layout |
| Secondary airplane mode | Same |
| Secondary app force-stopped | Same |
| Secondary backgrounded briefly | Degraded, recovers on foreground |
| Secondary walks out of range | Disconnect, then clean reconnect on return |
| Primary Wi-Fi off | Secondary shows waiting state and retries |
| AP reboot | Both recover |
| Rapid disconnect/reconnect cycling | No leaks, no zombie sockets, no duplicate streams |

---

## What to measure

Record these on every meaningful change. Numbers, not impressions.

**Latency** — glass to glass, camera at 240 fps, count frames between the primary's bottom screen
updating and the secondary's top screen updating. Target: under 50 ms added.

**Frame rate** — sustained fps at the secondary, plus dropped-frame count over a 10-minute session.

**Bitrate** — actual bytes/second on the wire, versus the configured target.

**CPU and thermals** — `dumpsys` and on-device thermal status on both phones after 30 minutes. The
question is whether the S24 Ultra throttles when doing emulation and encoding at once.

**Battery** — percentage drain per hour, both devices, screen on.

**Memory** — peak RSS for the Secondary role. It should be small, and staying small is a feature.

---

## ADB workflow

Both devices on the same network; connect both over ADB simultaneously.

```bash
# Enumerate
adb devices -l

# Target a specific device by serial
adb -s <primary-serial>   install -r emul8or.apk
adb -s <secondary-serial> install -r emul8or.apk

# Wireless ADB, so the phones are not tethered to the bench
adb -s <serial> tcpip 5555
adb connect <device-ip>:5555

# Tagged logs from both, in parallel
adb -s <primary-serial>   logcat -s Emul8or:V Citra:V MediaCodec:V &
adb -s <secondary-serial> logcat -s Emul8or:V MediaCodec:V &
```

Wireless ADB matters here: testing Wi-Fi behaviour while a phone is on USB masks power-management
effects that only appear on battery.

Android 9 on the Note 8 predates `adb pair`; use classic `adb tcpip` there.

---

## Devices to add later

Not blocking, but broadening coverage would help:

- A mid-range modern phone (Snapdragon 7-series) as Primary — the realistic-hardware case.
- A non-Samsung device, to shake out One UI-specific behaviour.
- A tablet as Secondary — a large top screen is an appealing configuration.
- Anything with a Mali GPU. Azahar specifically calls out Mali optimisation, and Adreno-only testing
  will hide an entire class of bug.
- An Android 10 or 11 device, to cover the gap between our two extremes.
