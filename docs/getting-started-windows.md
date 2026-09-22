# Getting Started on Windows — Step by Step

A beginner's guide to Phase 1: **building the Azahar emulator from source and putting it on your
phone.**

No prior experience assumed. If you have never opened a command prompt, you can still do this.

---

## First, the honest expectations

**What you are doing in this guide:** taking the Azahar emulator's source code (the human-readable
instructions that programmers write) and turning it into an app you can install on your Galaxy S24
Ultra.

**What you are NOT doing yet:** building Emul8or. None of the two-phone streaming exists yet. This
guide gets you the starting point that everything else is built on.

**Why bother, if you could just download Azahar?** Because you are about to modify it. If you can't
build the unmodified version first, then later — when something breaks — you won't know whether you
broke it or whether it never worked on your machine. This step gives you a known-good starting point.

### What it costs you

| | |
| --- | --- |
| **Time, first attempt** | An afternoon. Maybe 2–4 hours, and most of that is waiting |
| **Disk space** | 60 GB free. Not negotiable — the build is genuinely huge |
| **Downloads** | Around 15–20 GB total |
| **Difficulty** | Low, but long. Mostly copy, paste, wait |

**The single longest step is one command that runs for 30–60 minutes while you do something else.**
That is normal. It is not frozen.

---

## Some words you'll see

You don't need to memorise these, but they'll stop things feeling like nonsense.

- **Source code** — the text a programmer writes. Not runnable by itself.
- **Compiling / building** — turning source code into a real, runnable app. Like baking a cake from
  a recipe.
- **APK** — the finished Android app file. The cake.
- **Repository (repo)** — a project's folder of source code, with its full history.
- **Git** — the tool that downloads and tracks repositories.
- **Clone** — downloading a repository to your computer.
- **Command Prompt / Terminal** — a window where you type commands instead of clicking.
- **SDK / NDK** — toolkits from Google for building Android apps. The NDK is for code written in C++,
  which an emulator needs because it has to be fast.
- **Submodule** — a repository inside another repository. Azahar uses ~35 of them. **These cause most
  beginner failures**, so I'll flag them clearly.

---

## Before you start

Check these, or you'll hit a wall later:

- [ ] **60 GB free disk space.** Press `Windows + E`, click "This PC", look at your C: drive.
- [ ] **A reliable internet connection.** You're downloading ~20 GB.
- [ ] **Your Galaxy S24 Ultra and its USB cable.**
- [ ] **Two to four hours**, most of it unattended.
- [ ] **Your own legally-dumped 3DS game**, if you want to test that games actually run. Emul8or
      provides none, and never will. See [legal.md](legal.md).

---

# Part 1 — Install the tools

Four things to install. Do them in order.

## Step 1.1 — Install Git

Git is the tool that downloads the source code.

1. Go to **https://git-scm.com/download/win**
2. The download should start automatically. If not, click "64-bit Git for Windows Setup".
3. Run the downloaded file.
4. Click **Next** through every screen. **The defaults are fine.** Don't overthink it.
5. Click **Install**, then **Finish**.

## Step 1.2 — Turn on "long paths"

**Don't skip this.** Windows has an old limit on how long a file's full name-and-location can be.
Azahar's folders are deeply nested and will exceed it, producing confusing errors much later.

1. Press the **Windows key**, type `cmd`
2. **Right-click** "Command Prompt" → **Run as administrator**
3. Click **Yes** when Windows asks permission
4. Copy this line, paste it into the black window (right-click pastes), press **Enter**:

```
git config --system core.longpaths true
```

5. Now paste this one and press **Enter**:

```
reg add "HKLM\SYSTEM\CurrentControlSet\Control\FileSystem" /v LongPathsEnabled /t REG_DWORD /d 1 /f
```

It should say `The operation completed successfully.` Close the window.

## Step 1.3 — Install Java 17

The build tools are written in Java. **It must be version 17.** Not 21, not 24. Newer versions
break the build — this is the most common setup mistake.

1. Go to **https://adoptium.net/temurin/releases/?version=17**
2. Set **Operating System** to `Windows`, **Architecture** to `x64`, **Package Type** to `JDK`
3. Download the **`.msi`** file
4. Run it. Click Next through the screens.
5. **Important:** on the "Custom Setup" screen, find **"Set JAVA_HOME variable"**. It may have a red
   X meaning "won't install". Click it and choose **"Will be installed on local hard drive."**
6. Finish the install.

**Check it worked:** press Windows key, type `cmd`, press Enter, then type:

