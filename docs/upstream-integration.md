# Upstream Integration Plan

How Azahar source gets into Emul8or, and the exact plan for building it **unmodified** before any
Emul8or feature work begins.

This is the execution plan for [roadmap](../ROADMAP.md) phases 1 and 2. Background research is in
[azahar-build-research.md](azahar-build-research.md).

---

## 1. The rule

**Build unmodified Azahar, on the real device, before changing anything.**

This is worth stating plainly because it is tempting to skip. Azahar's Android build involves ~35
submodules, an exact NDK version, a CMake project rooted three directories above the Gradle project,
and a network-dependent pre-build step. Any of those can fail.

If Emul8or changes land first and the build breaks, there is no way to tell whether the cause is our
code or an environment problem that was there all along. A known-good baseline turns every later
failure into a diff.

**Phase 1 ends with a working APK containing zero Emul8or code.**

---

## 2. Baseline pin

| | |
| --- | --- |
| Upstream | `https://github.com/azahar-emu/azahar.git` |
| Remote name | `upstream` |
| Baseline tag | **`2126.1.2`** (released 2026-09-20) |
| Local tag alias | `azahar-2126.1.2` |
| Commit | `9e6f523a57fac9564ac0bf8286db3c3702d301ec` |
| Licence | GPL-2.0-or-later |

**Pin to a tag, not `master`.** Azahar commits daily. Tracking `master` means the base moves
underneath every rebase, and a build failure could be upstream's, ours, or simply a bad day on their
main branch. Tags are tested release points.

Config verified at this exact tag:

```
compileSdkVersion = "android-35"
ndkVersion        = "27.3.13750724"
applicationId     = "org.azahar_emu.azahar"
minSdk            = 29
targetSdk         = 37
```

These match the research doc, so the toolchain requirements in
[development-environment.md](development-environment.md) are correct for this baseline.

---

## 3. Adding the upstream remote

```bash
./scripts/setup-upstream.sh
```

Or manually:

```bash
git remote add upstream https://github.com/azahar-emu/azahar.git
git fetch --no-tags --depth=1 upstream refs/tags/2126.1.2:refs/tags/azahar-2126.1.2
```

> **Why a script.** Git remotes live in `.git/config`, which is local to a clone and not part of the
> committed tree. Anyone cloning Emul8or gets no `upstream` remote. Scripting it means the baseline
> pin is version-controlled rather than folklore.

To inspect upstream without importing it:

```bash
git show azahar-2126.1.2:src/android/app/build.gradle.kts
git ls-tree azahar-2126.1.2 src/android/
```

---

## 4. Vendoring strategy

**Decision: merge upstream history into this repository, pinned to a tag.**
(Option A in the research doc.)

```bash
git fetch --tags upstream
git merge --allow-unrelated-histories azahar-2126.1.2
```

The first merge brings the whole Azahar tree in alongside the existing docs. Subsequent upstream
adoption is an ordinary merge of a newer tag.

**Why not a submodule.** Azahar's Gradle project reaches up to the repository root for CMake
(`path = file("../../../CMakeLists.txt")`). A submodule would require restructuring the build against
the grain of upstream, and that restructuring becomes a permanent maintenance cost.

**Why not a GitHub fork.** The "forked from" relationship complicates Emul8or's independent branding,
which [legal.md](legal.md) requires.

### `.gitignore` collision check — done

An overly broad ignore rule can silently swallow a legitimate upstream file during the merge, and
that is a slow, irritating bug to find. So this was checked against the pinned tag rather than left
as a warning:

```bash
git ls-tree -r --name-only azahar-2126.1.2 | grep -E '\.(bin|a|so|o|class|dex|log|apk)$'
```

**Result: zero matches across all 2,327 tracked upstream files.** Emul8or's ignore rules are safe for
this merge.

The ROM/key patterns in `.gitignore` were nevertheless narrowed as a result — a blanket `*.bin` was
replaced with specific filenames (`boot9.bin`, `nand.bin`, `seeddb.bin`, …), since `*.bin` is exactly
the kind of rule that would eventually catch a legitimate upstream test fixture. Re-run the check
above when bumping to a newer upstream tag.

### Submodules after the merge

Azahar's `.gitmodules` arrives with the merge, but submodule contents do not. After merging:

```bash
git submodule update --init --recursive
```

Expect several GB. This is non-optional — CMake configure fails without it, and the error message
does not mention submodules.

---

## 5. Phase 1 execution checklist

Run in order. Do not skip ahead.

### 1. Environment

Follow [development-environment.md](development-environment.md), then verify:

```bash
java -version                                  # 17.x
ls "$ANDROID_HOME/ndk/27.3.13750724"           # exists
ls "$ANDROID_HOME/cmake/3.30.3"                # exists
adb devices                                    # S24 Ultra present
ccache -s
```

All five must pass before continuing. Environment problems discovered mid-build are much harder to
attribute.

### 2. Build upstream standalone, outside this repository

Deliberately separate from the Emul8or checkout. This validates the toolchain against a pristine
tree, with nothing of ours anywhere near it.

