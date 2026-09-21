# Azahar Build Research

Research into upstream Azahar's Android build, and how Emul8or should sit on top of it.

**Researched:** 2026-09-21
**Upstream:** https://github.com/azahar-emu/azahar
**Default branch:** `master`
**Latest stable tag:** `2126.1.2` (released 2026-09-20)
**Licence:** GPL-2.0-or-later

All findings below were read from the upstream repository at the date above. Re-verify before acting
on them; the project commits daily.

---

## 1. What Azahar is

Azahar is the successor to Citra, formed by merging PabloMK7's Citra fork with Lime3DS after Citra
shut down in 2024. It is the most active 3DS emulator project — roughly 8,200 stars, daily commits —
and is GPL-2.0-or-later.

It is the right base for Emul8or: actively maintained, compatible licence, mature Android support,
and — crucially — it already has a secondary-display subsystem (§6).

---

## 2. Repository layout

```
azahar/
├─ CMakeLists.txt          top-level CMake — drives the native build on all platforms
├─ src/
│  ├─ android/             Android app (Gradle project root)
│  │  ├─ build.gradle.kts  top-level Gradle config
│  │  ├─ app/
│  │  │  ├─ build.gradle.kts
│  │  │  └─ src/main/
│  │  │     ├─ AndroidManifest.xml
│  │  │     ├─ java/org/citra/citra_emu/   Kotlin/Java sources
│  │  │     └─ jni/                        JNI glue → C++ core
│  │  └─ gradlew
│  ├─ core/                emulator core
│  ├─ video_core/          renderer (OpenGL + Vulkan)
│  ├─ audio_core/
│  ├─ common/
│  ├─ network/             multiplayer (ENet)
│  └─ citra_qt/            desktop frontend — not built for Android
├─ externals/              ~35 git submodules
├─ .ci/android.sh          CI build script
└─ .github/workflows/build.yml
```

The Android app is **not** a standalone Gradle project — it reaches up into the repository root and
builds the C++ core via CMake (`path = file("../../../CMakeLists.txt")`). Consequences: you cannot
extract `src/android` on its own, and submodules are mandatory.

Note the package name is still `org.citra.citra_emu` and the namespace is `org.citra.citra_emu`,
while `applicationId` is `org.azahar_emu.azahar`. Historical, and worth knowing before grepping.

---

## 3. Android build configuration

From `src/android/app/build.gradle.kts` as of 2026-09-21:

| Setting | Value |
| --- | --- |
| `namespace` | `org.citra.citra_emu` |
| `applicationId` | `org.azahar_emu.azahar` |
| `compileSdkVersion` | `android-35` |
| **`minSdk`** | **`29`** ← the Emul8or problem |
| `targetSdk` | `37` |
| `ndkVersion` | `27.3.13750724` |
| CMake | `3.25.0+` (CI installs `3.30.3`) |
| Java / Kotlin JVM target | 17 |
| ABI filters | `arm64-v8a`, `x86_64` |
| AGP | 8.13.2 |
| Kotlin | 2.0.20 |

**Build types:** `debug`, `release`, `relWithDebInfo` (the default), `relWithDebInfoLite`.
**Product flavours:** `vanilla` (default) and `googlePlay` (`applicationId io.github.lime3ds.android`).

The Google Play flavour exists because Play's storage policy forbids the faster file-management
approach the Vanilla build uses. Emul8or targets sideloading, so **Vanilla is the relevant flavour**.

CMake arguments passed by Gradle:

```
-DENABLE_QT=0
-DENABLE_SDL2=0
-DANDROID_ARM_NEON=true
-DANDROID_SUPPORT_FLEXIBLE_PAGE_SIZES=ON   # Android 15 16 KiB pages
-DENABLE_GDBSTUB=OFF
```

`preBuild` downloads and unpacks the Khronos Vulkan validation layers, so **the first build needs
network access**.

`jniLibs.useLegacyPackaging = true` is required for `libadrenotools` custom driver loading. Do not
"clean this up".

---

## 4. Manifest and permissions

Declared hardware requirements:

```xml
<uses-feature android:glEsVersion="0x00030002" android:required="true" />
<uses-feature android:name="android.hardware.opengles.aep" android:required="true" />
```

These are **required**, meaning Play filtering and some installers will reject devices lacking
OpenGL ES 3.2 + AEP. Relevant to Emul8or: a Secondary-only device does not need either, so if the
Secondary role is ever split out, these must be relaxed for it.

