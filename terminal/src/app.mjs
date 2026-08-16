// The terminal page's module. Bundled by tools/build-terminal.mjs into
// terminal/dist/app.js; index.html loads that, nothing else.

import { Terminal } from "@xterm/xterm";
import { FitAddon } from "@xterm/addon-fit";
import { WebLinksAddon } from "@xterm/addon-web-links";
import { spawn, fetchTree } from "wasi-sh";
import { transform, tuishEnv, onlySh } from "../tweaks.mjs";

// ?dom keeps the DOM renderer (readable .xterm-rows) for headless assertions.
const DOM_ONLY = new URLSearchParams(location.search).has("dom");
const boot = document.getElementById("boot");
const bootDone = () => boot.classList.add("gone");

// System monospace — no web font, so the page has ZERO cross-origin loads (see
// the COEP/service-worker note in the head). Box-drawing and block glyphs are
// drawn by xterm's customGlyphs (WebGL), not the font, so they stay crisp.
const FONT = "ui-monospace, 'DejaVu Sans Mono', 'Menlo', 'Consolas', monospace";
try { await document.fonts.ready; } catch {}

// 16-color theme on the brand palette (index.sh mostly uses truecolor; this keeps
// any basic-SGR output on-palette). Greens/blues echo the site's headings/links.
const theme = {
  background:"#171b20", foreground:"#ced5e1", cursor:"#78c47e", cursorAccent:"#171b20",
  selectionBackground:"#22304a",
  black:"#0d1117", red:"#ff6b7f", green:"#78c47e", yellow:"#e2b880", blue:"#76aaec",
  magenta:"#b5a0ff", cyan:"#7dd3d8", white:"#ced5e1",
  brightBlack:"#556074", brightRed:"#ff8ca0", brightGreen:"#9ad79e", brightYellow:"#efcea0",
  brightBlue:"#9ecbff", brightMagenta:"#cbb8ff", brightCyan:"#a3e6ea", brightWhite:"#eef2f8"
};

const term = new Terminal({
  cursorBlink:false, cursorStyle:'bar', fontSize:15, fontFamily:FONT, lineHeight:1.0,
  letterSpacing:0, convertEol:false, allowProposedApi:true, scrollback:0, customGlyphs:true, theme
});
const fit = new FitAddon(); term.loadAddon(fit);
// Auto-link URLs the shell prints (the dim inline URLs in posts) — opens in a new tab.
term.loadAddon(new WebLinksAddon());
// The reader sets the tab title (OSC 2) as you navigate — mirror the HTML <title>.
term.onTitleChange((t) => { if (t) document.title = t; });

// tuish sends DECSCUSR 0 to restore the caret; xterm reads 0 as a blinking block.
// Answer 0 ourselves and let 1-6 through.
term.parser.registerCsiHandler({ intermediates:' ', final:'q' }, params => {
  if ((params[0] || 0) !== 0) return false;
  term.options.cursorStyle = 'bar'; term.options.cursorBlink = false; return true;
});

// System clipboard via OSC 52 — the reader emits ESC]52;c;<base64> when you copy a
// code snippet (clip.sh). xterm parses OSC but has no 52 handler, so we add one.
// Write-only: a clipboard READ ("?") is never honoured.
term.parser.registerOscHandler(52, (data) => {
  const semi = data.indexOf(";");
  if (semi < 0) return true;
  const payload = data.slice(semi + 1);
  if (payload === "?") return true;
  try {
    const text = new TextDecoder().decode(Uint8Array.from(atob(payload), (c) => c.charCodeAt(0)));
    window.__clip = text;                       // test hook
    navigator.clipboard?.writeText(text).catch(() => {});
  } catch {}
  return true;
});

