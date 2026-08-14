<!--
SPDX-FileCopyrightText: 2026 Alexandre Gomes Gaigalas <alganet@gmail.com>

SPDX-License-Identifier: CC-BY-NC-SA-4.0
-->
---
alt: 2026-06-28-12-POSIX-Nao-E-Um-Shell.pt
date: June 28, 2026
author: Alexandre Gomes Gaigalas
lang: en
---

# POSIX Is Not A Shell

When someone says "write it in POSIX shell for portability," they mean well.

POSIX is a specification. Not a program. The thing that actually runs your script is bash, dash, ash, ksh, yash, or one of a dozen others. They each implement POSIX with their own gaps, extensions, and historical accidents.

Here is a small experiment. One line, no flags, no functions, nothing exotic:

```
#!/bin/sh
echo "C:\new"
```

On bash, ksh, and a handful of others, you get back exactly what you typed:

```output
C:\new
```

On dash (which *is* `/bin/sh` on Debian, Ubuntu, and Alpine) the same line prints:

```output
C:
ew
```

dash's `echo` interprets `\n` as a newline. bash's does not. Run it across [shell-versions](https://github.com/alganet/shell-versions) and the shells split almost evenly: about half treat the backslash literally, the other half expand it.

```
docker run --rm alganet/shell-versions:all -c 'echo "C:\new"'
```

POSIX does not break the tie. The standard explicitly leaves [`echo`'s treatment of backslash escapes **implementation-defined**](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/echo.html#tag_20_37_05), and [encourages you to use `printf` instead](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/echo.html#tag_20_37_16). So "POSIX `echo`" is not a behavior you can write a script against. It is a documented disagreement.

This is not a contrived edge case. `echo` is the first command anyone learns. It is what "POSIX compliant" means in practice: compliant with the parts the spec actually pins down, on the versions that happened to ship.

## The Problem With Dialects

Natural languages have dialects. Brazilian Portuguese and European Portuguese are both Portuguese. A native speaker of one can understand the other with effort, but they are not the same. You cannot write Portuguese and expect it to work identically everywhere.

Shell scripting has the same problem. Bash is not *the* shell. It is *a* shell with a specific set of behaviors, many of which are not in POSIX and some of which contradict implementations that are technically more compliant (like dash).

The community pretends otherwise. We say "sh script" and mean "bash with `-e -u -o pipefail`." We say "POSIX compliant" and mean "it worked in CI." We say "portable" and mean "it ran on the two machines I tried."

## What Validation Actually Looks Like

I have been building [shell-docs](https://github.com/alganet/shell-docs), a cross-shell reference that validates each documented feature across 14 shells. The process is mechanical: write an example, run it on every shell, record the output, check for divergence.

Most features work the same. Some do not.

`$#` - the count of positional parameters. Works everywhere, no surprises.

`local` - not in POSIX at all. Every shell has it anyway, with different scoping rules.

`$(( ))` - [arithmetic expansion](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html#tag_18_06_04), universally supported. Division by zero: varies by implementation.

`[[ ]]` - not POSIX, not present in dash. If your script uses it under `#!/bin/sh`, it will silently fail on every system where `/bin/sh` is dash (Debian, Ubuntu, Alpine).

The ones that diverge are not bugs. They are accumulated decisions from decades of independent implementations, each targeting a slightly different point in the spec's history: 1988, 2001, 2017.

## The Honest Version of "Portable"

Portable means: tested across the range of shells it will actually run on.

The tool [shell-versions](https://github.com/alganet/shell-versions) tracks what version of each shell ships with major distributions. At time of writing, `/bin/sh` is:
- `dash 0.5.12` on Ubuntu 24.04
- `bash 3.2.57` on macOS (unchanged in fifteen years; GPL v3 kept bash 4.x out of the base system)
- `busybox ash` on Alpine
- `ksh93` on some enterprise Linux distributions


These are not the same program. They are not even the same age.

If you write `#!/bin/bash` and mean it, that is fine. At least it is honest. Write `#!/bin/sh` and you are promising something you should verify.

## Verification Is A Habit

The validation harness in shell-docs runs each example against all 14 shells in isolation, captures stdout and exit codes, and compares them against a known-good table. When a new shell version is released, you run it again.

This is not complex. It is just work that does not happen by default.

The payoff is that "it works in POSIX sh" can mean something concrete: it works in the fourteen shells I tested, and here are the results. That is a different claim than "I ran it in bash and it looked fine."

POSIX is not a shell. It is a promise about what shells should do. Verification is how you find out which ones kept it.
