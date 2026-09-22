# Prior Art: Azahar PR #2343 — phone-to-phone screen streaming

**This document exists to correct an error in Emul8or's earlier documentation, and to capture what is
by far the most valuable piece of prior art available to this project.**

- **PR:** [azahar-emu/azahar#2343](https://github.com/azahar-emu/azahar/pull/2343)
- **Author:** [Ufoex](https://github.com/Ufoex)
- **Opened:** 2026-07-24 · **Last updated:** 2026-09-20 · **State: open, unreviewed**
- **Size:** 6 commits, 10 files, +447 / −1
- **Companion viewer app:** [Ufoex/azahar-viewer](https://github.com/Ufoex/azahar-viewer) (separate repo)

---

## 1. The correction

Emul8or's `legal.md` previously asserted:

> *"Azahar would not merge that under any policy, because two-phone Wi-Fi streaming is a different
> product rather than a missing Azahar feature."*

**That claim was unsupported and is now retracted.** It was an inference from the absence of the
feature, not a finding. No maintainer has ever said this.

The evidence points the other way:

- Someone has already built phone-to-phone streaming **against Azahar**, and it works on real
  hardware.
- The PR is **open**, not closed or rejected.
- Related feature [issue #351 "Android external display support"](https://github.com/azahar-emu/azahar/issues/351)
  was **closed as completed** — meaning multi-display output is something Azahar *wanted* and
  *shipped*. That is the subsystem Emul8or plans to build on.

What is actually true is narrower and better evidenced: **Azahar's maintainers have not engaged with
this PR at all.** See §4.

---

## 2. What the PR does

Strikingly close to Emul8or's design, arrived at independently. Three parts:

### Commit 1 — `Config::Reload()` pointer-vs-content bug

`Settings::Keys::keys_array` holds `const char*`, and `android_config_omitted_keys` references the
same named constants separately. `std::ranges::find` compares **pointer identity, not string
content**, so the omitted-keys check silently fails and trips `ASSERT_MSG` on the **first settings
reload of any fresh Android install**. Fixed by comparing via `std::string_view`.

### Commit 2 — secondary window size clamped to the primary layout's minimum

`UpdateCurrentFramebufferLayout()` clamps width/height to `GetMinimumSizeFromLayout()` — a minimum
sized for the *primary* combined top+bottom window. On Android the secondary window's layout is then
fully replaced by `AndroidSecondaryLayout()` using the Surface's real size, but the earlier clamp has
already inflated the values fed into it, **offsetting `bottom_screen` and silently breaking
touch-to-framebuffer mapping** on any secondary window smaller than that minimum.

```cpp
#ifdef ANDROID
    if (!is_secondary) {
        width  = std::max(width,  min_size.first);
        height = std::max(height, min_size.second);
    }
#else
    width  = std::max(width,  min_size.first);
    height = std::max(height, min_size.second);
#endif
```

### Commit 3 — network streaming

An in-game menu entry, *"Stream Bottom Screen to Device…"*, which:

- Hands a **`MediaCodec` H.264 encoder input Surface** directly to
  `NativeLibrary.secondarySurfaceChanged()` — **"so the GPU renders straight into it with no CPU
  readback."**
- Serves it over a length-prefixed **TCP** protocol.
- Advertises via **NSD/mDNS** (`_azahar._tcp.`) so the viewer needs no IP address.
- Forwards touch **back** from the viewer into `onSecondaryTouchEvent` / `onSecondaryTouchMoved`.

Files touched: `NetworkStreamer.kt` (new, 322 lines), `SecondaryDisplay.kt`, `EmulationFragment.kt`,
`EmulationActivity.kt`, `emu_window.cpp`, plus manifest, menu, strings, and `config.cpp`.

**Tested end-to-end:** AYN Odin 2 → Poco phone over Wi-Fi, with touch round-trip, on *New Super Mario
Bros. 2* and *Super Mario 3D Land*.

---

## 3. What this proves for Emul8or

This is the single most useful thing found so far, because it converts our **highest-risk assumption
into a demonstrated fact.**

[`architecture.md`](architecture.md) §10 question 1 asked:

> Does `NativeLibrary.secondarySurfaceChanged()` accept a `MediaCodec` input surface without
> modification?

**Answer: yes.** Someone did exactly that, and it works on real hardware with no renderer changes.
The zero-copy GPU→encoder path Emul8or's architecture depends on is real.

Independently arrived at, and matching our design: `MediaCodec` H.264 with Surface input, the
secondary-window render path, NSD/mDNS discovery, no CPU readback.

### The gotchas it hands us for free

Two bugs on precisely the code path we intend to use, which we would otherwise have hit blind:

**a) `SecondaryDisplay` steals the Surface back.** The hidden `VirtualDisplay` placeholder's
`DisplayListener` callbacks fire asynchronously and will recreate the Presentation, yanking the
Surface out from under the encoder. Worse, `destroySurface()` can fire **after**
`releasePresentation()` — Android does not guarantee `dismiss()` is synchronous — nulling the
streamer's Surface. Ufoex's fix is a `suppressUpdates` flag guarding `updateSurface()`,
`destroySurface()`, and `updateDisplay()`.

This is exactly the surface-lifetime hazard that upstream's own `surface_mutex` comments warn about
in `native.cpp`. Emul8or **will** hit it.

**b) The touch-coordinate clamp bug** (commit 2). Relevant to Emul8or the moment a secondary surface
is smaller than the primary layout minimum.

### Where Emul8or still differs

| | PR #2343 | Emul8or |
| --- | --- | --- |
| Screen streamed | **Bottom** | **Top** |
| Second device role | Second *touchscreen* (input forwarded back) | **Display only**, no input |
| Apps required | Azahar + separate viewer app | **One APK**, two roles |
| Transport | TCP | UDP for video, TCP for control |
| Pairing / auth | None | Pairing code |
| Disconnect behaviour | Not specified | Pause, then local dual-screen fallback |
| Old-device support | Not addressed | Android 9 Secondary mode |

The direction is inverted — Ufoex streams the bottom screen and forwards touch; Emul8or streams the
top screen and keeps all input local. Both use the same underlying mechanism.

**Note the transport difference.** Ufoex uses TCP for video; Emul8or's [networking.md](networking.md)
argues for UDP, because a retransmitted frame arrives too late to display while blocking every frame
behind it. Their choice is simpler and demonstrably works; ours should be better under loss. Worth
measuring rather than assuming — if TCP is fine on a quiet LAN, simpler wins.

---

## 4. What the maintainers actually said

**Nothing.** This is the honest, evidenced answer to "do they not want this?"

Full timeline of the PR, from the API:

| Event | Actor |
| --- | --- |
| `labeled size/L` | `pull-request-size[bot]` |
| `labeled needs verification` | `github-actions[bot]` |
| `closed` | `github-actions[bot]` (anti-AI-bot gate) |
| 2 comments + reopen | `Ufoex` proving he is human, then `github-actions[bot]` |

**Zero reviews. Zero maintainer comments. No human from the Azahar team has touched it** in the two
months it has been open. Every participant is a bot or the author.

So there is **no evidence Azahar rejected this**, and equally **no evidence they want it**. It has
simply not been looked at. Plausible explanations — a busy project with 370+ open issues, a draft-ish
experimental PR, and an author who opened it saying *"not expecting a straight merge"* — but that is
inference, and it is labelled as such here.

The author's own stated reasons for treating it as experimental are the substantive concerns, and
they are good ones: single viewer, **no authentication or encryption**, fixed port, fixed resolution,
no settings UI.

---

## 5. Consequences for Emul8or

1. **Retract the false claim.** Done — `legal.md` corrected.
2. **The downstream-only policy is unchanged.** It rests on our AI policy being incompatible with
   Azahar's, not on a guess about what features they want. That reasoning stands on its own.
3. **Credit this work.** PR #2343 is GPL-2.0 like the rest of Azahar. If Emul8or adopts its
   approach — and we should, at minimum for the two bug fixes — it must be attributed in commits and
   in the licences screen. See [legal.md](legal.md) §5.
4. **Read `NetworkStreamer.kt` before writing ours.** 322 lines that already solve this problem.
5. **Carry both bug fixes from day one.** They are on our exact path, and both are independently
   correct regardless of streaming.
6. **Watch the PR.** If it is ever merged, Emul8or's patch surface shrinks considerably.

---

## 6. A note on method

I asserted that Azahar "would not merge" phone-to-phone streaming without checking. It sounded
reasonable — a two-phone streaming feature *does* sound out of scope for an emulator — and it was
convenient, since it supported a conclusion already reached for other reasons.

A single GitHub search found an open PR implementing it.

The lesson worth recording: **claims about what other people want require evidence from those
people.** Absence of a feature is not evidence of opposition to it. The downstream-only decision
happens to survive this correction intact, but it should never have been propped up by an invented
justification.
