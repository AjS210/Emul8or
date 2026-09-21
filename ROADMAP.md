# Emul8or Roadmap

The guiding rule: **get an unmodified Azahar building and running on the real target hardware before
writing a single line of Emul8or feature code.** Everything downstream depends on having a known-good
baseline to diff against. If phase 1 is skipped, every later bug is ambiguous — is it our streaming
code, or did the build never work?

Phases are ordered by dependency, not by excitement.

---

## Phase 0 — Project foundation

**Goal:** the repository is legible, legally sound, and describes what is being built.

- [x] Repository created.
- [x] GPL-2.0 `LICENSE` in place (inherited from Azahar).
- [x] `README.md` — project overview and the two modes.
- [x] `ROADMAP.md` — this document.
- [x] `docs/architecture.md`
- [x] `docs/legal.md`
- [x] `docs/networking.md`
- [x] `docs/testing-devices.md`
- [x] `docs/azahar-build-research.md`
- [x] `docs/development-environment.md`
- [ ] `CONTRIBUTING.md` and issue templates.
- [ ] Emul8or independent branding: name treatment, icon, colour palette. No Nintendo or Azahar marks.

**Exit criteria:** a newcomer can read the repo and understand the plan without asking questions.

---

## Phase 1 — Build unmodified Azahar

**Goal:** produce a working, *unmodified* Azahar APK from source and run it on the S24 Ultra.
**No Emul8or changes in this phase. None.**

Full execution checklist: [docs/upstream-integration.md](docs/upstream-integration.md) §5.

- [x] Add Azahar as a git remote named `upstream`, via `./scripts/setup-upstream.sh`.
- [x] Pin the baseline to tag **`2126.1.2`** (`9e6f523`) rather than tracking `master`. A moving base
      makes rebases unpredictable.
- [x] Verify the pinned tag's build config matches the research (`minSdk 29`, NDK `27.3.13750724`,
      compileSdk 35, targetSdk 37).
- [x] Decide vendoring strategy — **merge upstream history, pinned to a tag**. Submodule rejected
      because Azahar's Gradle project reaches up to the repo root for CMake. Reasoning in
      [docs/upstream-integration.md](docs/upstream-integration.md) §4.
- [x] Confirm Emul8or's `.gitignore` will not swallow upstream files on merge — checked, 0 collisions
      across 2,327 files.
- [ ] Install the toolchain per [docs/development-environment.md](docs/development-environment.md):
      JDK 17, Android SDK 35, NDK 27.3.13750724, CMake 3.30.3, Ninja, ccache.
- [ ] `git submodule update --init --recursive` — Azahar has ~35 submodules; a shallow or partial
      clone will fail the CMake configure step in confusing ways.
- [ ] Build: `cd src/android && ./gradlew assembleVanillaRelWithDebInfo`.
- [ ] Install on the S24 Ultra and confirm the app launches and reaches the game list.
- [ ] Confirm emulation actually runs, using a user-supplied, legally-dumped title. **No test content
      is committed to this repository.**
- [ ] Record the build wall-clock time, ccache hit rate, and every problem hit, in the research doc.

**Exit criteria:** an unmodified Azahar APK, built locally by us, boots a game on the S24 Ultra.

---

## Phase 2 — Emul8or fork baseline

**Goal:** rebrand and restructure without changing behaviour.

- [ ] Apply Emul8or branding: `applicationId`, app label, icon, splash. Independent assets only.
- [ ] Preserve all upstream GPL headers and attribution. Add an in-app "Open Source Licenses" screen
      naming Azahar and Citra and linking to sources.
- [ ] Set up a clean patch/branch structure so upstream rebases stay tractable.
- [ ] CI: GitHub Actions workflow that builds the APK on push. Model it on Azahar's
      `.github/workflows/build.yml` android job.
- [ ] Verify the rebranded build still boots a game — behaviour identical to phase 1.

**Exit criteria:** an "Emul8or" APK that is functionally identical to Azahar.

---

## Phase 3 — Role selection and local layouts

**Goal:** the APK knows what it is, and the local fallback layouts work.

- [ ] Role selection UI at launch: Primary Device / Secondary Screen. Persisted, and changeable later.
- [ ] Secondary Screen mode skips all emulator initialisation — no core boot, no ROM scan, no JIT.
      This is what makes Android 9 support feasible.
- [ ] Implement the three local fallback layouts:
  - [ ] Portrait: top above bottom.
  - [ ] Landscape A: top left, bottom right.
  - [ ] Landscape B: bottom left, top right.
- [ ] Layout switching from the in-game menu, and automatic switching on device rotation.
- [ ] Virtual controls render as an **overlay above** the screens, never as a third panel. Verify on
      the S24 Ultra's tall aspect ratio.
- [ ] Split minSdk by role — see phase 4.

**Exit criteria:** single-device play works in all three layouts with overlay controls.

---

## Phase 4 — Android 9 support for Secondary mode

**Goal:** the Galaxy Note 8 can be a second screen.

Upstream Azahar is `minSdk 29` (Android 10). The Note 8 is API 28. The plan is to lower the manifest
floor and gate the emulator by role at runtime.

- [ ] Lower `minSdk` to 28 and set the emulator-capable floor via a runtime check plus
      `<uses-sdk>` reasoning documented in the research doc.
