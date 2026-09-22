# Project Scope: What Emul8or Actually Is

Written 2026-09-22, replacing the original "3DS dual-screen app" framing.

---

## 1. The goal, restated

> *"A mobile app that turns everyone's phone into more of an R36S-styled handheld, where ALL the
> handheld emulator cores are in one place. Currently I have 5 independent apps to play 7
> generations of Pokémon games, without including NES, N64, GameCube, or Wii titles."*

Two goals, in priority order:

1. **One app, many systems.** Stop juggling five emulators to play one series.
2. **Two-phone dual-screen.** Still the most important single feature, but no longer the nucleus.

---

## 2. The uncomfortable finding: goal 1 is already solved

Before designing anything, the honest check: does an app already do this?

**Yes. [Lemuroid](https://github.com/Swordfish90/Lemuroid) — 4,342 stars, GPL-3.0, actively
maintained** (1.17.0, April 2026), free, no ads, on the Play Store, 11.4 MB.

I read its `SystemID.kt` enum directly from source. Here is the actual supported list:

```
NES, SNES, GENESIS, GB, GBC, GBA, N64, SMS, PSP, NDS, GG, ATARI2600,
PSX, FBNEO, MAME2003PLUS, PC_ENGINE, LYNX, ATARI7800, SEGACD, NGP,
NGC, WS, WSC, DOS, NINTENDO_3DS
```

Now check that against the five-apps-for-Pokémon problem:

| Gen | Games | System | Lemuroid |
| --- | --- | --- | --- |
| 1 | Red / Blue / Yellow | Game Boy | ✅ `GB` |
| 2 | Gold / Silver / Crystal | GBC | ✅ `GBC` |
| 3 | Ruby / Sapphire / Emerald / FRLG | GBA | ✅ `GBA` |
| 4 | Diamond / Pearl / Platinum / HGSS | DS | ✅ `NDS` |
| 5 | Black / White / B2W2 | DS | ✅ `NDS` |
| 6 | X / Y / ORAS | 3DS | ✅ `NINTENDO_3DS` |
| 7 | Sun / Moon / US / UM | 3DS | ✅ `NINTENDO_3DS` |

**All seven generations. One app. Today.** Plus `NES` and `N64` from your list.

Only **GameCube and Wii** are missing — and those are not handhelds, so they fall outside the
"R36S-styled handheld" framing anyway. (Dolphin standalone remains the right answer there; no
all-in-one frontend does GameCube/Wii well.)

### So should the project stop?

No — but the reason to continue has changed, and it is worth being precise about it.

**Building another all-in-one launcher would be redundant.** Lemuroid, RetroArch, ES-DE, Daijishō and
Beacon all occupy that space, several with years of polish. Entering it means competing on library
scanning, box art scraping and theme engines — none of which you set out to build.

**But none of them do two-phone dual-screen.** Not Lemuroid, not RetroArch, not any frontend. That
remains genuinely unoccupied.

---

## 3. The reframe

> **Emul8or is not "an all-in-one emulator." It is the dual-screen layer — and it should be built on
> top of an all-in-one that already works.**

The all-in-one part is a solved commodity you can inherit. The dual-screen part is the thing nobody
has finished. Build only the second, and get the first for free.

---

## 4. Why this makes the hard problem dramatically easier

This is the part that genuinely changes the engineering, and it resolves the licensing dead end from
[ds-support-research.md](ds-support-research.md).

### Lemuroid is a libretro frontend

It does not contain emulators. It loads **libretro cores** — Citra for 3DS, melonDS/DeSmuME for DS,
Snes9x, Gambatte, Mupen64Plus, and so on. Every core speaks the same C API.

### libretro cores hand the frontend one flat framebuffer

A libretro core does not know or care about "screens". It calls `retro_video_refresh` with a single
buffer. For dual-screen consoles, the core renders **both screens stacked into that one buffer** —
DS gives you 256×384 (two 256×192 screens), 3DS gives you the top and bottom composited together.

**That means splitting top from bottom is a crop, performed above the core, in the frontend stack.**

> **Correction (source-verified).** This section originally said the crop would be *"in Kotlin"*.
> That was wrong. Lemuroid renders through **LibretroDroid**, a separate GPL-3.0 C++/Kotlin library,
> and the crop must be added there — its existing `viewport` API positions the quad but never writes
> `textureCoordinates`, so it cannot sample a sub-region. The conclusion below is unaffected: it is
> still one implementation covering every dual-screen core, with no per-emulator renderer surgery.
> See **[lemuroid-crop-feasibility.md](lemuroid-crop-feasibility.md)** for the file-by-file detail.

### The consequence

Compare the two approaches:

| | Patch each emulator | Patch a libretro frontend |
| --- | --- | --- |
| Where the work lives | Azahar's C++ renderer, then melonDS's C++ renderer, separately | One place, in Kotlin, in the frontend |
| Per-system cost | Full re-implementation per emulator | **Zero** — crop rectangles differ, code does not |
| Systems covered | 3DS only, then DS only | **Every dual-screen core at once** |
| Licence friction | GPL-2.0 vs GPL-3.0 one-way incompatibility | **None** — cores stay untouched behind a stable API |
| Rebase burden | 6+ upstream files per emulator, forever | Frontend files only |

The GPL-2.0/GPL-3.0 problem **disappears entirely**, because you never merge Azahar's code into
melonDS's code. You leave both cores alone as independent `.so` files behind the libretro API, and do
all your work above them. Lemuroid is GPL-3.0, cores load dynamically, and the boundary is a stable
published C API.

**One dual-screen implementation. Every dual-screen system. No renderer surgery.**

That is a fundamentally better architecture than patching Azahar, and it only became visible once the
scope widened past 3DS.

---

## 5. What is actually left to build

Everything below is genuinely absent from every existing frontend:

1. **Role selection** — one APK, "Play here" vs "Be a second screen".
2. **Screen splitting** — crop the core's framebuffer into top and bottom regions. Per-system
   rectangles in a lookup table; DS is trivially 256×192 above 256×192.
3. **Streaming** — H.264 via `MediaCodec` over the LAN. Design already written in
   [networking.md](networking.md); the mechanism is proven by
   [PR #2343](prior-art-pr2343.md).
4. **Discovery and pairing** — mDNS, already specified.
5. **Graceful degradation** — secondary drops, primary falls back to local dual-screen layouts.
6. **Overlay controls above the split** — already specified in
   [feature-auto-hide-overlay.md](feature-auto-hide-overlay.md).

Items 3–6 are already designed in this repo. That design work survives the pivot intact; only the
host application changed.

---

## 6. Revised recommendation

**Fork Lemuroid rather than Azahar.**

| | Azahar base | Lemuroid base |
| --- | --- | --- |
| Systems | 3DS only | **25**, incl. all 7 Pokémon gens |
| Licence | GPL-2.0-or-later | GPL-3.0 (can absorb either) |
| Dual-screen work | C++ renderer surgery, per emulator | Kotlin crop, once |
| Library UI / scraping / box art | Build it | **Inherited** |
| Health | Active | Active, 4.3k stars |
| Matches stated goal | Partially | **Fully** |

Known trade-off, stated honestly: **libretro cores lag standalone emulators on the demanding
systems.** Lemuroid's 3DS support uses an older Citra core and will not match Azahar standalone for
Gen 6/7 performance. For Gen 1–5 — GB through DS — libretro cores are mature and the difference is
irrelevant. If Gen 6/7 performance proves unacceptable on your hardware, the fallback is dual-screen
on Lemuroid for everything up to DS, with Azahar standalone kept for 3DS.

That is a worthwhile trade for going from one system to twenty-five.

---

## 7. Revised phase order

1. **Test the prior art.** [try-existing-solution-first.md](try-existing-solution-first.md) — still
   step one, still unstarted. Add DualMelon for the DS comparison.
2. **Install Lemuroid.** Point it at your ROM folder. Confirm all seven Pokémon generations appear in
   one library. This validates or kills the whole premise in twenty minutes, before any code.
3. **Build Lemuroid unmodified** from source on Windows. New exit criterion, replacing "build Azahar".
4. **Crop experiment.** Get a DS core rendering top-half-only on screen. Smallest possible proof.
5. **Streaming**, per existing design.
6. **Role selection and fallback layouts.**

Steps 1 and 2 cost one evening and require no code. Do them before anything else.

---

## 8. What changes in this repo

Documents that **survive unchanged** — they were never Azahar-specific:

- `networking.md`, `feature-auto-hide-overlay.md`, `feature-touch-gestures.md`,
  `getting-started-windows.md`, `legal.md`, `testing-devices.md`

Documents now **partly obsolete**:

- `azahar-build-research.md`, `upstream-integration.md` — Azahar-specific build and vendoring plans.
  Keep for reference; the vendoring *method* still applies to a Lemuroid fork.
- `architecture.md` — the streaming design holds; "Azahar" should become "the core", and §4's
  renderer-patching approach is superseded by frontend cropping.

Still true and still valuable: the [hardware validation](architecture.md) that proved top/bottom
screen separation works on real devices, the two bug fixes from PR #2343, and the confirmation that a
receiver needs no emulator core (so Android 9 secondary devices remain fine).
