# Try the Existing Solution First

**Before building Emul8or, spend 20 minutes finding out whether someone else's work already does what
you want.**

If it does, you have saved yourself months — that is a win, not a loss. If it does not, you will know
*exactly* what is missing, which is the best possible specification for what to build.

No compiling. Both APKs are prebuilt.

---

## What you are testing

[Ufoex](https://github.com/Ufoex) built phone-to-phone 3DS screen streaming on top of Azahar. Two
apps, one per phone:

| Phone | App | Role |
| --- | --- | --- |
| **S24 Ultra** | `azahar-network-streaming.apk` | Modified Azahar — runs the game, streams |
| **Note 8** | `azahar-viewer.apk` | Receiver — displays the streamed screen |

Download both from the single release on his fork:

**https://github.com/Ufoex/azahar/releases/tag/network-streaming-v1**

(`azahar-viewer.apk` is also on the [viewer repo's release](https://github.com/Ufoex/azahar-viewer/releases/tag/v1.0.0)
— same app.)

---

## ⚠️ The important difference — read this before testing

**Ufoex streams the BOTTOM screen. Emul8or's plan is to stream the TOP screen.**

These are opposite designs:

| | Ufoex's build | Emul8or's plan |
| --- | --- | --- |
| Streamed to phone 2 | **Bottom** (touch) screen | **Top** (gameplay) screen |
| Phone 2 accepts touch? | **Yes** — a real second touchscreen | **No** — display only |
| Phone 1 shows | Top screen | Bottom screen |
| Apps needed | **Two separate apps** | **One APK**, pick a role |

His design turns phone 2 into the DS-style touch panel. Yours turns phone 2 into the gameplay screen.

**So when testing, judge the *mechanism*, not the arrangement.** The questions that matter are: is the
latency acceptable? does it hold a connection? is it pleasant to use? Whether the right screen is on
the right phone is a configuration difference, not a technical one.

**Also worth trying:** his build may let you combine its streaming with Azahar's existing
Secondary Display Layout setting (which you already found yesterday). If you can set the *phone* to
show only the bottom screen while streaming, you may be able to approximate Emul8or's arrangement.
Worth ten minutes of fiddling — if it works, that is a large finding.

---

## Before you start

- [ ] Both phones on **the same Wi-Fi network** — ideally both on 5 GHz
- [ ] Your own legally-dumped 3DS game
- [ ] "Install unknown apps" permission (Android will prompt you)

> **Safety note.** These are unsigned, third-party APKs from an individual's GitHub — debug-signed, by
> his own description. The source is public and the author is identifiable, which is reassuring, but
> this is still a personal proof of concept. His own README states the stream has **no authentication
> or encryption — anyone on the same LAN can connect.** Fine on your home network; do not run it on
> public Wi-Fi. Consider uninstalling both afterwards if you do not keep using them.
>
> It will install alongside your Play Store Azahar rather than replacing it, since it is a fork with a
> different signature. Your existing setup should be untouched, but your games and keys may need
> re-pointing in the new app.

---

## Steps

### 1. Install the viewer on the Note 8

Download `azahar-viewer.apk` (260 KB) to the Note 8 and tap it to install.

Android 9 will warn about unknown sources — allow it for your browser.

> Note: the viewer is **minSdk 21 (Android 5.0+)** and pure Kotlin with no native code. Your Note 8 is
> comfortably supported. This is also strong evidence for Emul8or's own plan to support Android 9 in
> Secondary mode.

### 2. Install the streaming Azahar on the S24 Ultra

Download `azahar-network-streaming.apk` and install it.

Set it up as you would normally — point it at your games, and at your system files/keys if you use
them.

### 3. Start a game and begin streaming

On the S24 Ultra:

1. Launch a game
2. Open the **in-game menu**
3. Tap **"Stream Bottom Screen to Device…"**

### 4. Connect the Note 8

Open **Azahar Viewer**. It discovers streaming instances automatically over mDNS — no IP typing. Tap
the entry that appears.

### 5. Play

Touch input on the Note 8 is forwarded back to the emulator, so it behaves like the 3DS's real bottom
screen.

---

## What to judge

This is the part that decides the project. Be deliberate.

| Question | Why it matters |
| --- | --- |
| **How bad is the input lag?** | The single most important number. Does touching the Note 8 feel instant, or noticeably behind? |
| **How is the video quality?** | Sharp, or blocky and smeary? |
| **Does it hold a connection?** | Play for 15+ minutes. Any drops, stutters, freezes? |
| **What happens if you walk away / kill Wi-Fi?** | Does it fail gracefully, or does the game carry on unplayable? |
| **How is battery and heat on the S24?** | Emulating *and* encoding is a heavy load |
| **How is the Note 8 holding up?** | 2017 hardware decoding video |
| **Could you actually enjoy a long session on this?** | The honest question underneath all the others |

### Then the decisive one

> **Is this good enough that you would just use it, instead of building your own?**

If **yes** — genuinely, brilliant. You wanted two-phone 3DS; you have it, today, for free. Emul8or
gets archived with its research intact, and you have lost one evening rather than three months.

If **no** — write down exactly *why*. Each reason becomes a requirement. "The lag is fine but it
disconnects and I lose progress" is a far better project brief than anything we wrote from scratch.

---

## What is already known to be missing

Not to talk you into anything — but these gaps are documented, not speculative, and none of them will
show up in a 20-minute test:

- **Two separate apps**, one per phone. Emul8or's plan is one APK with a role picker.
- **No pause on disconnect.** Emul8or pauses emulation and falls back to a local dual-screen layout.
- **No authentication or encryption** (his README).
- **Fixed port, fixed resolution, no settings UI**, single viewer at a time (his README).
- **Streams the wrong screen** for your stated goal.
- **The viewer app has no licence**, which means all rights reserved — it cannot legally be forked or
  reused as a base. Only the Azahar-side PR is GPL.
- **The PR is stale**: merge-conflicted, 112 commits behind Azahar's master, untouched since 1 Aug,
  never reviewed by a maintainer. It will fall further behind.
- **Adoption is tiny**: 3 stars, ~21 downloads.

Whether those matter is entirely your call. A proof of concept that does 80% of what you want may be
plenty.

---

## Record what you find

```
Date:
Game tested:
Wi-Fi band (5 GHz / 2.4 GHz):

Input lag:            none / slight / annoying / unplayable
Video quality:        great / fine / poor
Connection stability: rock solid / occasional hiccup / kept dropping
Battery + heat (S24): fine / warm / hot
Note 8 performance:   fine / struggled

Could you set the phone to show only the bottom screen
while streaming (approximating Emul8or's layout)?   yes / no / didn't try

WOULD YOU JUST USE THIS?     yes / no

If no, the specific reasons:
1.
2.
3.
```

Those reasons are the real deliverable. Bring them back and we will decide what — if anything —
Emul8or should be.
