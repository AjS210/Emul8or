# Where the Screen Split Actually Goes in Lemuroid

Source-level investigation, 2026-09-22. This **corrects a claim** made in
[project-scope.md](project-scope.md) §4.

---

## 1. The correction

I previously wrote that splitting top from bottom would be *"a crop, performed in the frontend, in
Kotlin."*

**The "in Kotlin" part is wrong.** I checked the source instead of assuming, and the crop has to
happen in C++, one layer below Lemuroid.

The conclusion that matters — *one implementation covers every dual-screen core, no per-emulator
renderer surgery* — **still holds**, and is if anything better supported than before. But the file
you edit is not the file I said it was.

---

## 2. The actual architecture

Lemuroid does not talk to libretro cores directly. There is a middle layer:

```
Lemuroid            (Kotlin, GPL-3.0)  — library UI, scanning, settings
    ↓
LibretroDroid       (C++/Kotlin, GPL-3.0, same author, 115 stars)  — the emulator view
    ↓
libretro cores      (.so files — Citra, melonDS, DeSmuME, Snes9x…)
```

**[LibretroDroid](https://github.com/Swordfish90/LibretroDroid)** is where all rendering lives. It is
a separate library by the same author (Filippo Scognamiglio), also GPL-3.0. It exposes
`GLRetroView`, an OpenGL surface that draws the core's framebuffer as a textured quad.

That is the layer Emul8or modifies. Not Lemuroid, not the cores.

---

## 3. What exists already, and what is missing

`GLRetroView.kt` already exposes a viewport property:

```kotlin
var viewport: RectF by Delegates.observable(RectF(0f, 0f, 1f, 1f)) { _, _, value ->
    LibretroDroid.setViewport(value.left, value.top, value.width(), value.height())
}
```

Promising — until you read what it does. In `videolayout.cpp`, `viewportRect` only feeds
`updateForegroundVertices()`, which computes the **foreground vertices**: *where on the display the
quad is drawn*, and how it scales to preserve aspect ratio.

The other half of the pair is `textureCoordinates` — the UVs that decide **which part of the
framebuffer is sampled**. In `videolayout.h` it is declared with a fixed initialiser of the full
`0.0 → 1.0` range, and grepping the whole file confirms it:

```
$ grep -n textureCoordinates videolayout.cpp
(no matches)
```

**`videolayout.cpp` never writes to `textureCoordinates`.** It is set once at construction and read
once by `video.cpp:182`. There is no UV cropping anywhere in the codebase.

So the existing `viewport` API **moves and scales the whole image**. It cannot show you half of it.

---

## 4. What needs building

A sibling to `setViewport` — call it `setTextureCrop` — that writes `textureCoordinates` the same way
`setViewport` writes the vertices.

| Layer | File | Change |
| --- | --- | --- |
| C++ core | `videolayout.h` / `.cpp` | Add `cropRect` + `updateTextureCoordinates()` writing the 12-float UV array |
| JNI | `libretrodroidjni.cpp` | `setTextureCrop(x, y, w, h)` |
| Java shim | `LibretroDroid.java` | Native method declaration |
| Kotlin API | `GLRetroView.kt` | `var textureCrop: RectF` observable, mirroring `viewport` |
| Lemuroid | emulator screen | Set the crop from the active role + system |

Five files, all following a pattern that already exists in the same classes. The maths is the easy
kind — writing eight floats into a 12-float array.

**It is C++, but it is small, and it is written once.**

---

## 5. Why this is still the right architecture

The comparison against patching emulators actually improves once you see the real layer:

| | Patch Azahar + melonDS | Patch LibretroDroid |
| --- | --- | --- |
| Codebases touched | 2 separate C++ emulators | **1 rendering library** |
| Per-system cost | Full re-implementation | **Crop rectangle in a lookup table** |
| Systems covered | 3DS, then DS | **Every dual-screen core at once** |
| Licence friction | GPL-2.0 vs GPL-3.0, one-way | **None** — GPL-3.0 throughout, cores untouched |
| Upstream rebase cost | 6+ files per emulator, forever | ~4 files in one library |

The crop rectangles themselves are trivial constants:

| System | Framebuffer | Top screen | Bottom screen |
| --- | --- | --- | --- |
| DS / DSi | 256×384 | `(0, 0, 1, 0.5)` | `(0, 0.5, 1, 0.5)` |
| 3DS | core-dependent | per-core constant | per-core constant |

Adding a new dual-screen system is **a row in a table**, not a porting project.

---

## 6. A useful shortcut for the single-device case

The DS cores already ship layout options. From the libretro docs, DeSmuME's
`desmume_screens_layout` accepts:

```
top/bottom | bottom/top | left/right | right/left | top only | bottom only |
quick switch | hybrid/top | hybrid/bottom
```

melonDS has an equivalent. **`top only` and `bottom only` do exactly what Emul8or needs** — and
Lemuroid can already set core options.

This does **not** solve the two-phone case: one core instance produces one framebuffer, so it cannot
render "top only" and "bottom only" simultaneously for two devices. The crop is still required.

But it is worth knowing for two reasons:

1. **Local fallback layouts** may be achievable through core options alone, with no code.
2. It is a **free test**. Set a DS core to `top only` in Lemuroid today and you have confirmed the
   whole concept end-to-end before writing anything.

---

## 7. Prior art: Lemuroid PR #943

**[PR #943](https://github.com/Swordfish90/Lemuroid/pull/943)**, *"Add more screen layout option for
NDS emulators"* — exposes DeSmuME and melonDS layout options in Lemuroid's UI, plus a screen-swap
button. 4 commits, 3 files, +71−3.

**Open since 22 August 2024. `mergeable_state: dirty`. Not updated since the day it was opened.**

The same pattern as [PR #2343](prior-art-pr2343.md) and [DualMelon](ds-support-research.md): someone
built the obvious thing, it works, and it stalled. Three independent instances now.

Read as a warning, that is discouraging. Read accurately, it is the actual market gap: **these
features are not hard to build and not hard to want — they are hard to finish.** That is the
differentiator, and it is a matter of follow-through rather than cleverness.

---

## 8. Revised next steps

1. **Free concept test, no code.** In Lemuroid, load a DS game, set the core option to `top only`.
   Then `bottom only`. If both look right, the split is confirmed at the source.
2. **Build LibretroDroid and Lemuroid unmodified** on Windows. LibretroDroid must build first — it is
   the dependency.
3. **Add `setTextureCrop`.** Prove it with a hardcoded `(0, 0, 1, 0.5)` on DS.
4. **Wire it to role selection**, then to streaming per [networking.md](networking.md).

Step 1 costs five minutes and de-risks everything after it.

---

## 9. Summary

| Question | Answer |
| --- | --- |
| Is the crop pure Kotlin? | **No** — my earlier claim was wrong |
| Where does it go? | **LibretroDroid**, a GPL-3.0 C++/Kotlin library under Lemuroid |
| Does a viewport API already exist? | Yes, but it positions the quad; it does not sample a sub-region |
| What is missing? | `textureCoordinates` is never written. Needs a `setTextureCrop` sibling |
| How big? | ~5 files, following an existing pattern in the same classes |
| Per-system cost after that? | **A row in a lookup table** |
| Licence problems? | **None.** GPL-3.0 throughout, cores stay untouched behind the libretro API |
