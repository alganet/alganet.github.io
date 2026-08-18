# alganet.github.io

This repository contains the source for the personal blog hosted at **https://alganet.dev/**.

The site ships in **two forms of the same content**: the ordinary HTML pages, and a
**shell/terminal version** under [`/terminal/`](terminal/) — a pure-shell TUI that runs
in the browser. Every page carries a *Terminal* switcher into it; the shell version has a
`w` key that switches back. The HTML remains canonical (SEO, feeds, accessibility); only
`/terminal/` needs cross-origin isolation.

The same reader also runs in a **real terminal** — the site is `curl`-able:

```sh
bash -c "$(curl -fsSL https://alganet.dev/terminal/index.sh)"
```

`terminal/index.sh` detects it isn't mounted by the browser loader, fetches the tuish
toolkit over HTTP, and sub-`curl`s each `.md` page as you browse (arrows scroll, Tab
moves between links, `⏎` opens, `l` language, `y` copies a code block via OSC 52, `q`
quits). `curl … | sh` works too — it re-execs through `/dev/tty` so the keyboard is live.

## Overview

- HTML files are stored in the root directory and under the `blog/` subdirectory.
- `index.html`, `blog.html` and their Portuguese counterparts are the main pages.
- `feed.xml` and `feed.pt.xml` provide RSS feeds.
- Static assets like `style.css`, `script.js`, and images live alongside the HTML.
- **Posts are markdown.** `blog/<date>-<slug>.md` and its `.pt.md` twin are the only
  authored files; every `.html` is generated. `index.md` is authored too, except its
  Blog list, which `build.sh` rewrites.
- The terminal version reads **those same `.md` files** — there is no intermediate
  format. Both sides parse them with tuish's `md.sh`, so they cannot drift.

## Scripts

Every script here runs under **bash, dash and busybox sh**, and produces
byte-identical output whichever one you use — the generated files are committed,
so a build that differed by interpreter would have two people's diffs reverting
each other.

### `build.sh`

Used to regenerate the site from its HTML templates and posts.

Run `./build.sh` to update all generated files after adding, editing or removing
posts. It reads the markdown with tuish's `md.sh` and renders the HTML through
`render.sh`; the terminal version reads the very same files, so **both forms stay in
sync automatically** — not by being generated from each other, but by being two
renderings of one parse. It also refreshes each post's machine-maintained front
matter (`alt`, `date`, `lang`) and writes `terminal/content.json`.

### `vendor.sh`

Snapshots the [tui.sh](https://github.com/alganet/tuish) toolkit into `terminal/` from the sibling checkout `../tuish`. Run `sh vendor.sh` only when tuish itself changes; the vendored snapshot is committed.

The browser half of the engine — [wasi-sh](https://github.com/alganet/wasi-sh) (busybox-on-wasm) and [xterm.js](https://xtermjs.org) — comes from npm instead, declared in `package.json` and bundled into `terminal/dist/` by `tools/build-terminal.mjs`:

```sh
npm ci && npm run build:terminal
```

`terminal/dist/` is **not** committed; the deploy workflow builds it. tuish stays vendored because the name `tuish` on npm belongs to an unrelated project.

`build.sh` sources the **vendored** `md.sh` and `hl.sh` rather than `../tuish/src`,
so the HTML is produced by the same bytes the browser mounts, and a clean checkout
builds without the sibling repositories.

The terminal version's own program is [`terminal/index.sh`](terminal/index.sh) — a generic, data-driven blog reader; [`terminal/index.html`](terminal/index.html) is the browser boot loader.

### `newpost.sh`

Creates a new post template (English + Portuguese) in the `blog/` directory, then runs
`build.sh` — so the new post appears in both the HTML site and the terminal version at once.

Usage example:

```sh
./newpost.sh "My New Entry" "Meu Novo Post"
```

This will produce something like `blog/2026-02-23-12-My-New-Entry.md` and
`blog/2026-02-23-12-Meu-Novo-Post.pt.md`, which are the files you edit. Re-run
`./build.sh` afterwards to regenerate the pages, indexes and feeds.

## Publishing

The site is automatically published to GitHub Pages by `.github/workflows/deploy.yml` on every push to `master`. The workflow builds `terminal/dist/` and uploads the whole tree — the terminal reads this site's own markdown and shell sources at runtime, so they are deployed content, not build inputs.

This requires **Settings → Pages → Source** to be set to **GitHub Actions**. On "Deploy from a branch" GitHub also runs its own builder, which publishes the raw branch — and `terminal/dist/` is not committed, so the terminal 404s whenever that build lands after the workflow's.

Deployed content is available at:

**https://alganet.dev/**

### The domain

`alganet.dev` is a custom domain on the *same* GitHub Pages site — the `CNAME` file
here, plus **Settings → Pages → Custom domain**. DNS lives on Cloudflare: four `A`
and four `AAAA` records at the apex pointing at GitHub's Pages addresses, **DNS-only**
(grey cloud), because GitHub renews the certificate over an HTTP-01 challenge that a
proxy in front of it would answer instead.

Nothing was moved. That is the point: because this repo is a *user* site, GitHub
serves the custom domain and 301s `alganet.github.io/<path>` to `alganet.dev/<path>`
for every path, so every URL ever published still resolves — including the `curl`
one-liner above, which `-L` follows.

The feeds are the one place absolute URLs are written (`SITE_URL` in `build.sh`).
Their Atom `<id>`s are deliberately *not* the site URL and are pinned to the old
domain in `FEED_TAG_DOMAIN`: an `<id>` is an identity, and rewriting it would
resurface every post as unread in every reader.

### Cross-origin isolation

The apex is **proxied** through Cloudflare (orange cloud), with SSL/TLS mode
**Full (strict)**. That is not for caching — Pages is already behind a CDN — it is
so that something in front of GitHub can set response headers. A Transform Rule
(*Rules → Transform Rules → Modify Response Header*) matching

```
starts_with(http.request.uri.path, "/terminal/")
```

sets `Cross-Origin-Opener-Policy: same-origin` and
`Cross-Origin-Embedder-Policy: credentialless`. `/terminal/` needs cross-origin
isolation for `SharedArrayBuffer`; the rest of the site must not have it, which is
why the rule is scoped rather than global.

`terminal/coi-serviceworker.js` stays anyway, demoted to a fallback — it no-ops when
the headers are honoured, and covers the browsers where `credentialless` alone does
not isolate by reloading once under `require-corp`. See the comment at the top of
`terminal/index.html`.

One consequence of proxying: visitors get Cloudflare's certificate, and GitHub's own
certificate now only secures the Cloudflare→Pages leg, which Full (strict) validates.
GitHub renews it over an HTTP-01 challenge that passes through the proxy. If that
ever fails the symptom is a 526 — grey-cloud the apex for an hour and let the
renewal complete.