Permissions requested: `INTERNET`, `ACCESS_NETWORK_STATE`, `CAMERA`, `RECORD_AUDIO`,
`POST_NOTIFICATIONS`, `MANAGE_EXTERNAL_STORAGE`, `WRITE_EXTERNAL_STORAGE`.

`MANAGE_EXTERNAL_STORAGE` is a heavyweight permission that Secondary mode has no business holding.
Emul8or should declare it conditionally or explain clearly at role selection why it is not needed.

Activities: `MainActivity`, `SettingsActivity`, `EmulationActivity`, `CheatsActivity`.

---

## 5. The minSdk problem

**Upstream: `minSdk = 29` (Android 10). Our secondary test device is Android 9 (API 28).**

### Why upstream sits at 29

Not documented in a single place, but the contributing factors are visible:

- Scoped storage and the Storage Access Framework paths the file management relies on.
- Vulkan 1.1 expectations, which are far more consistently present from Android 10.
- `libadrenotools` custom GPU driver loading.
- Modern `MediaCodec` and surface behaviours.
- General maintenance burden — dropping old releases is free for upstream.

A code search for `@RequiresApi` in the upstream tree returns only two hits
(`GrantMissingFilesystemPermissionFragment.kt`, `SetupFragment.kt`), both in storage-permission UI.
That is encouraging: **explicit API-29+ gating is rare, and concentrated in exactly the subsystem
Secondary mode does not use.** It is not proof — implicit API usage will not show up in that search
— but it suggests the floor is conservative rather than deeply load-bearing.

### The Emul8or plan: split minSdk by role

1. **Lower the manifest `minSdk` to 28** so the APK installs on the Note 8.
2. **Gate Primary mode at runtime.** On `Build.VERSION.SDK_INT < 29`, role selection offers Secondary
   only, with a clear explanation. No crash, no half-working emulator.
3. **Keep Secondary's code path API-28-clean.** It needs only `MediaCodec`, `SurfaceView`,
   `NsdManager`, and sockets — all long predating API 28.
4. **Never load the native library in Secondary mode.** The `.so` is still packaged, but
   `System.loadLibrary` is never called, so nothing inside it can execute on an unsupported OS.
5. **Relax the `uses-feature` requirements** or mark them `required="false"`, since a Secondary
   device needs no OpenGL ES AEP.
6. **Enforce with tooling, not discipline** — a lint baseline or a separate Gradle module with its
   own `minSdk 28` so `NewApi` violations in Secondary code fail the build.

### Risks

| Risk | Mitigation |
| --- | --- |
| A library dependency itself requires API 29+ | Audit AndroidX versions; several are 29+ in places. May need a Secondary-specific dependency set |
| Implicit API-29+ usage in shared code | The role-split module boundary plus lint catches this |
| APK size — the native `.so` ships to devices that never use it | Acceptable initially. ABI splits later if needed |
| Upstream raises `minSdk` to 30+ | Our patch grows. Keep the change to a single line plus a runtime gate so it rebases trivially |

### Plan B

If the split proves unworkable, ship a separate lightweight `emul8or-screen` APK with `minSdk 28`
that shares only the networking and decoder modules. This contradicts the one-APK goal and should be
a last resort — but it is a guaranteed escape hatch, and it is worth knowing it exists.

**Precedent:** the AzaharPlus fork advertises Android 9 support, which is evidence that API 28 is
achievable even for full emulation. Worth examining how they did it — though note AzaharPlus also
bundles system-file downloading from Nintendo servers, which is **explicitly out of bounds** for
Emul8or. Study the minSdk approach only.

---

## 6. The secondary-display subsystem — the key finding

**Azahar already renders the top and bottom screens to two independent surfaces.**

This was built for physical external displays — Samsung DeX, HDMI, Presentation API targets — but it
is exactly the seam Emul8or needs.

### Upstream components

**`src/android/app/src/main/java/org/citra/citra_emu/display/SecondaryDisplay.kt`**

A `DisplayManager.DisplayListener` that creates a `VirtualDisplay` and shows a `Presentation` on a
secondary display. It calls:

```kotlin
NativeLibrary.secondarySurfaceChanged(surface)
NativeLibrary.secondarySurfaceDestroyed()
```

**`NativeLibrary.kt`**