// Character-width provider matching tuish exactly (verbatim port of
// _tuish_char_width; keeps emoji/CJK cells aligned with the shell).
function tuishWidth(cp){
  if(cp<32)return 0; if(cp<127)return 1; if(cp<160)return 0; if(cp<768)return 1;
  if(cp<880)return 0; if(cp<4352)return 1; if(cp<4448)return 2; if(cp<4608)return 0;
  if(cp<8203){ if(cp>=6832&&cp<=6911)return 0; if(cp>=7616&&cp<=7679)return 0; return 1; }
  if(cp<=8207)return 0;
  if(cp<8986){ if(cp>=8400&&cp<=8447)return 0; return 1; }
  if(cp<=8987)return 2;
  if(cp<11904){
    if(cp>=9725&&cp<=9726)return 2; if(cp>=9748&&cp<=9749)return 2; if(cp>=9800&&cp<=9811)return 2;
    if(cp===9855)return 2; if(cp===9875)return 2; if(cp===9889)return 2; if(cp>=9898&&cp<=9899)return 2;
    if(cp>=9917&&cp<=9918)return 2; if(cp>=9924&&cp<=9925)return 2; if(cp===9934)return 2; if(cp===9940)return 2;
    if(cp===9962)return 2; if(cp>=9970&&cp<=9971)return 2; if(cp===9973)return 2; if(cp===9978)return 2;
    if(cp===9981)return 2; if(cp===10024)return 2; if(cp>=10060&&cp<=10062)return 2; if(cp>=10067&&cp<=10069)return 2;
    if(cp===10071)return 2; if(cp>=10133&&cp<=10135)return 2; if(cp===10145)return 2; if(cp===10160)return 2;
    if(cp===10175)return 2; if(cp>=11035&&cp<=11036)return 2; if(cp===11088)return 2; if(cp===11093)return 2;
    return 1;
  }
  if(cp<19904)return 2; if(cp<19968)return 1; if(cp<40960)return 2; if(cp<44032)return 1;
  if(cp<55216)return 2; if(cp<63744)return 1; if(cp<64256)return 2; if(cp<65024)return 1;
  if(cp<65040)return 0; if(cp<65072)return 1; if(cp<65136)return 2; if(cp<65281)return 1;
  if(cp<65377)return 2; if(cp<65504)return 1; if(cp<65511)return 2;
  if(cp>=65529&&cp<=65531)return 0; if(cp>=917760&&cp<=917999)return 0;
  if(cp>=127744&&cp<=129791)return 2; if(cp>=131072&&cp<=196607)return 2; if(cp>=196608&&cp<=262143)return 2;
  return 1;
}
try {
  term.unicode.register({ version:'tuish', wcwidth:tuishWidth,
    charProperties(cp, preceding){
      let width = tuishWidth(cp);
      let shouldJoin = width === 0 && preceding !== 0;
      if (shouldJoin){ const ow = (preceding >> 1) & 0x3; if (ow === 0) shouldJoin = false; else if (ow > width) width = ow; }
      return ((0 & 0xffffff) << 3) | ((width & 3) << 1) | (shouldJoin ? 1 : 0);
    }});
  term.unicode.activeVersion = 'tuish';
} catch {}

term.open(document.getElementById("term"));
if (!DOM_ONLY) {
  // WebGL, then xterm's built-in DOM renderer. The canvas addon used to sit
  // between the two; it was never updated for xterm 6 — it still declares a
  // peer on xterm ^5 and last shipped in 2024 — so it is no longer installed.
  try {
    const { WebglAddon } = await import("@xterm/addon-webgl");
    term.loadAddon(new WebglAddon());
  } catch {}
}
fit.fit();
window.__term = term;

