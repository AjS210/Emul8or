# Why These PRs Stall — Evidence, Not Guesswork

Investigated 2026-09-22, prompted by the question: *were any notes left as to why PR #943 was
abandoned? My first expectation is latency issues.*

**Answer: no notes exist, and it was not latency.** The evidence points somewhere less technical and
more useful.

---

## 0. Naming correction

PR #943 is **[a Lemuroid pull request by `jfalxa`](https://github.com/Swordfish90/Lemuroid/pull/943)**
— *"Add more screen layout option for NDS emulators"*.

It has **nothing to do with DualMelon**, which is a separate melonDS-android fork by `Liprax`. Three
distinct pieces of prior art keep coming up and they are easy to conflate:

| | What | Who | Where |
| --- | --- | --- | --- |
| PR #2343 | 3DS bottom-screen streaming to a 2nd device | Ufoex | Azahar |
| DualMelon | Two phones as one DS | Liprax | melonDS-android fork |
| **PR #943** | **More NDS screen layout options** | **jfalxa** | **Lemuroid** |

---

## 1. What the thread actually contains

Queried via the GitHub API — issue comments, inline review comments, and formal reviews:

```
issue comments:   0
review comments:  0
reviews:          0
```

**Nothing. Not one word from anybody, including the maintainer.**

- Opened **22 Aug 2024**
- Last updated **22 Aug 2024** — the same day
- Never touched again by anyone

There is no abandonment note because **there was never a conversation to abandon**. The author opened
it, and silence followed.

---

## 2. It was not latency

Worth ruling out explicitly, since that was the expectation.

PR #943 touches **three files, +71 −3**:

```
lemuroid-touchinput/.../LemuroidTouchConfigs.kt    +20 -0
retrograde-app-shared/.../library/GameSystem.kt    +43 -2
retrograde-app-shared/src/main/res/values/strings.xml  +8 -1
```

That is **configuration plumbing** — exposing core options that DeSmuME and melonDS already
implement, plus a swap button. No rendering code, no networking, no new threads. There is no
mechanism by which it could introduce latency, and no performance claim was ever made or contested.

The instinct was reasonable but the diff rules it out.

---

## 3. What actually happened: the author left

`jfalxa`'s total contribution history to Lemuroid:

```
total PRs to Lemuroid: 1
  #943  open  2024-08-22  Add more screen layout option for NDS emulators
```

`author_association: NONE` — a first-time drive-by contributor. They filed one PR, got no response,
and never returned. Their fork `jfalxa/Lemuroid` still exists; their account was active as recently
as July 2026. **They did not lose interest in GitHub. They lost interest in this.**

---

## 4. The maintainer is not absent — he is a bottleneck

This is the important part, and it is the opposite of the obvious conclusion.

Lemuroid is **not** abandoned. Recent commits:

```
2026-05-22  Konubinix    Add SNES port 1 to match snes9x's 2-port default (#1137)
2026-04-19  Swordfish90  Bump version code and cores.
2026-03-28  Swordfish90  Fix github actions breaking. (#1101)
2026-03-28  Swordfish90  Fix black screen on notification click. (#1099)
2026-03-14  Swordfish90  Add tentative background save handling (#1094)
```

Active. Shipping. Merging things.

But look at the **21 open PRs**:

| PR | Opened | Author | Title |
| --- | --- | --- | --- |
| #104 | 2020-10-07 | tytydraco | Fix typo for external folder preference |
| #133 | 2020-11-27 | ashishekka97 | Add support for 7zip compressed ROMs |
| #627 | 2023-03-20 | ixiumu | fix thumbnails url |
| **#943** | **2024-08-22** | **jfalxa** | **Add more screen layout option for NDS emulators** |
| #984 | 2025-01-06 | amnore | snes9x: add block vram access option |
| #1064 | 2025-10-16 | grantland | Implement viewport alignment |
| #1095 | 2026-03-20 | oscaruiz | feat(nds): expose firmware language setting for melonDS |
| #1150 | 2026-07-01 | theBaffo | Add "Viewport Alignment" in General Settings |
| #1174 | 2026-09-02 | matheuspaulo93 | Fix/dual joycon single controller |

**A typo fix has been open since 2020.** Of the 11 most recently merged PRs, **8 were authored by
Swordfish90 himself**, and the outside merges are one-line changes.

The pattern is unambiguous: **one maintainer who writes his own features and rarely merges anyone
else's.** Not hostile, not inactive — just a single person with limited time and a high bar, and a
queue that outgrew him years ago.

### The corroborating detail

PR #1071, *"Deprecated desmume and lazily migrate in-game saves to melonds"* (merged Nov 2025, 11
files, +279 −25) — authored by the maintainer.

So **fourteen months after** jfalxa offered DS screen layout options, the maintainer did significant
DS core work himself, and still did not merge or close #943. It was not rejected on technical
grounds. **It was never looked at.**

---

## 5. What this actually means for Emul8or

Three independent pieces of prior art, three identical fates:

| Prior art | Status | Why it stalled |
| --- | --- | --- |
| PR #2343 (Azahar) | Open, `dirty`, 112 behind | Zero maintainer engagement |
| DualMelon | 1 release, 18 behind parent | Solo dev, no upstreaming attempt |
| PR #943 (Lemuroid) | Open, `dirty`, zero comments | Zero maintainer engagement |

**None of them failed technically.** Nobody hit a latency wall, a licensing wall, or an architectural
wall. In every case the code worked and then ran out of human attention.

### The two conclusions that follow

**1. The feature gap is real and is not a trap.** The recurring worry — *"if this were a good idea
someone would have done it"* — is answered: people **did** do it. Repeatedly. It works. The reason it
is not in your hands is upstream throughput, not feasibility.

**2. Do not plan on upstreaming.** This retroactively validates the standing downstream-only
decision, and extends it beyond Azahar. A fork of Lemuroid/LibretroDroid should assume **nothing goes
back upstream**. Build the fork to stand alone, rebase periodically, and treat any merge as a bonus.

That is not a hostile stance towards these projects. It is the observable reality of one-maintainer
repositories, and planning around it is the difference between shipping and becoming the fourth
entry in this table.

---

## 6. The risk this actually surfaces

Not latency. **Attrition.**

Every project in that table died because one person stopped. That is the failure mode to design
against:

- **Keep the diff small.** PR #943 was 3 files; the LibretroDroid crop is ~5. Small diffs survive
  rebases; large ones rot. The ~12-file ceiling in
  [upstream-integration.md](upstream-integration.md) §6 is the right instinct.
- **Ship something usable early.** DualMelon got one release out and 29 people used it. That beats a
  perfect unreleased branch.
- **Write down why, not just what.** Every stalled project here is unreadable to a newcomer because
  the reasoning was never recorded. This repo's documentation habit is the direct countermeasure.

---

## 7. Summary

| Question | Answer |
| --- | --- |
| Were notes left explaining the abandonment? | **No.** Zero comments, zero reviews, zero maintainer words — ever |
| Was it latency? | **No.** 3 files, +71−3, pure config plumbing exposing existing core options |
| Was it rejected? | **No.** It was never reviewed. Still open, still `dirty` |
| Did the author give up on GitHub? | No — active as of Jul 2026. He gave up on *this* |
| Is Lemuroid abandoned? | **No.** Actively maintained and shipping |
| So what went wrong? | One maintainer, 21 open PRs, a typo fix from 2020, 8 of 11 recent merges self-authored |
| Lesson for Emul8or | **Plan downstream-only.** Guard against attrition, not latency |
