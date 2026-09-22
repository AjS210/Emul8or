# Legal and Licensing

> Not legal advice. This document records the project's rules and the reasoning behind them.
> Contributors are responsible for their own compliance.

---

## 1. The short version

**Emul8or contains no copyrighted Nintendo content, and never will.**

No ROMs. No games. No BIOS. No firmware dumps. No encryption keys. No system archives. No Nintendo
artwork, logos, fonts, sounds, or trademarks. Not in the repository, not in a release, not in a
build script that downloads them, not in a link that helps you find them.

Users supply their own files, dumped from hardware they own.

---

## 2. Software licence

Emul8or is licensed **GPL-2.0-or-later**.

This is not a choice so much as an inheritance. Emul8or derives from
[Azahar](https://github.com/azahar-emu/azahar), which is GPL-2.0-or-later, itself descended from
Citra. A derivative work of GPL-2.0-or-later code must be distributed under the same terms.

The full licence text is in [`LICENSE`](../LICENSE) at the repository root.

### What this obliges us to do

- **Ship the source.** Every distributed binary must be accompanied by, or offer, the complete
  corresponding source. In practice: public GitHub repository, and releases tagged to the commit
  they were built from.
- **Preserve copyright notices.** Upstream file headers stay intact. Do not strip or rewrite the
  Citra/Azahar attribution lines. Add to them where a file is substantially modified.
- **Keep modifications under the GPL.** Emul8or's own code — networking, streaming, role selection —
  is GPL-2.0-or-later too, because it is part of a derivative work.
- **No additional restrictions.** We cannot bolt on terms that restrict the freedoms the GPL grants.
- **State changes.** Modified files should carry a note that they were changed and when.

### Third-party dependencies

Azahar vendors roughly thirty-five submodules — Boost, dynarmic, fmt, cryptopp, SDL, cubeb,
glslang, libusb, and others, under a mix of GPL-2+, MIT, BSD, Zlib, and Boost licences. All are
GPL-2-compatible. Any **new** dependency Emul8or adds must be GPL-2-compatible as well.

**Incompatible licences to reject outright:** Apache-2.0 (patent clause conflicts with GPL-2.0-only
recipients), GPL-3-only, and anything proprietary or source-available-but-not-free.

Emul8or's own additions should prefer dependencies already present in the Android platform —
`MediaCodec`, `NsdManager`, `WifiP2pManager` — over new third-party libraries. Fewer dependencies,
fewer licence questions.

---

## 3. Prohibited content

The following must never appear in this repository, in a release artifact, or in any build process:

| Category | Examples |
| --- | --- |
| Game content | `.3ds`, `.cci`, `.cia`, `.cxi`, `.app`, `.romfs` files; save data from commercial titles |
| System software | 3DS firmware, NAND dumps, `boot9.bin`, `boot11.bin`, system archives, shared fonts |
| Cryptographic material | AES key slots, `aes_keys.txt`, `seeddb.bin`, ticket keys, common keys |
| Nintendo IP | Console renders, box art, character art, logos, wordmarks, official fonts, UI assets, sounds |
| Circumvention tooling | Dumpers, exploit chains, or instructions for defeating console copy protection |

**Also prohibited: links or instructions pointing to any of the above.** The distinction between
writing an emulator and helping people circumvent protection is precisely where the Yuzu litigation
landed, and it is not a line worth testing.

### What users must provide themselves

Emul8or will document *that* these are required, and will not document *how to obtain them*:

- Their own legally-dumped game files.
- Their own system files and keys, dumped from a 3DS they own.

A clear in-app message should explain that Emul8or ships none of this.

---

## 4. Trademarks and branding

**Nintendo.** "Nintendo", "Nintendo 3DS", "New Nintendo 3DS", and associated logos are trademarks of
Nintendo. Emul8or is not affiliated with, endorsed by, sponsored by, or connected to Nintendo in any
way. References to "Nintendo 3DS" in documentation are nominative — describing what the software is
compatible with — and must stay descriptive rather than suggesting endorsement.

Do not use Nintendo's marks in the app icon, launcher name, screenshots, or promotional material.
Do not stylise "Emul8or" to resemble a Nintendo wordmark.

**Azahar and Citra.** The Azahar logo is the property of PabloMK7 and angyartanddraw. It is **not**
covered by Azahar's GPL grant and must not be reused. Emul8or uses its own independent icon,
wordmark, and colour palette. We credit Azahar and Citra in text and in the in-app licence screen —
and use none of their artwork.

**Emul8or branding** must be original work, created for this project or sourced under a permissive
licence with attribution recorded in the repository.

---

## 5. Attribution requirements

Every release must include an accessible "Open Source Licenses" screen containing:

1. Emul8or's own copyright and the GPL-2.0-or-later grant.
2. A statement that Emul8or is derived from Azahar, with a link to
   `https://github.com/azahar-emu/azahar`.
3. Azahar's derivation from Citra, with attribution to the Citra Emulator Project.
4. The full GPL-2.0 text.
5. Licences for all bundled third-party components.
6. A link to Emul8or's own source.

Source files adapted from upstream keep their original headers. Emul8or's new files carry:

```
// Copyright 2026 Emul8or Project
// Licensed under GPLv2 or any later version
// Refer to the LICENSE file included.
```

This matches upstream's header convention, which keeps Azahar's `license-header` CI check happy and
makes upstreaming a patch less work.

---

## 6. Is this legal to write?

Writing and distributing an emulator is well-established as lawful in the United States. *Sony
Computer Entertainment, Inc. v. Connectix Corp.* (9th Cir. 2000) held that reverse-engineering a
console's firmware to produce an independently-written, interoperable emulator is fair use — even
though intermediate copying occurs, and even though the result competes commercially with the
console.

What is **not** protected, and where the Citra/Yuzu shutdown actually landed, is distributing
copyrighted game files, or distributing tools and instructions whose purpose is circumventing
technological protection measures (DMCA §1201).

Emul8or's position is therefore straightforward: be an emulator, and nothing else. No content, no
keys, no circumvention guidance, no "here is where to get your ROMs" wink. The project's legal
safety comes from that discipline, not from a clever argument.

Users are responsible for their own compliance in their own jurisdiction. Laws on personal backups
and format shifting vary considerably.

---

## 7. Rules for contributors

By contributing you confirm:

1. You wrote the contribution, or have the right to submit it under GPL-2.0-or-later.
2. It contains no code copied from incompatibly-licensed sources — including decompiled or
   disassembled Nintendo code.
3. It includes no prohibited content of any kind.
4. You have not used Nintendo's leaked or proprietary source material as a reference.

### AI-assisted contributions

**Emul8or's policy: AI assistance is permitted anywhere in this repository, provided it is disclosed
and a human has reviewed it.**

Requirements:

- **Disclose it** in the pull request description. Say what was AI-assisted and to what extent.
- **A human reviews and owns it.** The contributor is accountable for correctness, licensing, and
  behaviour. "The model wrote it" is not a defence for a bug or a licence violation.
- **The rules in §7 above still apply in full.** No incompatibly-licensed code, no decompiled or
  leaked Nintendo material, no prohibited content. An AI-generated contribution that launders
  copyrighted code is exactly as unacceptable as a hand-copied one — and harder to spot, so
  reviewers should be correspondingly sceptical of large unexplained contributions.
- **No autonomously-filed PRs or issues.** A human opens it, and a human answers questions about it.

#### Why this differs from Azahar's policy

Upstream Azahar maintains a strict [AI use
policy](https://github.com/azahar-emu/azahar/blob/master/AI-POLICY.md), which permits AI only for
diagnosis and for very small disclosed snippets, and prohibits AI-written contributions of
substantial size.

**That policy is a contribution rule for their repository. It is not a licence term, and it does not
restrict Emul8or.** GPL-2.0 §6 is explicit:

> You may not impose any further restrictions on the recipients' exercise of the rights granted
> herein.

Azahar cannot attach conditions to the GPL grant beyond the GPL itself. Emul8or's rights to use,
modify, fork, build, and publicly distribute Azahar's code are unconditional, subject only to the
ordinary GPL obligations in §2 of this document: stay GPL-2.0-or-later, ship the corresponding
source, preserve copyright notices, state changes.

#### The tradeoff we are accepting

Adopting a policy looser than Azahar's means **Emul8or cannot expect to upstream patches to Azahar.**

This costs less than it sounds. Emul8or's anticipated patch surface against upstream is roughly four
files — `minSdk`, the manifest, the launcher entry point, and the secondary-surface hook (see
[upstream-integration.md](upstream-integration.md) §6). Everything that makes Emul8or distinctive —
the networking layer, the H.264 streaming pipeline, role selection, the connection state machine —
is new code in Emul8or's own tree. Azahar would not merge that regardless of how it was written,
because two-phone Wi-Fi streaming is a different product, not a missing Azahar feature.

Should a genuinely general-purpose, upstreamable fix emerge — for example, making the secondary
surface API accept an arbitrary `Surface` — it can be written by hand specifically for submission,
and disclosed under Azahar's rules. That decision is made per patch, not as a standing constraint on
the whole project.

#### A note on perception

Emulation communities care about provenance, and a fork built on another project's work invites
scrutiny. That is a reasonable thing for them to care about. The mitigations are transparency about
how the code was produced, a human who genuinely understands and can defend the emulator-internals
changes, and not asking upstream maintainers to debug code nobody on our side understands.

This is a reputational consideration, not a legal one, and it is managed by conduct rather than by
policy.

**Disclosure for the current repository state:** the initial documentation set — `README.md`,
`ROADMAP.md`, and the files in `docs/` — was AI-drafted from research against the upstream Azahar
repository, and is under human review.

---

## 8. Distribution policy

- Sideloaded APKs via GitHub Releases, signed, with published checksums.
- Each release tagged to the exact commit it was built from, so source and binary correspond.
- Reproducible builds where practical.
- No bundled content, ever — including in "convenience" or "complete" packages.
- Google Play only after careful evaluation. Play's storage-access policy is what forced Azahar into
  separate Vanilla and Google Play flavours; that complexity is not worth taking on early.

---

## 9. Takedowns and contact

If you believe Emul8or infringes your rights, open an issue or contact the maintainer through
GitHub. The project will engage in good faith and remove genuinely infringing material.

The project will not, however, remove the emulator itself on the basis that emulation is
objectionable. Emulation is lawful, and preservation of the 3DS platform is a legitimate purpose.