// ── Cross-origin isolation guard (spawn needs SharedArrayBuffer) ────────────
if (!crossOriginIsolated) {
  const regs = navigator.serviceWorker ? await navigator.serviceWorker.getRegistrations() : [];
  boot.querySelector(".sub").textContent = regs.length
    ? "cross-origin isolation unavailable — serve with COOP/COEP headers"
    : "enabling cross-origin isolation (the page will reload)…";
} else {
  // ── Mount the guest FS: tuish sources at /src, the reader at /site, and the
  //    generated .tui content at /content (the *.tui siblings of the HTML). ──
  // These stay relative to the DOCUMENT, not to this module: fetch() resolves
  // against document.baseURI, so ./ is /terminal/ even though the bundle lives
  // in /terminal/dist/. Only the two new URL(..., import.meta.url) lookups
  // below are module-relative.
  const [srcManifest] = await Promise.all([ (await fetch("./manifest.json")).json() ]);
  const files = {
    ...await fetchTree({ paths: srcManifest.src, baseUrl: "./tuish/src", mount: "/src", filter: onlySh, transform }),
    ...await fetchTree({ manifestUrl: "./content.json", baseUrl: "..", mount: "/content" }),
    // The reader itself: revalidate every boot (cheap 304 when unchanged) so a
    // deploy reaches returning visitors immediately, not after GitHub Pages'
    // ~10-min max-age lapses. The tuish sources and .tui content below stay on
    // the default HTTP cache — they change rarely and tolerate the window.
    "/site/index.sh": await (await fetch("./index.sh", { cache: "no-cache" })).text(),
  };

  const dec = new TextDecoder();
  let session = null, gen = 0, firstFrame = false, lastExit = 0;

  // Boot target, kept fresh from the reader's page reports so a resize-respawn
  // (or a crash respawn) lands on the same page + language.
  const q = new URLSearchParams(location.search);
  let bootToken = q.get("p") || "home";     // home | blog | post:<base>
  let bootLang  = q.get("lang") === "pt" ? "pt" : "en";

  // TUISH_CTRL tells index.sh a host is listening on stderr (the \x1e channel).
  const geom = () => { fit.fit(); return { ...tuishEnv(term.cols, term.rows), TUISH_CTRL: "1" }; };

  // ── The control channel ─────────────────────────────────────────────────
  // index.sh talks to us on STDERR, framed by \x1e (RS):
  //   \x1epage:<lang>:<token>\x1e   where we are (restored on respawn)
  //   \x1enav:<url>\x1e             switch to the HTML site (the 'w' key)
  //   \x1enav:_blank:<url>\x1e      open a URL in a new tab
  let ctrl = "";
  function handleStderr(text){
    ctrl += text;
    let m, last = 0;
    const re = /\x1e(?:page:([a-z]{2}):([^\x1e]+)|nav:([^\x1e]+))\x1e/g;
    while ((m = re.exec(ctrl)) !== null){
      last = re.lastIndex;
      if (m[1]) { bootLang = m[1]; bootToken = m[2]; }
      else if (m[3]) {
        const v = m[3];
        if (v.startsWith("_blank:")) window.open(v.slice(7), "_blank", "noopener");
        else location.href = v;
        return;
      }
    }
    ctrl = ctrl.slice(last).slice(-8192);
  }

  // Bundling flattens wasi-sh's own import.meta.url lookups onto this file, so
  // its defaults would resolve the wasm and the worker relative to dist/ by
  // accident rather than by intent. Both are passed explicitly instead — the
  // build puts them right here, next to app.js.
  const wasmUrl = new URL("./busybox.wasm", import.meta.url);
  const workerUrl = new URL("./worker.mjs", import.meta.url);

  async function start(){
    const myGen = ++gen;
    const prev = session; session = null;
    if (prev) { try { prev.terminate(); } catch {} }
    firstFrame = false;
    term.reset();
    const s = await spawn({
      files, args: ["busybox","sh","/site/index.sh", bootToken, bootLang], env: geom(),
      wasm: wasmUrl, workerUrl,
    });
    if (myGen !== gen) { try { s.terminate(); } catch {} return; }
    session = s;
    s.onOutput((bytes, channel) => {
      if (myGen !== gen) return;
      if (channel === "stderr") { handleStderr(dec.decode(bytes)); return; }
      window.__rx = ((window.__rx || "") + dec.decode(bytes)).slice(-8000);
      if (!firstFrame) { firstFrame = true; bootDone(); }
      term.write(bytes);
    });
    s.onError((e) => { if (myGen === gen) console.warn("[session]", e.message); });
    s.onExit((code) => {
      if (myGen !== gen) return;
      console.warn("[session] shell exited (code " + code + ") — respawning " + bootToken);
      const now = Date.now();
      if (now - lastExit < 1500) {
        term.write("\r\n\x1b[31mThe shell keeps exiting on boot.\x1b[0m\r\nReload to try again; see the console.\r\n");
        return;
      }
      lastExit = now; start();
    });
    term.focus();
  }

  // Keyboard → the session, every key unmodified.
  term.onData((d) => { if (session) session.write(d); });

  // Resize: reflow, hand the live geometry to the guest (wasi-sh synthesizes
  // SIGWINCH; index.sh re-wraps in place — no respawn).
  let rz;
  addEventListener("resize", () => {
    clearTimeout(rz);
    rz = setTimeout(() => { fit.fit(); if (session) session.resize(term.cols, term.rows); }, 120);
  });

  try { await start(); } catch (e) { window.__err = String(e && e.stack || e); }
  setTimeout(bootDone, 8000);
}