```
java -version
```

You want to see something containing **`17`**. If it says "not recognized", restart your PC and try
again.

## Step 1.4 — Install Android Studio

This is the big one (~1 GB download). It gives you the Android toolkits.

1. Go to **https://developer.android.com/studio**
2. Click the big download button, accept the terms
3. Run the installer, click **Next** through everything, then **Install**
4. Launch Android Studio when it finishes
5. A setup wizard appears. Choose **Standard**, click through, accept licences, and let it download.
   This takes a while.
6. Eventually you reach a "Welcome to Android Studio" window. Leave it open.

### Now add the specific pieces Azahar needs

Android Studio installed the general tools. Azahar needs three **exact versions**.

1. In the Welcome window, click **More Actions** (or the ⚙ gear) → **SDK Manager**
2. Click the **SDK Platforms** tab
   - Tick **Android 15.0 ("VanillaIceCream")** — API level 35
3. Click the **SDK Tools** tab
   - **Tick the "Show Package Details" checkbox** at the bottom right. This is essential — without
     it you can't pick versions.
   - Find **NDK (Side by side)**, expand it, tick **`27.3.13750724`**
   - Find **CMake**, expand it, tick **`3.30.3`**
   - Make sure **Android SDK Build-Tools** and **Android SDK Platform-Tools** are ticked
4. Click **OK** / **Apply**, accept licences, wait for the download (several GB)

> **Why exact versions?** The emulator's C++ code is built with these specific tools. A different
> NDK version can fail in ways whose error messages don't tell you the version is the problem.

---

# Part 2 — Download the source code

## Step 2.1 — Open a Command Prompt

Press the **Windows key**, type `cmd`, press **Enter**. A black window appears. This is where you'll
work.

> **Tip:** in Command Prompt, **right-click pastes**. `Ctrl+V` may not work.

## Step 2.2 — Make a folder and go into it

Type each line, pressing Enter after each:

```
cd C:\
```

```
mkdir dev
```

```
cd dev
```

You've made `C:\dev` and moved into it. (If `mkdir dev` says it already exists, that's fine.)

## Step 2.3 — Download Azahar

**This is the step people get wrong.** The `--recursive` part is what also fetches those ~35
submodules. Leave it out and the build fails later with errors that never mention submodules.

Paste this and press Enter:

```
git clone --recursive https://github.com/azahar-emu/azahar.git azahar-baseline
```

This downloads several GB. **Expect 10–30 minutes.** Text will scroll constantly — that's good.

When it finishes, go into the folder:

```
cd azahar-baseline
```

## Step 2.4 — Switch to the tested version

The code changes daily. You want a stable, tested release rather than whatever was uploaded this
morning.

```
git checkout 2126.1.2
```

You may see a paragraph about "detached HEAD". **That's normal.** It just means you're looking at a
specific version.

```
git submodule update --init --recursive
```

This makes sure every submodule is present. It may take another few minutes. **Run it even if you
used `--recursive` earlier** — it costs nothing and prevents the most common failure.

---

# Part 3 — Build the app

## Step 3.1 — Go to the Android folder

```
cd src\android
```

## Step 3.2 — Start the build

This is the long one.

```
gradlew.bat assembleVanillaRelWithDebInfo
```

Press Enter, and **leave it alone.**

### What to expect

- Text scrolls for a long time
- It will sometimes pause on one line for several minutes
- **This is normal.** It is not frozen
- **30 to 60+ minutes**, possibly longer on a slower PC
- Your PC's fans will get loud. Also normal
- You need internet during this — it downloads extra pieces as it goes

Go and do something else. Seriously.

### How you know it worked

Near the end you'll see:

```
BUILD SUCCESSFUL in 42m 13s
```

