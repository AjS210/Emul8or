# Feature: Auto-Hide Touch Overlay on Controller Connect

**Status:** specified, not implemented. Roadmap phase 10.
**Origin:** requested feature, modelled on Lemuroid's behaviour.

---

## The question

> When connecting a Bluetooth controller (e.g. a Nintendo Switch Pro Controller), does the control
> overlay disappear in Azahar?

## The answer: no

Azahar has **only a manual toggle**. There is no automatic detection whatsoever.

To hide the overlay today, a user must: open the in-game side menu → **Overlay Options** →
untick **Show Controller Overlay**. Every time, by hand. And to get the touch controls back —
because they put the controller down, or the battery died — they have to go and untick it again.

### Verified against the source, not guessed

Checked at the pinned baseline `azahar-2126.1.2`:

| Evidence | Finding |
| --- | --- |
| `InputOverlay.kt` visibility logic | `if (EmulationMenuSettings.showOverlay) { addOverlayControls(orientation) }` — a single persisted boolean, nothing else |
| `EmulationMenuSettings.showOverlay` | Plain `SharedPreferences` boolean, default `true` |
| Only writer of that boolean | `EmulationFragment.kt` menu handler, i.e. a manual user tap |
| `InputDeviceListener`, `onInputDeviceAdded`, `onInputDeviceRemoved`, `registerInputDeviceListener` | **Zero occurrences anywhere in the Android source** |
| `SOURCE_GAMEPAD`, `SOURCE_JOYSTICK`, `getInputDeviceIds` | **Zero occurrences** |

Azahar never asks Android whether a controller is attached. It cannot react to one being connected,
because nothing is listening.

Community reports agree — from a March 2025 thread on the Azahar release: *"I don't think there is a
way to hide touch controls cause I haven't been able to find it and they don't disappear after
connecting a controller."*

### Prior art

This is a solved problem elsewhere, which is a good sign that the behaviour is well-understood and
uncontroversial:

- **Lemuroid** — the reference for this request.
- **DuckStation** — "Auto-Hide Touchscreen Controller".
- **DraStic** — "Disable mapped keys in overlay".
- **ColEm** — "Hide Virtual Joystick".

---

## What Emul8or should do

**The overlay hides itself when a gamepad is connected, and comes back when it disconnects. No user
action, no menu diving.**

### Behaviour

| Event | Result |
| --- | --- |
| Gamepad connected while in-game | Overlay animates out |
| Gamepad disconnected while in-game | Overlay animates back in |
| Game launched with a gamepad already connected | Overlay never appears |
| Gamepad connects during Secondary Screen mode | No effect — Secondary has no overlay |
| User manually toggles the overlay | Manual choice wins for the rest of the session (see below) |

### The manual-override rule

Automatic behaviour that overrides a deliberate user action is infuriating. So:

- If the user manually toggles the overlay **while a controller is connected**, respect that and stop
  auto-hiding until the next connect/disconnect event.
- Treat auto-hide as a *default*, not a lock.

### Do not clobber the user's saved preference

**This matters.** `EmulationMenuSettings.showOverlay` is a persisted preference representing *what
the user wants*. Auto-hide is a *transient runtime state*.

If auto-hide writes directly to that preference, then a user who connects a controller once and later
uninstalls the controller finds their overlay permanently off with no memory of disabling it.

So the visibility decision becomes:

```
overlayVisible = showOverlay                       // the user's persisted preference
                 && !(autoHideEnabled && gamepadConnected && !manualOverrideThisSession)
```

The persisted boolean is read, never written, by the auto-hide path.

### Setting

One new preference, defaulting **on**:

> **Auto-hide controls when a controller is connected** — *Hides the on-screen buttons automatically
> while a physical controller is connected, and shows them again when it disconnects.*

---

## Implementation sketch

Small, self-contained, and it touches upstream code in exactly one place.

### 1. Detection — `emul8or/input/GamepadWatcher.kt`

Android provides this directly; no polling, no third-party library.

