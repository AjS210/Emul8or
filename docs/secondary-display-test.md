# Test: Does the Secondary Display Feature Work?

**You can run this today, on the Play Store Azahar you already have. No building, no coding.**

This is the single most valuable thing you can do before starting the project.

---

## Why this test matters so much

Emul8or's entire plan rests on one assumption:

> Azahar can already render the 3DS **top screen** to a *separate display*, independently of the
> bottom screen.

If that's true, Emul8or doesn't have to rebuild the hard part. We just feed that existing feature a
**Wi-Fi connection** instead of a **cable**. The emulator won't know the difference.

If it's *not* true, the whole architecture needs rethinking — and it's far better to learn that in
ten minutes with an app you already own than after weeks of work.

**This test costs you ten minutes and tells you whether the project's foundation is solid.**

---

## The pleasant surprise: you may not need a cable

While reading Azahar's source, I found the description text for this setting:

> *"The layout used by a connected secondary screen, **wired or wireless (Chromecast, Miracast)**"*

Azahar explicitly supports **wireless** second screens. So if you own a **Chromecast, a Fire TV
Stick, a Roku, or a smart TV with screen mirroring**, you can run this test with no adapter at all.

That is also a meaningful hint for the project: Azahar is already comfortable with a second screen
that has network latency, not just a cable. That's encouraging for what we're planning.

---

## What you'll need — any ONE of these

| Option | What you need | Notes |
| --- | --- | --- |
| **A. Wireless** | Chromecast / Fire Stick / Roku / smart TV with mirroring | Easiest if you have one. Tests something close to our real use case |
| **B. Wired** | USB-C-to-HDMI adapter + TV or monitor | Most reliable, lowest latency |
| **C. Samsung DeX** | USB-C-to-HDMI adapter + TV | Same hardware as B; DeX is Samsung's desktop mode |

Your S24 Ultra supports all three.

---

## Before you start

- [ ] Azahar installed (you have this)
- [ ] **One of your own legally-dumped 3DS games**, already loading in Azahar. The test needs a
      running game — you can't see two screens with nothing playing.
- [ ] A TV, monitor, or casting device

---

# Part 1 — Connect the second screen

Do this **first**, before touching Azahar's settings. The option behaves differently depending on
what's already connected.

### If wireless (Chromecast / Fire Stick / smart TV)

1. Make sure your phone and the device are on **the same Wi-Fi network**
2. On the S24 Ultra, swipe down twice from the top to open **Quick Settings**
3. Find **Smart View** (you may need to swipe left to a second page of icons)
4. Tap it, pick your TV or Chromecast from the list
5. Accept any prompt on the TV
6. Your phone's screen should now appear on the TV — **mirrored**, which is not the goal yet, just
   confirmation the link works

### If wired (HDMI adapter)

1. Plug the USB-C-to-HDMI adapter into the S24 Ultra
2. Plug an HDMI cable from the adapter to your TV or monitor
3. Set the TV to that HDMI input
4. Your phone's screen should appear — again, mirrored for now

**If nothing appears on the TV, stop here.** Fix the connection before going further, or you'll be
debugging two problems at once.

---

# Part 2 — Turn on the secondary display in Azahar

Now the actual setting. I pulled the exact menu path from Azahar's source code, so these names should
match what you see.

1. **Open Azahar**
2. Tap the **Settings** (gear) icon
3. Tap **Layout** *(the section is internally called "Layout settings" — it holds screen orientation,
   screen layout, portrait layout, and the secondary display options)*
4. Scroll down to find **"Enable Secondary Display"** and **turn it ON**

   Its description reads: *"If disabled, Azahar will let Android manage connected displays. If this
   is enabled and multiple displays are connected, you can select which one Azahar will use in the
   Emulation Quick Menu"*

5. Just below it, tap **"Secondary Display Layout"**
6. From the list, choose **"Top Screen"**

The full list of choices is: *Opposite Screen, **Top Screen**, Bottom Screen, Side by Side, Original,
Hybrid, Large Screen.* You want **Top Screen**.

---

# Part 3 — Run the test

1. **Start one of your games**
2. Look at both screens

### Once the game is running, you may need to pick the display

The setting's description mentions choosing a display in the **Emulation Quick Menu**. So if nothing
changes at first:

1. While the game is running, open the in-game menu (usually the ⋮ button, or a swipe from the edge)
2. Look for **"Secondary Display"** or **"Choose Display"**
3. Select your TV/monitor from the list

---

# What you're looking for

## ✅ SUCCESS

- **TV/monitor:** the 3DS **top screen** (the wide gameplay view), and *only* that
- **Phone:** the 3DS **bottom screen** (the touch screen), and *only* that
- Both update live as you play
- Touch controls still work on the phone

**If you see this — that IS Emul8or, over a cable.** The mechanism works. The remaining job is
swapping the cable for Wi-Fi, which is real work, but it's *plumbing*, not invention.

## ⚠️ PARTIAL

- The TV shows **both** 3DS screens, or a duplicate of your phone — meaning it's still mirroring,
  not using the secondary display feature. Re-check that "Enable Secondary Display" is ON and that
  you chose the right display in the Quick Menu.