If instead you see **`BUILD FAILED`**, jump to [Part 5 — When things go wrong](#part-5--when-things-go-wrong).

## Step 3.3 — Find your app

The APK is at roughly:

```
C:\dev\azahar-baseline\src\android\app\build\outputs\apk\vanilla\relWithDebInfo\
```

Open that folder in File Explorer. There's a file ending in **`.apk`**. **You just built that.**

---

# Part 4 — Put it on your phone

## Step 4.1 — Unlock Developer Mode on the S24 Ultra

Phones don't normally accept apps over USB. You have to ask.

1. **Settings** → **About phone**
2. Tap **Software information**
3. Find **Build number** and **tap it seven times**
4. It counts down ("You are 3 steps away..."), then says **"Developer mode has been enabled"**
5. Enter your PIN if asked

## Step 4.2 — Turn on USB Debugging

1. **Settings** → **Developer options** (near the bottom now)
2. Turn on **USB debugging**
3. Confirm the warning

## Step 4.3 — Plug in and authorise

1. Connect the phone to your PC by USB
2. **On the phone**, a popup asks **"Allow USB debugging?"** — tick **"Always allow"**, tap **Allow**
3. If no popup appears, unplug and replug

> Use a **data** cable. Some charge-only cables carry no data and will silently do nothing.

## Step 4.4 — Check the PC sees the phone

Back in Command Prompt:

```
adb devices
```

You want:

```
List of devices attached
R5CT12345AB     device
```

- **If it says `unauthorized`** → check the phone for the popup and tap Allow
- **If the list is empty** → try another cable or USB port
- **If `adb` isn't recognized** → see Part 5

## Step 4.5 — Install it

From the `src\android` folder:

```
adb install -r app\build\outputs\apk\vanilla\relWithDebInfo\app-vanilla-relWithDebInfo.apk
```

> If the filename is different, look in the folder and use the exact name you see.

You want:

```
Success
```

**That's it.** Azahar is on your phone — a version *you* built.

## Step 4.6 — Test it

Open the app on your phone and check:

- [ ] It opens without crashing
- [ ] You can get through the setup screens
- [ ] It asks for file permissions and accepts them
- [ ] The game list screen appears
- [ ] **If you have your own legally-dumped game:** it loads and runs
- [ ] Sound works
- [ ] Touch controls work
- [ ] On-screen buttons sit *on top of* the game picture, not in a separate strip below it

**If the game runs — Phase 1 is done.** That is the foundation the whole project stands on.

---

# Part 5 — When things go wrong

Normal. Everyone hits at least one of these.

### "BUILD FAILED" mentioning CMake or a missing file

**Almost always missing submodules.** Go back to `C:\dev\azahar-baseline` and run:

```
git submodule update --init --recursive
```

Then build again. This fixes the majority of first-time failures.

### "Unsupported class file major version"

Wrong Java version. Run `java -version`. If it isn't 17, uninstall other Java versions or revisit
Step 1.3.

### "NDK not configured" / "NDK version not found"

The exact NDK isn't installed. Return to SDK Manager, tick **Show Package Details**, install NDK
**`27.3.13750724`**.

### "CMake '3.x.x' was not found"

Same place — install CMake **`3.30.3`** in SDK Tools.

### "'adb' is not recognized"

Windows doesn't know where `adb` lives. Either use the full path:

```
C:\Users\YOUR_NAME\AppData\Local\Android\Sdk\platform-tools\adb.exe devices
```

(replacing `YOUR_NAME`), or add that `platform-tools` folder to your PATH.

### Errors about paths being too long

You skipped Step 1.2. Go back and do it, then delete `C:\dev\azahar-baseline` and re-clone.

### "Out of memory" during the build

Close Chrome and everything else, then try again. The build is memory-hungry.

### It seems frozen

Wait longer. Some steps take 10+ minutes on one line. Only worry if there's no disk or CPU activity
for 20+ minutes (check Task Manager).

### Something else

Copy the **last 30 lines** of the error text and bring them to me. The final error is usually the
real one; everything above it is noise.

---

# What happens after this

Once unmodified Azahar builds and runs, you have a working foundation. Then:

**Phase 2** — rebrand it as Emul8or (name, icon, app ID). No behaviour changes.
**Phase 3** — add the "Primary or Secondary?" choice at launch, and the local screen layouts.
**Phase 4** — make Secondary mode work on Android 9, for the Note 8.
**Phase 5** — get the two phones talking over Wi-Fi.
**Phase 6** — actually stream the top screen. **The real goal.**

Full plan in [ROADMAP.md](../ROADMAP.md).

### One bonus test, if you can

If you have a **USB-C-to-HDMI adapter** and a monitor or TV, try this while you're still on
unmodified Azahar:

1. Connect the S24 Ultra to the screen
2. In Azahar's settings, find the **secondary display** option and enable it
3. Set the secondary layout to show the **top screen**

If the 3DS top screen appears on the TV while the bottom screen stays on the phone — **that is
Emul8or's entire core feature already working**, just over a cable instead of Wi-Fi. Emul8or's plan
is to feed that same mechanism a network connection instead of an HDMI port.

Confirming this works on your actual phone, before we write any code, removes the single biggest
risk in the project. See [architecture.md](architecture.md) §4.
