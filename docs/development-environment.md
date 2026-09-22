# Development Environment

Everything needed to build Emul8or from source.

> **New to this?** This page is a terse reference for people who already build Android projects.
> If you want a walk-through that assumes no prior experience, read
> **[getting-started-windows.md](getting-started-windows.md)** instead.

The versions below are **not suggestions**. They are what upstream Azahar's build is pinned to, and
mismatches produce failures that are slow and confusing to diagnose. Match them.

---

## 1. Required toolchain

| Component | Version | Notes |
| --- | --- | --- |
| **JDK** | **17** | Exactly 17. Newer JDKs break AGP 8.13. CI uses `JAVA_HOME_17_X64` |
| **Android SDK Platform** | **API 35** | `compileSdkVersion = "android-35"` |
| **Android SDK Build-Tools** | 35.x | |
| **Android NDK** | **27.3.13750724** | Exact version string, from `ndkVersion` in `build.gradle.kts` |
| **CMake** | **3.30.3** | Gradle asks for `3.25.0+`; CI installs 3.30.3 via `sdkmanager` |
| **Ninja** | any recent | Usually arrives with the CMake SDK package |
| **Gradle** | via wrapper | Do not install separately — use `./gradlew` |
| **Android Gradle Plugin** | 8.13.2 | Declared in the build files |
| **Kotlin** | 2.0.20 | Declared in the build files |
| **Git** | 2.x | Submodules are essential |
| **ccache** | any recent | Optional but strongly recommended |
| **Python** | 3.x | Some build scripts use it |

**Disk:** allow 40–60 GB. Source plus submodules is several GB; native build artifacts across
variants dwarf that.

**RAM:** 16 GB comfortable, 8 GB workable with reduced parallelism.

---

## 2. Host platform

Linux is the reference — it is what upstream CI uses and the smoothest path.

| Host | Status |
| --- | --- |
| Linux (Ubuntu 22.04/24.04, Fedora, Arch) | Reference. Recommended |
| macOS (Apple Silicon or Intel) | Works; Homebrew for prerequisites |
| Windows | Works via Android Studio; long paths and Gradle daemon memory are the usual friction. WSL2 is often easier |

---

## 3. Setup — Linux

### Prerequisites

```bash
# Debian / Ubuntu
sudo apt update
sudo apt install -y git curl unzip zip ccache ninja-build python3 openjdk-17-jdk

# Fedora
sudo dnf install -y git curl unzip zip ccache ninja-build python3 java-17-openjdk-devel

# Arch
sudo pacman -S --needed git curl unzip zip ccache ninja python jdk17-openjdk
```

Confirm the JDK:

```bash
java -version    # must report 17.x
```

If several JDKs are installed, pin it:

```bash
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH="$JAVA_HOME/bin:$PATH"
```

### Android SDK

Either install Android Studio (which bundles the SDK) or use command-line tools only:

```bash
mkdir -p ~/Android/sdk/cmdline-tools
cd ~/Android/sdk/cmdline-tools
curl -O https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
unzip commandlinetools-linux-11076708_latest.zip
mv cmdline-tools latest
```

Environment — add to `~/.bashrc` or `~/.zshrc`:

```bash
export ANDROID_HOME="$HOME/Android/sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"
```

Install the exact packages:

```bash
sdkmanager --licenses    # accept all

sdkmanager \
  "platform-tools" \
  "platforms;android-35" \
  "build-tools;35.0.0" \
  "ndk;27.3.13750724" \
  "cmake;3.30.3"
```

Verify:

```bash
ls "$ANDROID_HOME/ndk/27.3.13750724"
ls "$ANDROID_HOME/cmake/3.30.3"
```

If either is missing, the build will fail later with a much less helpful message.

### ccache

The C++ core is large and rebuilds often. ccache turns a 45-minute rebuild into a few minutes.

```bash
ccache --max-size=20G
ccache --set-config=compiler_check=content
ccache --set-config=sloppiness=time_macros
```

The last two match upstream CI (`CCACHE_COMPILERCHECK=content`, `CCACHE_SLOPPINESS=time_macros`) and
materially improve the hit rate for NDK builds.

Gradle picks it up via `NDK_CCACHE`:

```bash
export NDK_CCACHE=$(which ccache)
```

---

## 4. Setup — macOS

```bash
brew install --cask temurin@17
brew install ccache ninja git python

export JAVA_HOME=$(/usr/libexec/java_home -v 17)
```

Then install the Android SDK as above (use the `commandlinetools-mac-*` archive), and the same
`sdkmanager` package list.

---

## 5. Setup — Windows

Android Studio is the pragmatic choice; it manages the SDK, NDK, and CMake.

1. Install **Android Studio** (recent stable).
2. SDK Manager → **SDK Platforms** → Android 15 (API 35).
3. SDK Manager → **SDK Tools** → tick *Show Package Details*, then install NDK `27.3.13750724` and
   CMake `3.30.3`.
4. Install a **JDK 17** (Temurin) and point Gradle at it — Android Studio's bundled JBR may be a
   different major version.
5. Enable long path support:
   ```
   git config --global core.longpaths true
   ```
   and set `LongPathsEnabled=1` in the registry. Azahar's submodule tree has deep paths.

WSL2 with the Linux instructions is frequently the smoother route.

---

## 6. Getting the source

Emul8or currently contains documentation only; Azahar source arrives in roadmap phase 1.

**Clone Emul8or:**

```bash
git clone https://github.com/AjS210/Emul8or.git
cd Emul8or
```