```kotlin
// Copyright 2026 Emul8or Project
// Licensed under GPLv2 or any later version
// Refer to the LICENSE file included.

class GamepadWatcher(
    context: Context,
    private val onChanged: (Boolean) -> Unit
) : InputManager.InputDeviceListener {

    private val inputManager =
        context.getSystemService(Context.INPUT_SERVICE) as InputManager

    val isGamepadConnected: Boolean
        get() = InputDevice.getDeviceIds().any { id ->
            InputDevice.getDevice(id)?.let { isGamepad(it) } == true
        }

    private fun isGamepad(device: InputDevice): Boolean {
        if (device.isVirtual) return false
        val sources = device.sources
        return (sources and InputDevice.SOURCE_GAMEPAD) == InputDevice.SOURCE_GAMEPAD ||
               (sources and InputDevice.SOURCE_JOYSTICK) == InputDevice.SOURCE_JOYSTICK
    }

    fun start() = inputManager.registerInputDeviceListener(this, null)
    fun stop() = inputManager.unregisterInputDeviceListener(this)

    override fun onInputDeviceAdded(deviceId: Int) = onChanged(isGamepadConnected)
    override fun onInputDeviceRemoved(deviceId: Int) = onChanged(isGamepadConnected)
    override fun onInputDeviceChanged(deviceId: Int) = onChanged(isGamepadConnected)
}
```

**Filter carefully.** Phones report a surprising number of input devices, and some non-gamepads
advertise gamepad-ish sources. `device.isVirtual` excludes Android's own virtual keyboard. Expect to
tune this once real hardware is tested — which is precisely what the Switch Pro Controller is for.

### 2. Hook — `EmulationFragment.kt`

The only upstream file this feature touches:

```kotlin
// Emul8or: auto-hide the touch overlay while a physical controller is connected.
private val gamepadWatcher by lazy {
    GamepadWatcher(requireContext()) { connected ->
        Emul8orOverlayState.gamepadConnected = connected
        binding.surfaceInputOverlay.refreshControls()
    }
}
```

Started in `onResume()`, stopped in `onPause()`. Registering a system listener that outlives the
fragment leaks it.

### 3. Visibility — `InputOverlay.kt`

Upstream currently reads:

```kotlin
if (EmulationMenuSettings.showOverlay) {
    addOverlayControls(orientation)
}
```

Change to a single call so the logic lives in Emul8or's code, not scattered through upstream's:

```kotlin
if (Emul8orOverlayState.shouldShowOverlay()) {
    addOverlayControls(orientation)
}
```

**Upstream touch point total: 2 files, a handful of lines.** Consistent with the patch-surface
discipline in [upstream-integration.md](upstream-integration.md) §6 — every hook here is a permanent
rebase cost, so keep the logic in our tree and leave a one-line call behind.

---

## Testing

Your Switch Pro Controller is the primary test device, and it is a *good* one — it pairs as a
standard HID gamepad, so it exercises the common path.

| Test | Expected |
| --- | --- |
| Connect controller mid-game | Overlay disappears |
| Disconnect controller mid-game | Overlay returns |
| Launch a game with controller already paired | Overlay never shows |
| Controller sleeps / times out | Overlay returns (this is a *disconnect*) |
| Controller battery dies mid-game | Overlay returns — **the important one**, the player must not be left with no input at all |
| Manual toggle while connected | Manual choice respected |
| Bluetooth keyboard connected | Overlay **stays** — not a gamepad |
| Emul8or Secondary Screen mode | No effect; no overlay exists there |

The battery-death case is the one that actually matters. If the overlay does not come back, the game
becomes uncontrollable.

### Note on the Switch Pro Controller specifically

It is known to be quirky on some Android versions, occasionally presenting unusual button mappings or
requiring a pairing dance. That affects *input mapping*, not *presence detection* — this feature only
asks "is a gamepad attached?", which is the robust part. Worth knowing if the mapping turns out odd
while auto-hide works fine.

---

## Where this sits

Roadmap **phase 10**, alongside Bluetooth controller support. It is not a dependency for the
two-phone streaming work, and should not jump the queue ahead of it.

That said, it is genuinely small — one new file, two small upstream edits — and it is
self-contained enough to be a good first coding task once the build is working, if the main path is
blocked on something else.