- It works but is laggy on a wireless connection — **fine, and still a pass.** Miracast is much
  slower than what we'll build. We'll use direct, low-latency video encoding instead of generic
  screen mirroring.

## ❌ FAILURE

- Turning the setting on changes nothing
- The second screen stays black
- Azahar crashes

**A failure here is genuinely valuable information**, not a disaster. It would mean Emul8or needs a
different approach to capturing the top screen, and it's enormously better to know that now.

---

# RESULT: ✅ PASS — confirmed 2026-09-22

**Tested on the Samsung Galaxy S24 Ultra (SM-S928U1, Android 16) against a TV, using the Play Store
build of Azahar.**

| Question | Result |
| --- | --- |
| TV showed **only** the 3DS top screen | **Yes** |
| Phone showed **only** the 3DS bottom screen | **Yes** — after also setting the phone's own layout |
| Both screens full-screen, no bezels or borders | **Yes** |
| On-screen controls overlaid on the bottom screen | **Yes** |
| Phone and TV layouts independently configurable | **Yes** |

**The core architectural assumption is validated.** Azahar renders the two 3DS screens to two
independent displays, each with its own layout, on the exact target hardware. Emul8or's job is now to
replace the display with a network stream — plumbing, not invention.

## The important detail: two settings, not one

Enabling the secondary display is **not** sufficient on its own. Two separate layouts must be set:

| Screen | Setting | Value |
| --- | --- | --- |
| **TV** (secondary) | Settings → Layout → **Secondary Display Layout** | **Top Screen** |
| **Phone** (primary) | Settings → Layout → **Screen Layout** | **Single Screen** (landscape) |

Without the second one, the phone keeps drawing *both* 3DS screens while the TV shows the top screen
— so the top screen appears twice and the bottom screen is small.

This maps directly onto Emul8or's design, and confirms the two-sided layout switching described in
[architecture.md](architecture.md) §7 is necessary. When a secondary device connects, Emul8or must
change the layout on **both** ends, not just start streaming. When it disconnects, the primary must
restore a dual-screen layout — which is exactly the pause-then-relayout behaviour already specified.

### A shortcut worth knowing: "Opposite Screen"

Reading the layout code afterwards (`framebuffer_layout.cpp`, `AndroidSecondaryLayout`), the
secondary layout list has an **Opposite Screen** option that is the default. It renders
`SingleFrameLayout(..., !swap_screen, ...)` — that is, **automatically whichever screen the phone is
not showing.**

So an equivalent and more robust configuration is:

- Phone → **Single Screen**
- TV → **Opposite Screen**

Then the phone's "Swap Screens" button flips *both* displays in one action, keeping them
complementary. Emul8or should prefer this coupling rather than pinning each side independently, since
it cannot desynchronise into showing the same screen twice.

## What this rules in

- ✅ Two independent surfaces with independent layouts — real, shipping, working on the S24 Ultra.
- ✅ Full-screen output with no forced bezels or letterboxing on either end.
- ✅ Control overlay already composites over the bottom screen on the phone, satisfying the
  "controls overlay, not a third panel" requirement in [architecture.md](architecture.md) §7 for
  free.
- ✅ The primary's appearance in dual-device mode is exactly what Emul8or's Primary mode should look
  like. That UI is inherited, not built.

## What is still unproven

This test used a **real display** (HDMI/cast). It does **not** yet prove the remaining question,
which stays the project's highest risk:

> Will `NativeLibrary.secondarySurfaceChanged()` accept a **`MediaCodec` encoder input surface**
> in place of a display surface?

That is [architecture.md](architecture.md) §10 question 1, and it is still the first thing to
prototype in phase 6. What this test *does* establish is that everything upstream of that surface —
dual rendering, independent layouts, full-screen output — already works. The unknown is now narrowed
to a single API handoff rather than the whole mechanism.

---

<details>
<summary>Original blank results template</summary>

```
Date:
Method used:            (Chromecast / Fire Stick / smart TV / HDMI adapter / DeX)
Second screen device:

Did the TV show ONLY the top screen?        yes / no
Did the phone show ONLY the bottom screen?  yes / no
Did touch controls still work?              yes / no
Did the game run at normal speed?           yes / no

If wireless — roughly how laggy? (none / slight / bad / unplayable)

Anything unexpected:
```

</details>

---

# Why this is worth ten minutes

Right now, `architecture.md` §10 lists this as **the project's highest-risk unknown**. Every plan we
have assumes it's true.

- **If it works** → the risk is gone. We start Phase 1 knowing the foundation holds, and Phase 6
  becomes "replace the display with an encoder" rather than a research project.
- **If it fails** → we redesign *now*, before you've spent an afternoon setting up a build
  environment for an approach that wouldn't have worked.

Either result is a win. The only bad outcome is not knowing.

---

## One more thing worth noticing

Pay attention to **how the phone behaves** while the second screen is active. Does the bottom screen
fill the whole phone display? Are the on-screen controls laid out sensibly over it?

That's exactly what Emul8or's Primary mode should look like. If Azahar already handles it well, we
inherit that. If it looks awkward, that's a UI problem we've now identified early — see
[architecture.md](architecture.md) §7.
