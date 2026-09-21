# Emul8or Networking

> Design document. Describes the intended protocol. Nothing here is implemented yet.

---

## 1. Requirements and priorities

Emul8or's networking exists to move one 400×240 video stream from a phone to another phone in the
same room, as fast as possible.

Priorities, in order:

1. **Latency.** Under 50 ms glass-to-glass added. This dominates every other decision.
2. **Reliability of connection**, not of every packet. A lost frame is a blink. A stalled stream is
   a broken game.
3. **Zero configuration.** The two phones should find each other without the user typing anything.
4. **Graceful failure.** Losing the secondary pauses the game; it does not crash it.

Explicitly **not** goals: internet play, more than two devices, NAT traversal, encryption of the
video payload (LAN-local, and crypto costs latency — revisit later).

---

## 2. Transport strategy

Three transports, in the order they are being built:

| Phase | Transport | Status |
| --- | --- | --- |
| 1 | Same Wi-Fi network (infrastructure LAN) | First target |
| 2 | Wi-Fi Direct (Wi-Fi P2P) | Later — roadmap phase 9 |
| 3 | Phone hotspot | Avoided; last resort only |

**Why LAN first.** Both phones are already associated with an access point, the sockets are ordinary
IPv4/IPv6, NSD discovery works out of the box, and debugging via ADB over the same network is easy.

**Why Wi-Fi Direct later.** It removes dependence on an access point — genuinely useful away from
home — but adds a whole class of failure: group negotiation, GO election, per-OEM quirks, and on
some devices it disconnects the existing Wi-Fi. Introducing that at the same time as a new video
pipeline would make failures impossible to attribute. The transport layer is abstracted from the
start so it can be swapped in cleanly.

**Why hotspot is avoided.** Tethering from the Primary costs it battery and CPU precisely when it is
running an emulator, it often forces 2.4 GHz, and carrier policy sometimes blocks it. It stays
documented as a manual fallback, not a supported path.

### Network quality expectations

| Network | Expectation |
| --- | --- |
| 5 GHz, uncongested | Target latency achievable |
| 5 GHz, busy | Usable; adaptive bitrate earns its keep |
| 2.4 GHz | Degraded; warn the user |
| Public / enterprise Wi-Fi | AP client isolation will likely block it entirely |
| Mesh with band steering | May work; devices on different bands add hops |

The app should detect band and link speed where the API allows, and warn before the user concludes
the software is broken.

---

## 3. Discovery

**Primary advertises, Secondary discovers.**

Android's `NsdManager` (mDNS/DNS-SD) handles this without extra dependencies.

```
Service type:  _emul8or._tcp
Service name:  Emul8or-<short-device-name>
Port:          control channel TCP port (ephemeral)

TXT records:
  v      protocol version, e.g. "1"
  dev    human-readable device name
  role   "primary"
  codec  supported codecs, e.g. "h264"
  st     session state: "open" | "busy"
```

Secondary lists discovered services and lets the user pick. With exactly one result and a previously
paired device, auto-connect.

### Manual fallback

Discovery fails more often than it should — AP client isolation, multicast filtering, VPNs, and
battery-optimised Wi-Fi all break mDNS. A manual path is mandatory, not optional:

- Primary displays its IP address and port prominently.
- Secondary offers direct IP:port entry.
- Optionally a short pairing code encoding the last octet plus port, to reduce typing.

When discovery fails, say *why* it probably failed. "No devices found" is useless; "No devices
found — this network may block device-to-device discovery. Try entering the IP shown on your primary
phone" is actionable.

---

## 4. Control channel

**TCP**, persistent, from Secondary to Primary's advertised port.

TCP for control because it is ordered and reliable and control traffic is tiny. Its head-of-line
blocking is disqualifying for video but irrelevant here.

### Framing

Length-prefixed binary messages:

```
┌────────────┬────────────┬──────────────────┐
│ len  u32be │ type   u8  │ payload (len-1)  │
└────────────┴────────────┴──────────────────┘
```

### Message types

