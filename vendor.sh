#!/usr/bin/env sh

# vendor.sh — snapshot the tuish toolkit into terminal/.
#
# The terminal/ shell version runs a pure-shell TUI (terminal/index.sh) on
# busybox-ash-compiled-to-wasm (wasi-sh), painting to xterm.js in the browser.
# This script vendors the ENGINE those pieces need — it does NOT touch content:
# the *.tui files that feed the reader are generated ALONGSIDE the HTML by
# build.sh on every run. Run this only when tuish itself changes.
#
# wasi-sh and xterm.js used to be vendored here too — wasi-sh copied out of a
# sibling checkout, xterm curl'd from jsDelivr. They come from npm now
# (package.json) and are bundled into terminal/dist/ by
# tools/build-terminal.mjs, so Dependabot can see and update them. tuish stays
# here: the name `tuish` on npm belongs to an unrelated project.
#
# Expects the sibling project checked out next to this repo:
#   ../tuish     — the TUI toolkit (src/*.sh) + its web POC (web/tweaks.mjs, …)
#
# Usage:  sh vendor.sh    (from the repo root)

set -eu

TUISH=../tuish
WEB="$TUISH/web"
DEST=terminal

# The tuish modules the reader sources — in dependency order. clip.sh provides
# OSC-52 copy for the "copy code snippet" feature. host.sh (app-in-app hosting) is
# excluded: the blog reader embeds no live apps.
# hl.sh must precede md.sh: md.sh uses it when present and degrades without it.
# Both are also sourced by build.sh, straight out of this vendored copy — so the
# HTML and the terminal are rendered by the same parser bytes, not merely the same
# parser in principle.
MODULES="compat ord tui term canvas event hid viewport str draw keybind buf clip hl md"

rm -rf "$DEST/tuish"
mkdir -p "$DEST/tuish/src"

# 1. tuish sources (only the modules the reader needs).
for m in $MODULES; do
    cp "$TUISH/src/$m.sh" "$DEST/tuish/src/$m.sh"
done

# 2. The wasm adaptation (the four stty `|| :` guards), verbatim from the tuish web
#    POC so it cannot drift. (coi-serviceworker.js is NOT copied: our copy is
#    patched for Firefox — see its header — and maintained in-tree.)
cp "$WEB/tweaks.mjs" "$DEST/tweaks.mjs"

# 3. manifest.json — the src file list the boot loader fetchTree's and mounts
#    at /src. (The .tui content list is a SEPARATE file, terminal/content.json,
#    written by build.sh, so the two generators never fight over one manifest.)
{
    printf '{\n  "src": ['
    _sep=''
    for m in $MODULES; do
        printf '%s"%s.sh"' "$_sep" "$m"
        _sep=', '
    done
    printf ']\n}\n'
} > "$DEST/manifest.json"

echo "vendored: $(echo $MODULES | wc -w) tuish modules → $DEST/"
