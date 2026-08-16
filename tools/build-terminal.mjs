// Build terminal/'s browser bundle from the npm dependencies.
//
// Everything here lands in terminal/dist/, which is NOT committed — it is the
// one part of the site that needs a toolchain. build.sh, render.sh and
// vendor.sh stay pure POSIX shell and their output stays in git; this only
// covers the third-party JS that used to be vendored by hand.
//
// Three entry points rather than one, for reasons that are not stylistic:
//
//   app      the page's own module. ESM output because it uses top-level
//            await (document.fonts.ready), and code-splitting because the
//            WebGL and canvas renderers are await import()ed as a fallback
//            chain — ~210 KB that most visitors never fetch.
//
//   worker   wasi-sh's worker entry, built separately because it is loaded as
//            a real Worker, not imported. spawn() resolves it with
//            `new URL('./worker.mjs', import.meta.url)`, which after bundling
//            would point at terminal/dist/ — so that is exactly where this
//            puts it, and app.mjs passes the URL explicitly anyway.
//
//   css      xterm's stylesheet, which the page links directly.
//
// busybox.wasm is copied rather than bundled: wasi-sh resolves it from
// import.meta.url too, and app.mjs overrides that with an explicit URL.

import { mkdir, copyFile, stat } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import * as esbuild from 'esbuild';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const outdir = join(root, 'terminal', 'dist');
const dev = process.argv.includes('--dev');

await mkdir(outdir, { recursive: true });

const common = {
  bundle: true,
  format: 'esm',
  target: 'es2022',
  minify: !dev,
  sourcemap: dev,
  logLevel: 'info',
  absWorkingDir: root,
  platform: 'browser',
  // wasi-sh is isomorphic: options.mjs reads the wasm off disk when it detects
  // node, via `await import('node:fs/promises')`. That branch is unreachable in
  // a browser (its isNode check is false), but esbuild still has to resolve the
  // specifier, so leave node builtins external rather than shimming them in.
  external: ['node:*'],
};

// The page module. `splitting` needs an outdir, and keeps the two renderer
// addons in their own lazily-fetched chunks.
await esbuild.build({
  ...common,
  entryPoints: [join(root, 'terminal', 'src', 'app.mjs')],
  outdir,
  splitting: true,
  entryNames: 'app',
  chunkNames: 'chunk-[hash]',
});

// The worker. Named exactly worker.mjs so the URL app.mjs hands to spawn()
// resolves next to app.js.
await esbuild.build({
  ...common,
  entryPoints: [join(root, 'node_modules', 'wasi-sh', 'src', 'worker.mjs')],
  outfile: join(outdir, 'worker.mjs'),
});

await esbuild.build({
  ...common,
  entryPoints: [join(root, 'node_modules', '@xterm', 'xterm', 'css', 'xterm.css')],
  outfile: join(outdir, 'xterm.css'),
});

const wasm = join(root, 'node_modules', 'wasi-sh', 'dist', 'busybox.wasm');
await copyFile(wasm, join(outdir, 'busybox.wasm'));

// A build that silently produced a 0-byte wasm or lost the worker would fail
// only in the browser, at spawn() time, with a message about SharedArrayBuffer
// that points nowhere near the real cause.
for (const f of ['app.js', 'worker.mjs', 'xterm.css', 'busybox.wasm']) {
  const { size } = await stat(join(outdir, f));
  if (!size) throw new Error(`build produced an empty terminal/dist/${f}`);
  console.log(`  ${f.padEnd(14)} ${size.toLocaleString()} bytes`);
}