```bash
cd ~/src
git clone --recursive https://github.com/azahar-emu/azahar.git azahar-baseline
cd azahar-baseline
git checkout 2126.1.2
git submodule update --init --recursive

export NDK_CCACHE=$(which ccache)
cd src/android
./gradlew assembleVanillaRelWithDebInfo
```

Allow 30–60+ minutes for the cold build. Requires network access for the Vulkan validation layers
download in `preBuild`.

### 3. Install and verify on the S24 Ultra

```bash
adb install -r app/build/outputs/apk/vanilla/relWithDebInfo/*.apk
```

Verify, in order:

- [ ] App launches without crashing.
- [ ] Setup flow completes; storage permission grants.
- [ ] Game list renders.
- [ ] A user-supplied, legally-dumped title boots.
- [ ] Audio works.
- [ ] Touch input on the bottom screen works.
- [ ] Layout switching works.
- [ ] Virtual controls appear as an overlay, not a reserved panel.

**No test content is committed to this repository.** Use your own dumps. See [legal.md](legal.md).

### 4. Probe the secondary-display path

Still with unmodified Azahar, because this determines Emul8or's whole architecture.

- [ ] Find the secondary-display setting in Azahar's UI (`ENABLE_SECONDARY_DISPLAY`).
- [ ] Enable it with Samsung DeX or an HDMI adapter, if available.
- [ ] Confirm `SecondaryDisplayLayout::TOP_SCREEN` renders the top screen alone on the second display.
- [ ] Capture logcat during surface attach and detach — this is the code path Emul8or will drive.

If the S24 Ultra's DeX mode can demonstrate the top screen on a separate display, the mechanism
Emul8or intends to hijack is confirmed working on the target hardware, before a line of our code
exists.

### 5. Record everything

Append to [azahar-build-research.md](azahar-build-research.md):

- [ ] Cold build wall-clock time and host specs.
- [ ] ccache hit rate (`ccache -s`).
- [ ] Every error hit and its fix — these become the troubleshooting table.
- [ ] Any drift between documented and actual config.
- [ ] Observed behaviour of the secondary-display path.
- [ ] APK size, for later comparison.

### 6. Import into Emul8or

Only after all of the above passes:

```bash
cd /path/to/Emul8or
./scripts/setup-upstream.sh
git fetch --tags upstream
git merge --allow-unrelated-histories azahar-2126.1.2
git submodule update --init --recursive
cd src/android && ./gradlew assembleVanillaRelWithDebInfo
```

- [ ] Build succeeds identically inside the Emul8or repository.
- [ ] Resulting APK behaves identically to the standalone build.
- [ ] Commit the merge with no functional changes of our own.

**Phase 1 exit criterion:** unmodified Azahar, built from the Emul8or repository, boots a game on the
S24 Ultra.

---

## 6. Keeping the patch surface small

Every upstream file Emul8or touches is a future merge conflict. The discipline:

1. **New code lives in `emul8or/`.** Never inside `org.citra.citra_emu` packages.
2. **Upstream edits are hooks, not logic.** Ideally one call out to Emul8or code.
3. **Every touch point is recorded** in the table below, with a reason.
4. **Generally-useful changes get upstreamed**, so we stop carrying them — subject to Azahar's
   [AI policy](https://github.com/azahar-emu/azahar/blob/master/AI-POLICY.md), which governs anything
   we send them.

### Upstream touch point register

Maintained as changes land. Empty until phase 2.

| File | Change | Reason | Upstreamable? |
| --- | --- | --- | --- |
| *(none yet)* | | | |

Planned, from the research:

| File | Planned change | Reason |
| --- | --- | --- |
| `src/android/app/build.gradle.kts` | `minSdk 29 → 28`; applicationId; app name | Note 8 support; branding |
| `src/android/app/src/main/AndroidManifest.xml` | Relax `uses-feature`; role-selection launcher | Secondary on API 28 |
| Launcher entry point | Route to role selection before `MainActivity` | Two-mode APK |
| `display/SecondaryDisplay.kt` or sibling | Network-backed secondary surface | The streaming hook |

Four files. If this list passes roughly a dozen, the approach needs rethinking before it becomes
unmaintainable.

---

## 7. Adopting newer upstream releases

```bash
git fetch --tags upstream
git log --oneline azahar-<current>..<new-tag> -- src/android/    # what changed on Android
git merge <new-tag>
git submodule update --init --recursive
cd src/android && ./gradlew assembleVanillaRelWithDebInfo
```

Adopt deliberately, not automatically. Before each bump, check whether upstream changed `minSdk`,
the NDK or CMake version, or anything in `display/` or `jni/` — those are the areas Emul8or depends
on, and a change there is a signal to read the diff carefully rather than merge and hope.

---

## 8. Compliance reminders

- **Keep upstream copyright headers intact.** Do not strip Citra/Azahar attribution.
- **Note modifications** in files that are substantially changed.
- **Emul8or's own code is GPL-2.0-or-later too** — it is part of a derivative work.
- **No Azahar or Citra artwork.** The Azahar logo is the property of PabloMK7 and angyartanddraw and
  is not covered by the GPL grant.
- **Never commit** ROMs, keys, BIOS, firmware, or system files. `.gitignore` blocks the common
  extensions, but that is a safety net, not a policy.

Full detail in [legal.md](legal.md).
