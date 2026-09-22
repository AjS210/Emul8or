# DS Support: Can Azahar's Dual-Screen Work Be Reused for a DS Core?

**Question:** Azahar only plays 3DS games. How much of it can be stripped and reused with a DS core?

**Short answer: almost none of it — and you don't need to, because it already exists for DS.**

Researched 2026-09-22.

---

## 1. Why code reuse is a dead end

### The licences are one-way incompatible

| Project | Licence |
| --- | --- |
| Azahar | **GPL-2.0-or-later** (verified: *"Licensed under GPLv2 or any later version"*) |
| melonDS | **GPL-3.0** |
| melonDS-android | **GPL-3.0** |
| DeSmuME | GPL-2.0 |

Azahar being GPL-2.0-**or-later** means its code *can* be relicensed upward into a GPL-3.0 project.
So Azahar code → melonDS is legally possible.

The reverse is not. **GPL-3.0 code cannot move into a GPL-2.0 project.** So nothing flows back.

That asymmetry matters less than it sounds, though, because of the next point.

### There is nothing worth moving

The instinct behind the question is reasonable — Azahar clearly knows how to render two screens
independently, so why not lift that? But look at what the dual-screen support actually *is*:

| Azahar piece | Lines | Genuinely reusable? |
| --- | --- | --- |
| `SecondaryDisplay.kt` | ~150 | **No** — thin wrapper over Android's `Presentation` + `VirtualDisplay` APIs |
| `secondarySurfaceChanged()` JNI | ~10 | **No** — passes a `Surface` to Azahar's own C++ |
| `EmuWindow_Android(is_secondary)` | — | **No** — built on Azahar's `Frontend::EmuWindow` base class |
| `AndroidSecondaryLayout()` | ~30 | **No** — computes rectangles for **3DS** screens (400×240 / 320×240) |
| `ScreenLayout.kt` enums | ~90 | **No** — integer values mirroring Azahar's C++ `Settings` |

**None of it is emulator-agnostic.** Every piece is either (a) a few lines calling a standard Android
API, or (b) tightly bound to Azahar's own window, settings, and layout classes.

The "hard part" of Azahar's secondary display isn't clever code — it's that someone plumbed a second
`Surface` through an existing renderer. You cannot transplant that plumbing; you'd re-plumb the new
renderer instead. The transferable asset is **the technique**, which is free, and which this
repository has already documented in [architecture.md](architecture.md) §4.

Concretely: hoisting Azahar's dual-screen support into a DS emulator would mean rewriting essentially
all of it against melonDS's own renderer. That is not "stripping and reusing" — that is writing it
again.

---

## 2. The much better news: DS already has this

Two separate projects already do dual-screen DS on Android.

### melonDS-android has official dual-screen support

[rafaelvcaetano/melonDS-android](https://github.com/rafaelvcaetano/melonDS-android) — the standard
Android DS emulator. **1,650 stars, actively maintained** (last push Sept 2026), GPL-3.0, on the Play
Store.

Release **2.0.0** (18 Apr 2026) added:

> *"Add support dual-screen devices (thanks to @SapphireRhodonite for the initial implementation,
> special thanks to AYANEO and AYN for providing test devices)"*

That is for physical dual-screen handhelds (AYN Thor, AYANEO Flip), not two phones — the same
distinction as Azahar's external-display support.

### DualMelon does the two-phone version

[Liprax/DualMelon](https://github.com/Liprax/DualMelon) — a fork of melonDS-android whose description
is, almost word for word, Emul8or's premise:

> *"allows using two separate phones as a single Nintendo DS console (one phone as the top screen,
> one as the bottom screen)"*
>
> - **Top Screen Mode:** One phone displays only the upper screen of the DS.
> - **Bottom Screen Mode:** The other phone displays only the lower touchscreen.
> - **Immersive Layout:** Place the two phones together…

**And it is the right way round** — top screen on one phone, bottom touchscreen on the other. That is
Emul8or's arrangement, not Ufoex's inverted one.