```kotlin
external fun surfaceChanged(surf: Surface)
external fun surfaceDestroyed()
external fun secondarySurfaceChanged(secondary_surface: Surface)
external fun secondarySurfaceDestroyed()
external fun onSecondaryTouchEvent(xAxis: Float, yAxis: Float, pressed: Boolean): Boolean
external fun onSecondaryTouchMoved(xAxis: Float, yAxis: Float)
```

**`src/android/app/src/main/jni/native.cpp`**

```cpp
ANativeWindow* s_surface;
ANativeWindow* s_secondary_surface;
std::unique_ptr<EmuWindow_Android> window;
std::unique_ptr<EmuWindow_Android> secondary_window;
```

Both OpenGL and Vulkan paths construct a second `EmuWindow_Android` with `is_secondary = true`.
Surface lifetime is guarded by a recursive mutex and a condition variable — upstream has clearly
been burned by surface teardown races, and the comments say so. **Emul8or's encoder surface must
respect the same discipline.**

**`display/ScreenLayout.kt`**

```kotlin
enum class SecondaryDisplayLayout(val int: Int) {
    NONE(0), TOP_SCREEN(1), BOTTOM_SCREEN(2), SIDE_BY_SIDE(3),
    REVERSE_PRIMARY(4), ORIGINAL(5), HYBRID(6), LARGE_SCREEN(7)
}
```

`TOP_SCREEN` is precisely Emul8or's dual-phone configuration.

**`src/core/frontend/framebuffer_layout.h`**

```cpp
FramebufferLayout AndroidSecondaryLayout(u32 width, u32 height);
FramebufferLayout FrameLayoutFromResolutionScale(u32 res_scale, bool is_secondary = false, ...);
```

### What this means for Emul8or

The integration reduces to: **give the emulator a `MediaCodec` encoder input surface instead of a
`Presentation` surface.**

```kotlin
val codec = MediaCodec.createEncoderByType("video/avc")
codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
val inputSurface = codec.createInputSurface()
NativeLibrary.secondarySurfaceChanged(inputSurface)
codec.start()
```

If this works unmodified, Emul8or needs **no renderer changes at all** — the top screen goes from
GPU to encoder without a CPU readback, which is the difference between hitting the latency target
and not.

### What must be validated, early

1. Does the native side accept an encoder input surface? EGL/Vulkan surface creation against a
   `MediaCodec` input surface is normally fine, but the Vulkan path in particular needs checking.
2. At what resolution does the secondary window render — encoder-requested, or internal scale?
3. Can the secondary surface be swapped at runtime without restarting emulation?
4. Does `SecondaryDisplayLayout::TOP_SCREEN` behave correctly when the secondary is not a real
   display?
5. Does upstream's Presentation-based path conflict with ours? Likely mutually exclusive.

**This is the highest-risk unknown in the project.** Prototype it as the first task in roadmap phase
6 — before any protocol work — because a negative answer changes the architecture.

---

## 7. Also relevant: existing multiplayer

`src/network/` implements ENet-based multiplayer with a room server, and `jni/multiplayer.cpp`
exposes it to Android. This is **not** what Emul8or needs — it synchronises emulated console
networking between separate emulator instances, whereas Emul8or streams pixels from one instance to
a dumb display.

Worth knowing it exists so the two are not confused, and worth reading for house style on
networking code that might be upstreamed.

---

## 8. Build process

### CI (`.ci/android.sh`)

```bash
export NDK_CCACHE=$(which ccache)
cd src/android
chmod +x ./gradlew
./gradlew assembleVanillaRelease
./gradlew bundleVanillaRelease
```

The GitHub Actions android job: `ubuntu-latest`, checkout with `submodules: recursive`, caches
`~/.gradle/caches`, `~/.gradle/wrapper`, and the ccache directory, installs
`cmake;3.30.3` via `sdkmanager`, then builds with `JAVA_HOME=$JAVA_HOME_17_X64`.

### Local build

```bash
git clone --recursive https://github.com/azahar-emu/azahar.git
cd azahar
git submodule update --init --recursive     # if --recursive was missed
cd src/android
./gradlew assembleVanillaRelWithDebInfo
```

Output lands in `src/android/app/build/outputs/apk/vanilla/relWithDebInfo/`.

### Practical notes

- **Submodules are non-negotiable.** ~35 of them. A non-recursive clone fails at CMake configure
  with errors that do not obviously say "you forgot submodules".
- **First build is slow** — 30–60+ minutes on a typical machine. The C++ core is large. `ccache` is
  strongly advised and is what CI uses.
