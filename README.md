# alganet.github.io

This repository contains the source for the personal blog hosted at **https://alganet.github.io/**.

The site ships in **two forms of the same content**: the ordinary HTML pages, and a
**shell/terminal version** under [`/terminal/`](terminal/) — a pure-shell TUI that runs
in the browser. Every page carries a *Terminal* switcher into it; the shell version has a
`w` key that switches back. The HTML remains canonical (SEO, feeds, accessibility); only
`/terminal/` needs cross-origin isolation.

The same reader also runs in a **real terminal** — the site is `curl`-able:

```sh
bash -c "$(curl -fsSL https://alganet.github.io/terminal/index.sh)"
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

### `build.sh`

Used to regenerate the site from its HTML templates and posts.

Run `./build.sh` to update all generated files after adding, editing or removing
posts. It reads the markdown with tuish's `md.sh` and renders the HTML through
`render.sh`; the terminal version reads the very same files, so **both forms stay in
sync automatically** — not by being generated from each other, but by being two
renderings of one parse. It also refreshes each post's machine-maintained front
matter (`alt`, `date`, `lang`) and writes `terminal/content.json`.

### `vendor.sh`

Snapshots the shell-TUI *engine* into `terminal/`: the [tui.sh](https://github.com/alganet/tuish) toolkit and the [wasi-sh](https://github.com/alganet/wasi-sh) runtime (busybox-on-wasm) from the sibling checkouts `../tuish` and `../wasi-sh`. Run `./vendor.sh` only when tuish or wasi-sh themselves change; the vendored snapshot is committed.

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

The site is automatically published via GitHub Pages from the `main` branch. Deployed content is available at:

**https://alganet.github.io/**

