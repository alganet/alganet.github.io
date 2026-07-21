// tuish-on-wasm adaptation, in one place so the browser page (index.html)
// and the headless drift gate (check.mjs) cannot drift apart.
//
// The wasm guest is busybox ash with NO external programs — `stty` does not
// exist. tuish's compat.sh runs under `set -euf`, so the three bare stty
// command substitutions in tui.sh would abort init with exit 127 the moment
// they fail. Guarding them with `|| :` inside the substitution keeps init
// alive; the empty results then flow through tuish's own fallbacks
// (tuish_update_size falls back to $LINES/$COLUMNS; fini's stty restore is
// already guarded by `test -n`).
//
// That's the ENTIRE transform. Everything else in tuish runs unmodified on
// the fork-free wasm: the capability/timing probes (heredocs and builtin
// pipes work), ord.sh's 256-entry $(printf) char table, the examples'
// $(dirname "$0") locator (fails harmlessly BEFORE set -e is on; sourcing
// resolves via /../src → /src with the tree mounted at root).
//
// Upstream candidate: these same guards would let tuish survive any
// stty-less environment — worth proposing on tuish itself, which would make
// this file's transform empty.

export function transform(path, text) {
  if (!path.endsWith('/tui.sh')) return text;
  return text
    .replace('_tuish_previous_stty="$(stty -g)"', '_tuish_previous_stty="$(stty -g 2>/dev/null || :)"')
    .replace('_tuish_stty="$(stty -g)"', '_tuish_stty="$(stty -g 2>/dev/null || :)"')
    .replace('_ts="$(stty size 2>/dev/null)"', '_ts="$(stty size 2>/dev/null || :)"')
    .replace(/(\t\tintr undef quit undef werase undef discard undef time 0 2>\/dev\/null)$/m, '$1 || :');
}

// Environment for a tuish example: geometry (tuish falls back to
// $LINES/$COLUMNS when stty can't answer) plus the byte-oriented locale
// tuish sets for itself anyway.
export function tuishEnv(cols, rows) {
  return {
    COLUMNS: String(cols),
    LINES: String(rows),
    LC_ALL: 'C',
    TERM: 'xterm-256color',
  };
}

export const onlySh = (rel) => rel.endsWith('.sh');
