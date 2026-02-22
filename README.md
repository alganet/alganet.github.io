# alganet.github.io

This repository contains the source for the personal blog hosted at **https://alganet.github.io/**.

## Overview

- HTML files are stored in the root directory and under the `blog/` subdirectory.
- `index.html`, `blog.html` and their Portuguese counterparts are the main pages.
- `feed.xml` and `feed.pt.xml` provide RSS feeds.
- Static assets like `style.css`, `script.js`, and images live alongside the HTML.

## Scripts

### `build.sh`

Used to regenerate the site from its HTML templates and posts.

Run `./build.sh` to update all generated files after adding, editing or removing posts. It relies on simple shell commands, `sed`, or other tools to assemble indexes and feeds.

### `newpost.sh`

Creates a new post template in the `blog/` directory. It:

Usage example:

```sh
./newpost.sh "My New Entry" "Meu Novo Post"
```

This will produce something like `blog/2026-02-23-12-My-New-Entry.html` and `blog/2026-02-23-12-Meu-Novo-Post.pt.html` which you can manually edit.

## Publishing

The site is automatically published via GitHub Pages from the `main` branch. Deployed content is available at:

**https://alganet.github.io/**

