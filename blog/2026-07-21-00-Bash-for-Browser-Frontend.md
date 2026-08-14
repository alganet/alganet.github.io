<!--
SPDX-FileCopyrightText: 2026 Alexandre Gomes Gaigalas <alganet@gmail.com>

SPDX-License-Identifier: CC-BY-NC-SA-4.0
-->
---
alt: 2026-07-21-00-Bash-para-Frontend-no-Navegador.pt
date: July 21, 2026
author: Alexandre Gomes Gaigalas
lang: en
---

# Bash for Browser Frontend

The title is bait. It is also, annoyingly, true.

If you have a terminal within reach, run this:

```
bash -c "$(curl -fsSL https://alganet.github.io/terminal/index.sh)"
```

What comes back is not a screenshot of the site and not a dump of its text, but the site itself, made navigable, so that the arrow keys scroll it, Tab steps between its links, Enter opens a post, and the `y` key copies a code snippet to your clipboard. If you would rather stay in a browser, the same program runs there as well, either at the [terminal version of the site](/terminal/) or through the small `$ []` switcher tucked into the corner of every page.

It is a single script that runs in both places without much caring which one it landed in, and the stack it rests on is short enough to describe in full.

## wasi-sh

[wasi-sh](https://github.com/alganet/wasi-sh) is BusyBox compiled to WebAssembly: a real, fork-free POSIX shell that carries some fifty coreutils as in-process builtins and runs inside a browser tab with no server standing behind it. It can mount a file tree and move bytes in and out, which is very nearly everything a program needs to feel at home.

## tuish

[tuish](https://github.com/alganet/tuish) is a terminal interface toolkit written in portable shell script. It compiles to nothing and spawns no subprocesses, drawing instead by writing ANSI escape sequences directly, and on its own it handles keyboard and mouse events, box drawing, truecolor, Unicode width, and scrollable viewports.

Put those two together and a shell script becomes a frontend, which is the whole of the trick and the reason the title is only half a joke.

## Not bash, actually. True shell though.

The shell running in the browser is not bash but BusyBox `ash`, and the toolkit that does the real work runs without modification across five of them:

```output
bash        4+
zsh         5+
ksh93       AJM 93u+
mksh        R59+
busybox sh  1.30+
```

That leaves `bash`, the one word the title leans on, as the shell that contributes the least. The part worth paying attention to is the portable shell underneath it, which merely happens to reach your browser as a BusyBox build.

The rest is left for you to find, since the whole of the source is a single [shell script](/terminal/index.sh) that you are welcome to read and, better still, to run.