**Add Azahar as upstream:**

```bash
git remote add upstream https://github.com/azahar-emu/azahar.git
git fetch upstream --tags
```

**To build unmodified Azahar first** — which roadmap phase 1 requires before any Emul8or work —
clone it separately:

```bash
git clone --recursive https://github.com/azahar-emu/azahar.git
cd azahar
git checkout 2126.1.2
git submodule update --init --recursive
```

> **Submodules are mandatory.** Azahar has ~35. Omitting `--recursive` produces CMake configure
> errors that do not mention submodules. If a build fails immediately and inexplicably, run
> `git submodule update --init --recursive` before investigating anything else.

---

## 7. Building

```bash
cd src/android
./gradlew assembleVanillaRelWithDebInfo
```

Output:

```
src/android/app/build/outputs/apk/vanilla/relWithDebInfo/
```

### Variants

| Command | Produces |
| --- | --- |
| `./gradlew assembleVanillaDebug` | Debug, debuggable, slowest runtime |
| `./gradlew assembleVanillaRelWithDebInfo` | **Default for development** — optimised and debuggable |
| `./gradlew assembleVanillaRelease` | Release. Uses the debug key unless a keystore is configured |
| `./gradlew tasks` | Everything available |

Use the **Vanilla** flavour. The `googlePlay` flavour exists solely for Play Store storage-policy
compliance and is irrelevant to a sideloaded project.

### Expected timings

| Build | Time |
| --- | --- |
| First, cold | 30–60+ minutes |
| Incremental, Kotlin only | under a minute |
| Incremental, C++ change | a few minutes |
| Clean rebuild with warm ccache | 5–10 minutes |

The first build is genuinely long. It is compiling an entire emulator plus thirty-odd dependencies.

### First build needs network

`preBuild` downloads the Khronos Vulkan validation layers. An offline first build will fail.

---

## 8. Signing

Unsigned development builds use the Android debug key automatically — nothing to configure.

For release signing, upstream reads environment variables:

```bash
export ANDROID_KEYSTORE_FILE=/path/to/keystore.jks
export ANDROID_KEYSTORE_PASS=...
export ANDROID_KEY_ALIAS=...
```

**Never commit a keystore or its password.** Release keys belong in GitHub Actions secrets.

---

## 9. Installing and debugging

```bash
# Install
adb install -r app/build/outputs/apk/vanilla/relWithDebInfo/*.apk

# Two devices attached — target one explicitly
adb devices -l
adb -s <serial> install -r <apk>

# Logs
adb logcat -s Emul8or:V Citra:V
adb logcat -v time | grep -i emul8or
```

Wireless ADB is worth setting up early — testing Wi-Fi streaming while tethered by USB hides
power-management behaviour that only appears on battery. See
[testing-devices.md](testing-devices.md).

Native debugging is available through Android Studio (LLDB) since `relWithDebInfo` sets
`isJniDebuggable = true`.

---

## 10. Common problems

| Symptom | Cause | Fix |
| --- | --- | --- |
| CMake configure fails immediately | Missing submodules | `git submodule update --init --recursive` |
| `Unsupported class file major version` | Wrong JDK | Use JDK 17 exactly |
| `NDK not configured` / version mismatch | Wrong NDK | Install `27.3.13750724` |
| `CMake 'x.y.z' was not found` | Wrong CMake | `sdkmanager "cmake;3.30.3"` |
| First build fails downloading something | No network | Connect; `preBuild` fetches validation layers |
| Out of memory during build | Gradle/Kotlin heap | Raise `org.gradle.jvmargs` in `gradle.properties` |
| Very long paths fail on Windows | Path limit | Enable long paths, or build under WSL2 |
| Rebuilds still slow | ccache not wired in | `export NDK_CCACHE=$(which ccache)`, check `ccache -s` |
| Install fails with `INSTALL_FAILED_OLDER_SDK` | Device below `minSdk` | Expected on the Note 8 until roadmap phase 4 |

---

## 11. Suggested `gradle.properties`

Local overrides — do not commit machine-specific values:

```properties
org.gradle.jvmargs=-Xmx4096m -XX:MaxMetaspaceSize=1024m
org.gradle.parallel=true
org.gradle.caching=true
android.useAndroidX=true
kotlin.incremental=true
```

On 8 GB machines, reduce `-Xmx` and consider disabling parallel builds.

---

## 12. Code style

Emul8or follows upstream conventions so patches can be upstreamed without reformatting churn.

- **C++** — `.clang-format` at `src/.clang-format`. Upstream CI enforces it via `.ci/clang-format.sh`.
- **Kotlin** — ktlint 1.8.0, applied through the `org.jlleitschuh.gradle.ktlint` Gradle plugin.
  ```bash
  ./gradlew ktlintCheck
  ./gradlew ktlintFormat
  ```
- **Licence headers** — upstream CI checks them. New Emul8or files use:
  ```kotlin
  // Copyright 2026 Emul8or Project
  // Licensed under GPLv2 or any later version
  // Refer to the LICENSE file included.
  ```

---

## 13. Verifying the setup

Before starting work, confirm:

```bash
java -version                                  # 17.x
echo $ANDROID_HOME                             # set
ls $ANDROID_HOME/ndk/27.3.13750724             # exists
ls $ANDROID_HOME/cmake/3.30.3                  # exists
adb devices                                    # devices listed
ccache -s                                      # responds
git --version
```

If all of these pass, the toolchain is correct and any subsequent failure is a source or
configuration problem rather than an environment one — which is a much easier thing to debug.