- [ ] Audit every API-29+ call site in the code paths Secondary mode actually touches. Decoder,
      surface, and networking paths must be API 28-clean.
- [ ] Audit the native side: the JNI library still gets packaged into the APK even if never loaded.
      Confirm it does not load on Secondary. Consider an ABI/packaging split if size matters.
- [ ] Storage: Azahar leans on scoped storage and `MANAGE_EXTERNAL_STORAGE`. Secondary mode should
      need **no** storage permissions at all — verify and strip them for that role.
- [ ] Hard-block Primary mode on API 28 devices with a clear explanatory message, rather than
      letting it crash.
- [ ] Install and launch on the Note 8. Confirm Secondary mode runs.

**Exit criteria:** Emul8or installs and runs in Secondary Screen mode on Android 9.

**Fallback if this proves infeasible:** ship a separate thin `emul8or-screen` APK module targeting
API 28 that shares only the networking and decode code. Documented as plan B, not plan A — two APKs
contradicts the one-APK goal and should be a last resort.

---

## Phase 5 — Networking foundation

**Goal:** the two phones find each other and hold a connection. No video yet.

- [ ] NSD/mDNS service advertisement on Primary, discovery on Secondary.
- [ ] Manual IP entry as a fallback for hostile networks (AP isolation, enterprise Wi-Fi).
- [ ] TCP control channel: handshake, protocol version negotiation, capability exchange, heartbeat.
- [ ] Pairing confirmation with a short code, so you do not stream to a stranger's phone.
- [ ] Connection state machine: discovering → connecting → connected → degraded → disconnected.
- [ ] Clear connection status UI on both devices.

**Exit criteria:** the two phones connect, exchange heartbeats, and survive a brief Wi-Fi blip.

---

## Phase 6 — Top screen streaming

**Goal:** the actual product.

- [ ] Tap the top-screen framebuffer on Primary. Preferred path: render the top screen to a
      dedicated surface via Azahar's existing secondary-surface mechanism, so we reuse upstream
      plumbing instead of forking the renderer.
- [ ] `MediaCodec` H.264 hardware encode at 400×240 (or an integer multiple), low-latency /
      realtime configuration, no B-frames.
- [ ] Packetise and send over UDP with sequence numbers. Frame-level loss is preferable to
      head-of-line blocking.
- [ ] Decode on Secondary with `MediaCodec` straight to a `SurfaceView`.
- [ ] Target: **under 50 ms** glass-to-glass added latency. Measure it; do not guess.
- [ ] Adaptive bitrate driven by observed loss and queue depth.
- [ ] Primary shows bottom screen only while a secondary is connected.

**Exit criteria:** a game is playable across two phones, with input lag that is not distracting.

---

## Phase 7 — Disconnect handling and fallback

**Goal:** losing the second phone is an inconvenience, not a disaster.

- [ ] Detect disconnect quickly via heartbeat timeout — target under 2 seconds.
- [ ] On disconnect: **pause emulation immediately**, then switch to the local dual-screen layout.
      Pause first, so nothing happens in-game while the player is looking at a dead screen.
- [ ] Offer reconnection; resume seamlessly if the secondary returns.
- [ ] Handle the reverse case: Secondary losing Primary shows a clear "waiting to reconnect" state.
- [ ] Handle Primary backgrounding, screen-off, and incoming calls sensibly.

**Exit criteria:** yanking Wi-Fi from the secondary mid-game pauses cleanly and recovers.

---

## Phase 8 — Polish and hardening

- [ ] Audio stays on Primary; confirm A/V sync is not disturbed by the video path.
- [ ] Battery and thermal profiling on both devices. Streaming plus emulation is a heavy load.
- [ ] Stream-quality settings: resolution, bitrate, and a latency-vs-quality slider.
- [ ] Graceful degradation on a congested network.
- [ ] Reconnect-storm and edge-case testing.

---

## Phase 9 — Wi-Fi Direct

- [ ] Wi-Fi Direct (p2p) transport as an alternative to infrastructure Wi-Fi.
- [ ] Transport abstraction so LAN and Wi-Fi Direct are interchangeable behind one interface.
- [ ] Automatic transport selection with manual override.

Deliberately after streaming works over ordinary Wi-Fi. Debugging a new transport and a new video
pipeline simultaneously is a bad idea.

---

## Phase 10 — Controls and distribution

- [ ] Bluetooth controller support on Primary.
- [ ] Controller-aware layout: hide the on-screen overlay when a physical controller is connected.
- [ ] Customisable overlay: position, size, opacity.
- [ ] Signed release APKs on GitHub Releases, with checksums.
- [ ] Consider Obtainium support for update-tracking, as Azahar does.
- [ ] Google Play: evaluate much later. Play imposes storage-access restrictions that pushed Azahar
      into two build flavours; this is not a phase-one concern.

---

## Explicit non-goals

To keep scope honest, Emul8or is **not**:

- A general-purpose screen-mirroring app.
- A remote-play-over-the-internet service. LAN only, for latency reasons.
- A place to obtain games, keys, or system files.
- A hard fork that diverges from Azahar. The intent is to track upstream and, where a change is
  general-purpose and welcome, offer it back.
- Three-or-more-device capable. Two devices, one top screen, one bottom screen.