| Type | Name | Direction | Purpose |
| --- | --- | --- | --- |
| 0x01 | `HELLO` | S → P | Protocol version, device info, decoder capabilities |
| 0x02 | `HELLO_ACK` | P → S | Accept, assign session id, echo negotiated parameters |
| 0x03 | `REJECT` | P → S | Refuse, with reason code |
| 0x10 | `PAIR_REQUEST` | P → S | Display this pairing code |
| 0x11 | `PAIR_CONFIRM` | S → P | User confirmed |
| 0x20 | `STREAM_CONFIG` | P → S | Codec, resolution, fps, SPS/PPS, UDP port |
| 0x21 | `STREAM_START` | P → S | Video is about to flow |
| 0x22 | `STREAM_STOP` | P → S | Video stopping, with reason |
| 0x30 | `PING` | both | Heartbeat, carries a timestamp |
| 0x31 | `PONG` | both | Heartbeat reply, echoes timestamp for RTT |
| 0x40 | `STATS` | S → P | Frames received/dropped, jitter, decode time |
| 0x41 | `REQUEST_KEYFRAME` | S → P | Decoder needs an IDR — e.g. after packet loss |
| 0x50 | `PAUSE` | P → S | Emulation paused |
| 0x51 | `RESUME` | P → S | Emulation resumed |
| 0x60 | `BYE` | both | Clean shutdown, with reason |

### Handshake

```
  Secondary                              Primary
      │                                     │
      │────────── HELLO (v, caps) ─────────►│
      │                                     │  version + capability check
      │◄──── HELLO_ACK (session, params) ───│
      │                                     │
      │◄────── PAIR_REQUEST (code) ─────────│  code shown on both screens
      │──────── PAIR_CONFIRM ──────────────►│  user confirms
      │                                     │
      │◄─── STREAM_CONFIG (sps/pps, port) ──│
      │──────── (binds UDP socket) ─────────│
      │◄──────── STREAM_START ──────────────│
      │                                     │
      │◄═══════ UDP video frames ═══════════│
      │───────── PING / PONG ──────────────►│  every 500 ms
```

Version mismatch produces `REJECT` with a specific reason, so the UI can say "your other phone is
running an older version of Emul8or" instead of "connection failed".

### Pairing

A four-digit code shown on the Primary, confirmed on the Secondary. This prevents accidentally
streaming to a housemate's phone on the same network. Remembered devices skip the prompt.

Lightweight by design — this is a LAN convenience feature, not a security boundary.

---

## 5. Video transport

**UDP**, unidirectional, Primary → Secondary.

TCP is wrong for this. A retransmitted frame arrives too late to display, and while TCP waits for
it, every subsequent frame is stuck behind it. The correct response to a lost packet in a realtime
stream is to drop the frame and move on.

### Packet format

Frames exceed the MTU, so NAL units are fragmented:

```
┌──────────┬──────────┬──────────┬──────────┬──────────┬───────────────┐
│ magic u16│ seq  u32 │ frame u32│ frag u16 │ flags u8 │ payload       │
└──────────┴──────────┴──────────┴──────────┴──────────┴───────────────┘

magic  0xE8 0x0R      sanity check
seq    per-packet, monotonic — detects loss
frame  frame number — groups fragments
frag   fragment index within the frame
flags  bit0 last-fragment, bit1 keyframe, bit2 config (SPS/PPS)
```

Payload sized so the total datagram stays under ~1200 bytes, comfortably below typical MTU and
tolerant of any encapsulation in the path.

### Loss handling

- Missing sequence number → mark the frame incomplete.
- Incomplete frame → discard it entirely. Feeding a partial frame to `MediaCodec` corrupts decoder
  state, and the artifacts persist for far longer than the dropped frame would have.
- Loss of a keyframe, or corruption persisting past a threshold → `REQUEST_KEYFRAME` on the control
  channel.
- Sustained loss → Primary reduces bitrate, then resolution.

### Why not RTP or WebRTC

RTP is a reasonable fit and standard, but brings a dependency and generality we do not need for one
stream between two devices we control on both ends.

WebRTC is tempting — it solves jitter, congestion control, and loss properly — but drags in a large
native dependency, adds signalling complexity, and its latency floor for a LAN link is not obviously
better than a purpose-built path. Worth revisiting if the hand-rolled approach proves fragile.

---

## 6. Jitter buffer

Minimal, and adaptive.