- **Network required on first build** for the Vulkan validation layers download.
- **Exact NDK version matters.** Install `27.3.13750724`; a different NDK may configure and then
  fail in strange ways.
- **JDK 17 exactly.** Newer JDKs break AGP 8.13.
- `relWithDebInfo` is the default variant and the right one for development — release-optimised but
  debuggable.

---

## 9. Adding Azahar as upstream

Emul8or's repository is currently empty apart from documentation. Azahar source needs to arrive in a
way that makes ongoing rebases tractable.

### Step 1 — add the remote

```bash
git remote add upstream https://github.com/azahar-emu/azahar.git
git fetch upstream --tags
```

### Step 2 — choose a vendoring strategy

**Option A — merge upstream history into this repository (recommended).**

```bash
git fetch upstream
git merge --allow-unrelated-histories upstream/master
# or pin to the stable tag:
git merge --allow-unrelated-histories 2126.1.2
```

- Full history, ordinary `git merge upstream/master` to update, conflicts resolved normally.
- Emul8or code lives in its own `emul8or/` tree, so conflicts concentrate in the few upstream files
  we actually touch.
- Large repository, and our commits and upstream's are interleaved.

**Option B — git submodule.**

- Clean separation, trivial upstream updates.
- But Azahar's Android build is not structured for it — the Gradle project reaches into the
  repository root for CMake. Making this work means restructuring the build, which is a large
  investment against the grain of upstream. **Not recommended.**

**Option C — hard fork on GitHub.**

- Simplest to start. But GitHub forks cannot be renamed into an independent project cleanly, and the
  "forked from" relationship complicates Emul8or's independent branding.

**Recommendation: Option A, pinned to a release tag rather than `master`.** Upstream commits daily;
a moving base makes every rebase a surprise. Pin to `2126.1.2`, get a build working, then adopt new
tags deliberately.

### Step 3 — keep the patch surface small

Every upstream file Emul8or modifies is a future merge conflict. Rules:

1. New code goes in `emul8or/`, never inside `org.citra.citra_emu` packages.
2. Upstream modifications should be the minimum hook needed — ideally a single call into Emul8or code.
3. Document every upstream touch point in a table in this file, with the reason.
4. Where a change is general-purpose and Azahar would plausibly want it, **upstream it** — compliant
   with Azahar's [AI policy](https://github.com/azahar-emu/azahar/blob/master/AI-POLICY.md) — so we
   stop carrying it.

Expected touch points, kept deliberately short:

| File | Change | Why |
| --- | --- | --- |
| `src/android/app/build.gradle.kts` | `minSdk 29 → 28`, applicationId, app name | Note 8 support, branding |
| `AndroidManifest.xml` | Relax `uses-feature`, add role-selection entry activity | Secondary on API 28 |
| Launcher entry point | Route to role selection before `MainActivity` | Two-mode APK |
| `SecondaryDisplay.kt` or a sibling | Provide a network-backed secondary surface | The streaming hook |

Four files. If that list grows much past a dozen, the approach needs rethinking.

---

## 10. Open questions

1. Does the native secondary-window path accept a `MediaCodec` input surface? **Blocking; test first.**
2. Exactly which API-29+ calls exist in the code paths Secondary mode touches?
3. Will the AndroidX dependency set resolve at `minSdk 28`, or does Secondary need its own?
4. How did AzaharPlus achieve Android 9 support? (Study the approach only — its system-file
   downloading is out of bounds for Emul8or.)
5. Does Azahar's frame pacing interact badly with an encoder surface's buffer release timing?
6. Can the secondary surface be attached and detached at runtime, or does connecting a phone
   mid-game require an emulation restart?

---

## 11. Sources

- Upstream repository — https://github.com/azahar-emu/azahar
- `src/android/app/build.gradle.kts`, `src/android/build.gradle.kts`
- `src/android/app/src/main/AndroidManifest.xml`
- `src/android/app/src/main/java/org/citra/citra_emu/display/` — `SecondaryDisplay.kt`, `ScreenLayout.kt`
- `src/android/app/src/main/jni/native.cpp`, `jni/emu_window/`
- `src/core/frontend/framebuffer_layout.h`
- `.ci/android.sh`, `.github/workflows/build.yml`
- `AI-POLICY.md`, `license.txt`, `.gitmodules`

All read at upstream `master`, 2026-09-21.
