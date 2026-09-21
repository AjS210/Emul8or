#!/usr/bin/env bash
#
# Copyright 2026 Emul8or Project
# Licensed under GPLv2 or any later version
# Refer to the LICENSE file included.
#
# Configures the Azahar upstream remote and fetches the pinned baseline tag.
#
# Git remotes live in .git/config, which is local to a clone and never
# committed. This script keeps the baseline pin under version control instead
# of leaving it as folklore in someone's shell history.
#
# Usage:  ./scripts/setup-upstream.sh
#
# See docs/upstream-integration.md

set -euo pipefail

UPSTREAM_URL="https://github.com/azahar-emu/azahar.git"
UPSTREAM_REMOTE="upstream"

# Pinned baseline. Azahar commits daily, so we track tested release tags
# rather than master. Bump deliberately -- see docs/upstream-integration.md.
BASELINE_TAG="2126.1.2"
LOCAL_TAG="azahar-${BASELINE_TAG}"
EXPECTED_COMMIT="9e6f523a57fac9564ac0bf8286db3c3702d301ec"

say()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }

git rev-parse --git-dir >/dev/null 2>&1 || die "Not inside a git repository."

# --- remote ------------------------------------------------------------------

if git remote get-url "$UPSTREAM_REMOTE" >/dev/null 2>&1; then
    current="$(git remote get-url "$UPSTREAM_REMOTE")"
    if [ "$current" = "$UPSTREAM_URL" ]; then
        say "Remote '$UPSTREAM_REMOTE' already points at Azahar."
    else
        warn "Remote '$UPSTREAM_REMOTE' points at: $current"
        warn "Expected: $UPSTREAM_URL"
        die  "Refusing to overwrite. Fix it manually with 'git remote set-url'."
    fi
else
    say "Adding remote '$UPSTREAM_REMOTE' -> $UPSTREAM_URL"
    git remote add "$UPSTREAM_REMOTE" "$UPSTREAM_URL"
fi

# --- baseline tag ------------------------------------------------------------

if git rev-parse -q --verify "refs/tags/${LOCAL_TAG}" >/dev/null; then
    say "Baseline tag '$LOCAL_TAG' already present."
else
    say "Fetching baseline tag '$BASELINE_TAG' (shallow) ..."
    git fetch --no-tags --depth=1 "$UPSTREAM_REMOTE" \
        "refs/tags/${BASELINE_TAG}:refs/tags/${LOCAL_TAG}"
fi

actual="$(git rev-parse "refs/tags/${LOCAL_TAG}^{commit}")"
if [ "$actual" != "$EXPECTED_COMMIT" ]; then
    warn "Baseline commit mismatch."
    warn "  expected: $EXPECTED_COMMIT"
    warn "  actual:   $actual"
    warn "Upstream may have re-tagged. Verify before relying on this baseline."
else
    say "Baseline verified: ${BASELINE_TAG} @ ${actual:0:12}"
fi

# --- sanity check the pinned build config ------------------------------------

say "Build config at the pinned tag:"
if git cat-file -e "${LOCAL_TAG}:src/android/app/build.gradle.kts" 2>/dev/null; then
    git show "${LOCAL_TAG}:src/android/app/build.gradle.kts" \
        | grep -E '^\s*(compileSdkVersion|ndkVersion|applicationId|minSdk|targetSdk)\s*=' \
        | sed 's/^/    /'
else
    warn "Could not read build.gradle.kts from the tag (shallow fetch may omit blobs)."
fi

cat <<EOF

$(say "Done.")

Inspect upstream without importing it:

    git show ${LOCAL_TAG}:src/android/app/build.gradle.kts
    git ls-tree ${LOCAL_TAG} src/android/

Next: build UNMODIFIED Azahar and run it on the S24 Ultra before making any
Emul8or changes. Checklist in docs/upstream-integration.md, section 5.
EOF