- Start at zero — display frames as they complete.
- If reordering or jitter is observed, grow to one or two frames (16–33 ms).
- Hard cap around 50 ms. Beyond that the latency cost exceeds the smoothness gain, which defeats the
  purpose of the project.
- Shrink when the network settles.

Every millisecond buffered is a millisecond of input lag. The bias is aggressively toward low
buffering, accepting the occasional dropped frame.

---

## 7. Heartbeat and disconnect detection

- `PING` every **500 ms** from both ends.
- Missing two consecutive `PONG`s (~1 s) → **DEGRADED**. Warn, keep streaming.
- Missing four (~2 s) → **DISCONNECTED**.
- TCP socket error → immediate **DISCONNECTED**, no waiting.

Round-trip time from ping/pong feeds the on-screen connection-quality indicator.

### On disconnect

**Primary:**
1. Pause emulation **immediately**.
2. Switch to the local dual-screen fallback layout.
3. Show a clear "secondary screen disconnected" state with a reconnect option.
4. Keep advertising, so the secondary can rejoin.
5. On rejoin: confirm with the user, then resume streaming.

**Secondary:**
1. Show "connection lost — waiting to reconnect".
2. Retry with backoff: 1 s, 2 s, 4 s, 8 s, then every 10 s.
3. Auto-resume on success.

The pause-before-relayout ordering is deliberate and stated again here because it is the single most
important behaviour in this document. The player has lost half their screen; the game must stop.

---

## 8. Bandwidth and adaptation

At native 400×240 / 60 fps, H.264 needs roughly **2–8 Mbit/s** for good quality. Trivial for 5 GHz,
fine for uncongested 2.4 GHz.

Adaptation ladder, in order:

1. Reduce bitrate (encoder parameter, instant, no visible reconfiguration).
2. Reduce frame rate to 30 fps.
3. Reduce resolution (requires encoder reconfigure and a new keyframe — visible hitch).
4. Warn the user that the network cannot sustain the stream.

Inputs: packet loss reported via `STATS`, RTT from ping/pong, and encoder output queue depth.

---

## 9. Security

LAN-local, so the threat model is modest — but not empty.

**In scope**
- Pairing code prevents accidental connection to the wrong device.
- Protocol version checking prevents malformed-input crashes from mismatched builds.
- All received packets are treated as untrusted: bounds-check every length field, never allocate
  based on an unvalidated size, and cap fragment reassembly buffers.

**Out of scope for now**
- Video payload encryption. It costs latency, and the content is a game screen on a local network.
  Revisit if remote play is ever considered — at which point the whole design changes anyway.
- Authentication beyond the pairing code.

**Permissions**

| Permission | Role | Why |
| --- | --- | --- |
| `INTERNET` | both | Sockets |
| `ACCESS_NETWORK_STATE` | both | Detect connectivity changes |
| `ACCESS_WIFI_STATE` | both | Band and link-speed diagnostics |
| `CHANGE_WIFI_MULTICAST_STATE` | Secondary | mDNS discovery on some devices |
| `NEARBY_WIFI_DEVICES` | both | Android 13+, for Wi-Fi Direct (phase 9) |
| `ACCESS_FINE_LOCATION` | both | Only if targeting pre-13 Wi-Fi Direct; avoid if possible |

Secondary mode needs **no storage permissions at all**. Keep it that way — it is part of what makes
the role viable on old hardware and easy to trust.

---

## 10. Testing

| Scenario | Expected |
| --- | --- |
| Both on 5 GHz, same AP | Full quality, under 50 ms |
| Both on 2.4 GHz | Works, degraded, user warned |
| Devices on different bands of one AP | Works; measure the extra hop |
| Secondary Wi-Fi toggled off | Pause within 2 s, clean fallback |
| Secondary airplane mode | Same |
| Secondary app backgrounded | Degraded, then reconnect on foreground |
| Primary Wi-Fi toggled off | Secondary shows waiting state, retries |
| AP reboots mid-session | Both recover when the network returns |
| Competing traffic (large download) | Adaptive bitrate holds the stream |
| AP with client isolation | Discovery fails with an explanatory message |
| Version mismatch | Clear rejection message |
| Walk out of range and back | Disconnect, then clean reconnect |

Latency is measured, not estimated: film both screens at 240 fps with a high-frame-rate camera and
count the frame delta. It is crude and it is the only honest number.
