# Feature: Multi-Touch Gestures

**Status:** specified, not implemented. Roadmap phase 3 (core gesture) / phase 10 (extras).
**Origin:** requested — "tap with three fingers to toggle the control overlay".

---

## Verdict: yes, and it's a better fit than it first appears

The emulated 3DS touchscreen is **resistive and single-touch**. It physically cannot register two
fingers. Confirmed in the core API — the whole surface is expressed as one point:

```cpp
bool TouchPressed(unsigned framebuffer_x, unsigned framebuffer_y);
void TouchReleased();
void TouchMoved(unsigned framebuffer_x, unsigned framebuffer_y);
```

and at the JNI boundary:

```kotlin
external fun onTouchEvent(xAxis: Float, yAxis: Float, pressed: Boolean): Boolean
```

One x, one y. No pointer ID, no slot.

**This is the crucial point: any gesture using three or more fingers is, by definition, not something
the emulated console can consume.** There is no ambiguity to resolve, no heuristic, no risk of
stealing a legitimate game input. Three fingers cannot mean anything to a 3DS.

That makes 3+ finger gestures unusually safe here — safer than in most apps, where a multi-touch
gesture competes with pinch-zoom or scrolling.

---

## What already exists upstream

Azahar's `InputOverlay.onTouchEvent()` **is** already multi-touch aware — it has to be, so you can
hold a D-pad direction and press a button simultaneously:

```kotlin
val pointerList = (0 until event.pointerCount).toMutableList()
val currentActionPointer = event.actionIndex
// ... iterates every active pointer, tracks pointer IDs
```

It handles `ACTION_POINTER_DOWN` / `ACTION_POINTER_UP` and tracks pointer IDs properly. So the
plumbing to observe multiple fingers is present; nothing detects *gestures* on top of it.

**Practical consequence:** Emul8or's gesture detector should sit *above* that logic and consume the
event before the overlay and the emulated touchscreen see it. Implementation note below.

---

## Proposed gestures

Conservative by default. Each is individually configurable, and each defaults to something hard to
trigger accidentally.

| Gesture | Action | Default | Phase |
| --- | --- | --- | --- |
| **3-finger tap** | Toggle control overlay | **On** | 3 |
| 3-finger swipe down | Open the in-game menu | Off | 10 |
| 3-finger swipe left/right | Swap top/bottom screens between displays | Off | 10 |
| 4-finger tap | Pause / resume emulation | Off | 10 |

The requested 3-finger tap is the only one enabled by default. The rest exist because the detector
makes them nearly free, but an emulator that reacts to gestures nobody asked for is annoying — they
stay off until explicitly enabled.

### Why 3-finger tap is the right default

- Impossible to perform accidentally while playing. A 3DS needs one finger, or a stylus.
- Impossible to confuse with a game input, per the single-touch argument above.
- It solves the exact problem in
  [feature-auto-hide-overlay.md](feature-auto-hide-overlay.md): the manual toggle is currently buried
  in a menu. These two features complement each other — auto-hide handles the controller case
  automatically, the gesture handles everything else instantly.

---

## Detection rules

Gesture detection must be strict, or it will fire during normal play.

A **3-finger tap** requires all of:

| Condition | Threshold | Why |
| --- | --- | --- |
| Peak simultaneous pointers | exactly 3 | 4 is a different gesture |
| Duration, first down → last up | < 300 ms | A tap, not a rest |
| Max movement of any pointer | < 40 dp | A tap, not a swipe or drag |
| All three down within | 150 ms of each other | Three fingers landing together, not sequentially |

Miss any of them and the event falls through to normal handling untouched.

**Use `dp`, not pixels.** 40 px is a very different distance on the S24 Ultra's ~500 dpi display than
on a Note 8, and hardcoded pixel thresholds are a classic source of "works on my phone" bugs.

---

## The one real conflict: Samsung's palm/3-finger gestures

**Relevant to your exact hardware.** Samsung's One UI has system-level multi-finger gestures, most
notably **palm swipe to capture** (screenshot). Some OEMs and accessibility settings add three-finger
swipes for screenshot or split-screen.

System gestures are processed **before** the app sees them, so we cannot override them and should not
try.

Mitigations, in order:

1. **Prefer a 3-finger *tap* over a 3-finger *swipe*.** Samsung's conflicting gestures are swipes.
   A stationary tap sidesteps the common collisions — this is the main reason tap is the default.
2. **Make it configurable.** If a user's device eats the gesture, they can reassign or disable it.
3. **Document it.** If nothing happens, the first thing to check is Settings → Advanced features →
   Motions and gestures.
4. **Provide a non-gesture path.** The in-game menu toggle must remain. A gesture is a shortcut, never
   the only way to do something.

Worth testing on the S24 Ultra early, since it is the most gesture-heavy device in the test matrix.

---

## Implementation sketch

### Where it goes

`emul8or/input/GestureDetector.kt` — Emul8or's own tree, per the patch-surface rules in
[upstream-integration.md](upstream-integration.md) §6.

### How it intercepts

The cleanest hook is **`dispatchTouchEvent`** on the emulation activity or the container view, *not*
`onTouchEvent` on `InputOverlay`. Reasons:

- It sees the event before the overlay's button hit-testing.
- Returning `true` consumes the event, so neither the overlay nor `NativeLibrary.onTouchEvent()` is
  reached — no phantom stylus tap in-game.
- It leaves upstream's carefully-ordered pointer loop completely untouched.

```kotlin
// Copyright 2026 Emul8or Project
// Licensed under GPLv2 or any later version
// Refer to the LICENSE file included.

override fun dispatchTouchEvent(event: MotionEvent): Boolean {
    if (emul8orGestures.onTouchEvent(event)) return true   // consumed
    return super.dispatchTouchEvent(event)
}
```

### The cancellation problem

**The subtle bug to avoid.** A gesture is only recognised once the third finger lands — by which
point the first finger has *already* been forwarded as a touch-down to the emulated 3DS screen. If
the gesture then fires, the game is left with a stuck touch-down that never gets a matching up.

So on recognition, Emul8or must send `NativeLibrary.onTouchEvent(0f, 0f, false)` to release any touch
in progress. Upstream already uses exactly that call to release touches (`InputOverlay.kt:171`), so
we follow the existing convention rather than inventing one.

Equally, a gesture that *starts* but fails its thresholds — say the user rests three fingers for a
second — must fall through cleanly without having eaten the earlier events.

### Upstream touch points

**One file, one method.** `dispatchTouchEvent` on the emulation activity. Everything else lives in
Emul8or's tree. That keeps the permanent rebase cost near zero, which matters given the
downstream-only policy in [legal.md](legal.md).

---

## Interaction with Emul8or's two modes

| Mode | Gestures active? |
| --- | --- |
| **Primary** | Yes — full set |
| **Secondary Screen** | **No.** The secondary displays video and handles no input at all ([architecture.md](architecture.md) §2). Adding gesture handling there would breach the role separation that lets Secondary run on Android 9 |

---

## Testing

| Test | Expected |
| --- | --- |
| 3-finger tap during gameplay | Overlay toggles; no in-game touch registered |
| 3-finger tap while dragging a stylus input | In-game touch cleanly released, no stuck input |
| Normal single-finger play | Completely unaffected |
| Two fingers (D-pad + button) | Unaffected — this is normal overlay use |
| Slow three-finger rest | No toggle; falls through |
| Three-finger swipe | No toggle (fails the movement threshold) |
| On S24 Ultra with One UI gestures on | Works, or fails predictably and is documented |
| On Note 8 (Android 9) | Detector API is old and stable; should behave identically |
| Rapid repeated taps | No double-fire; debounce |

---

## Honest assessment

This is a genuinely good fit, for a reason specific to this console: **the 3DS touchscreen is
single-touch, so multi-finger input is free real estate.** A gesture layer here costs nothing in
ambiguity, which is not true of most apps.

It is also small — one new file, one intercepted method — and it improves a real papercut, since the
overlay toggle is currently buried in a menu.

The risks are modest and known: OEM gesture conflicts (mitigated by preferring taps and keeping it
configurable), and the stuck-touch bug on recognition (mitigated by an explicit release, using
upstream's own convention).

Scheduled into **phase 3** for the 3-finger tap, alongside the layout work where overlay behaviour is
already being touched. The optional extras wait for **phase 10** with the rest of the input work.