| | DualMelon |
| --- | --- |
| Licence | **GPL-3.0** — properly licensed, unlike Ufoex's viewer |
| Prebuilt APK | **Yes** — `app-gitHub-prod-release.apk`, 29 downloads |
| Package | `com.liprax.dualmelon` |
| Stars / forks | **0 / 0** |
| Last commit | 18 Jul 2026 |
| Divergence | 2 commits ahead, **18 behind** upstream |
| Docs | README is partly in Turkish (`GİTHUBREADME.txt`, commit messages) |

Single-developer, zero-star, two months stale — but real, installable, and correctly licensed.

### DraStic (DS, closed-source, now free)

Has had **external display support for years** — `Options → Video → External display screen = Top
screen`. Not open source, so irrelevant as a code base, but relevant as proof the feature is
long-established in DS emulation.

---

## 3. What this means for Emul8or

Worth stating plainly, because it changes the strategic picture:

**Two-phone dual-screen emulation is not an unexplored idea. It has been done — for 3DS (Ufoex) and
for DS (DualMelon) — and neither implementation is polished or widely adopted.**

That is not a reason to stop. It *is* a reason to be clear-eyed about what the project would be:
**not "the first", but "the good one".** Every existing attempt is a single-developer proof of
concept with 0–3 stars, no hardening, and a stale branch.

### If DS support is wanted, the route is melonDS, not Azahar

Do **not** try to graft a DS core into an Azahar-derived Emul8or. That would mean:

- Embedding a GPL-3.0 core into a GPL-2.0-or-later codebase → the combined work becomes GPL-3.0,
  which is legal but means Emul8or could never share code with Azahar again.
- Running two completely separate emulator cores with different build systems, settings, save
  formats, and renderers in one APK.
- Roughly doubling the maintenance burden for zero shared code.

The sane approach, if DS matters:

1. **Fork melonDS-android separately** (GPL-3.0), and apply the same networking/streaming design.
2. Or better — **contribute the two-phone feature to DualMelon**, which already has the arrangement
   right and is properly licensed, rather than starting a third implementation.
3. Keep the **protocol** shared between the 3DS and DS versions. The wire format in
   [networking.md](networking.md) is emulator-agnostic — discovery, handshake, H.264 framing,
   heartbeat. *That* is the genuinely reusable asset, and it is Emul8or's own work.

**The reusable thing across cores is the network protocol, not the rendering code.**

---

## 4. Recommended next step

Before any of this, finish the evaluation already in progress
([try-existing-solution-first.md](try-existing-solution-first.md)).

Then, if DS interests you, **install DualMelon's APK and try it too** — it is prebuilt, GPL-3.0, and
does exactly the two-phone arrangement you described, for DS. Twenty minutes, same as the Azahar
test.

Between the two tests you will know:

- Whether two-phone play is actually enjoyable, or a novelty that wears off in an hour.
- Whether existing implementations are good enough.
- Precisely which gaps a serious version would need to close.

That is a far better basis for deciding what to build than any amount of further design work.

---

## 5. Summary

| Question | Answer |
| --- | --- |
| Can Azahar's dual-screen code be reused for DS? | **No.** It is thin Android API glue plus Azahar-specific classes. Nothing meaningful transplants |
| Is it legally possible? | Azahar GPL-2.0-or-later → melonDS GPL-3.0 is allowed. The reverse is not |
| Does DS already have dual-screen? | **Yes.** melonDS-android 2.0.0 for dual-screen handhelds |
| Does DS already have two-phone? | **Yes.** DualMelon — top screen on one phone, bottom on the other |
| Is that project mature? | No. 0 stars, single developer, 18 commits behind, last touched July 2026 |
| Should Emul8or add a DS core? | **No.** Separate fork of melonDS-android, or contribute to DualMelon |
| What *is* reusable across cores? | **The network protocol** — discovery, handshake, streaming, reconnect. Emul8or's own design |
