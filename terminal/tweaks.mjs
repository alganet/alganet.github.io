// tuish-on-wasm adaptation, in one place so the browser page (index.html)
// and the headless drift gate (check.mjs) cannot drift apart.
//
// tuish's compat.sh runs the whole app under `set -euf`, and none of the guest's
// stty calls can work on a wasm "terminal": every one of them fails. The rules
// below append `|| :` so a failure is a no-op instead of an abort, and the empty
// results flow through tuish's own fallbacks (tuish_update_size falls back to
// $LINES/$COLUMNS; fini's stty restore is already guarded by `test -n`). tui.sh's
// follow-up `stty discard undef` carries its own `|| :` upstream and needs
// nothing here.
//
// HOW MUCH THIS STILL BUYS, measured (probe: run boxes.sh in the guest under the
// full transform, under no transform, and with each guard individually removed —
// all four produce byte-identical output and exit 0):
//
//   * stty is NOT missing. This guest's busybox has the applet built in, so the
//     command substitutions return empty and rc=1, not exit 127.
//   * `set -e` is already suspended across init: tuish_init calls
//     _tuish_device_init in `_tuish_device_init || return 1`, which covers the
//     entire dynamic extent of _tuish_init_term — the failing stty calls in there
//     cannot abort anything today.
//
// So the transform is currently INERT. It is kept as cheap insurance for a guest
// whose busybox is built without the stty applet (exit 127, a different failure)
// and for tuish calling stty outside that suspension — not because the page needs
// it now. Do not read a green gate as proof a rule fired.
//
// Which is why each rule is ASSERTED. A transform keyed on source text is only as
// good as its match, and a silent miss is this file's worst failure mode: it looks
// exactly like a transform that worked. tuish dropping `discard undef` from the
// raw-mode line (busybox stty has no such control char, and it validates the whole
// argument list before applying any of it) killed the old regex outright and
// nothing noticed. Match on the parts that carry meaning; throw when one stops
// matching.
//
// Everything else in tuish runs unmodified on the fork-free wasm: the
// capability/timing probes (heredocs and builtin pipes work), ord.sh's 256-entry
// $(printf) char table, the examples' $(dirname "$0") locator (fails harmlessly
// BEFORE set -e is on; sourcing resolves via /../src → /src with the tree mounted
// at root).

const RULES = [
  ['_tuish_previous_stty="$(stty -g)"', '_tuish_previous_stty="$(stty -g 2>/dev/null || :)"'],
  ['_tuish_stty="$(stty -g)"', '_tuish_stty="$(stty -g 2>/dev/null || :)"'],
  ['_ts="$(stty size 2>/dev/null)"', '_ts="$(stty size 2>/dev/null || :)"'],
  // The tail of the multi-line raw-mode `stty`. Anchored on `intr undef` … the
  // redirect rather than the full control-char list, which tuish revises.
  [/^(\t*intr undef .*time 0 2>\/dev\/null)$/m, '$1 || :'],
];

export function transform(path, text) {
  if (!path.endsWith('/tui.sh')) return text;
  return RULES.reduce((acc, [from, to]) => {
    const out = acc.replace(from, to);
    if (out === acc) {
      throw new Error(
        `tweaks.mjs: no match for ${from} in tui.sh — the wasm stty guard would be ` +
        `silently dropped. Update the rule to the new source text.`);
    }
    return out;
  }, text);
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
