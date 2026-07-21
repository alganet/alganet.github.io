#!/usr/bin/env sh

# vendor.sh — snapshot the tuish toolkit + the wasi-sh runtime into terminal/.
#
# The terminal/ shell version runs a pure-shell TUI (terminal/index.sh) on
# busybox-ash-compiled-to-wasm (wasi-sh), painting to xterm.js in the browser.
# This script vendors the ENGINE those pieces need — it does NOT touch content:
# the *.tui files that feed the reader are generated ALONGSIDE the HTML by
# build.sh on every run. Run this only when tuish or wasi-sh themselves change.
#
# Expects the sibling projects checked out next to this repo:
#   ../tuish     — the TUI toolkit (src/*.sh) + its web POC (web/tweaks.mjs, …)
#   ../wasi-sh   — busybox-on-wasm runtime (src/*.mjs, dist/busybox.wasm)
#
# Usage:  sh vendor.sh    (from the repo root)

set -eu

TUISH=../tuish
WASISH=../wasi-sh
WEB="$TUISH/web"
DEST=terminal

# The tuish modules the reader sources — in dependency order. clip.sh provides
# OSC-52 copy for the "copy code snippet" feature. host.sh (app-in-app hosting) is
# excluded: the blog reader embeds no live apps.
MODULES="compat ord tui term canvas event hid viewport str draw keybind buf clip"

rm -rf "$DEST/tuish" "$DEST/vendor"
mkdir -p "$DEST/tuish/src" "$DEST/vendor/wasi-sh/src" "$DEST/vendor/wasi-sh/dist"

# 1. tuish sources (only the modules the reader needs).
for m in $MODULES; do
    cp "$TUISH/src/$m.sh" "$DEST/tuish/src/$m.sh"
done

# 2. wasi-sh runtime: the JS shim + the wasm blob.
cp "$WASISH"/src/*.mjs "$DEST/vendor/wasi-sh/src/"
cp "$WASISH"/dist/busybox.wasm "$DEST/vendor/wasi-sh/dist/"

# 3. The wasm adaptation (the four stty `|| :` guards), verbatim from the tuish web
#    POC so it cannot drift. (coi-serviceworker.js is NOT copied: our copy is
#    patched for Firefox — see its header — and maintained in-tree.)
cp "$WEB/tweaks.mjs" "$DEST/tweaks.mjs"

# 3b. xterm.js + addons + css, vendored LOCALLY (not loaded from a CDN at run
#     time). This is load-bearing: on GitHub Pages the coi-serviceworker adds the
#     COOP/COEP headers, but it can't re-serve CROSS-ORIGIN modules — Firefox then
#     blocks the CDN xterm import and the terminal never boots. Same-origin files
#     have no such problem. The jsDelivr `+esm` builds are self-contained ESM; we
#     strip their sourceMappingURL so devtools never reaches for a CDN map.
XT="$DEST/vendor/xterm"
mkdir -p "$XT"
_xget() { curl -sfL --max-time 30 "$1" | sed '/^\/\/# sourceMappingURL/d' > "$2"; }
_xget 'https://cdn.jsdelivr.net/npm/@xterm/xterm@6.0.0/+esm'            "$XT/xterm.mjs"
_xget 'https://cdn.jsdelivr.net/npm/@xterm/addon-fit@0.11.0/+esm'       "$XT/addon-fit.mjs"
_xget 'https://cdn.jsdelivr.net/npm/@xterm/addon-web-links@0.11.0/+esm' "$XT/addon-web-links.mjs"
_xget 'https://cdn.jsdelivr.net/npm/@xterm/addon-webgl@0.19.0/+esm'     "$XT/addon-webgl.mjs"
_xget 'https://cdn.jsdelivr.net/npm/@xterm/addon-canvas@0.7.0/+esm'     "$XT/addon-canvas.mjs"
curl -sfL --max-time 30 'https://cdn.jsdelivr.net/npm/@xterm/xterm@6.0.0/css/xterm.min.css' > "$XT/xterm.css"

# 4. manifest.json — the src file list the boot loader fetchTree's and mounts
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

echo "vendored: $(echo $MODULES | wc -w) tuish modules + wasi-sh runtime → $DEST/"
