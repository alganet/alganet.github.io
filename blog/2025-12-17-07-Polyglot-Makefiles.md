<!--
SPDX-FileCopyrightText: 2025 Alexandre Gomes Gaigalas <alganet@gmail.com>

SPDX-License-Identifier: CC-BY-NC-SA-4.0
-->
---
alt: 2025-12-17-07-Makefiles-Poliglotas.pt
date: December 17, 2025
author: Alexandre Gomes Gaigalas
lang: en
---

# Polyglot Makefiles

 While Unix-like systems typically use **GNU make**, Windows environments based on Microsoft toolchains, traditionally use **nmake**. Although alternatives like GNU make on Windows exist (MSYS2, MinGW, WSL), many projects still need to support native **nmake** workflows. 

 Unfortunately, GNU make and nmake are similar tools with **different syntax and features**. This often leads to duplicated makefiles or forcing contributors to install a non-native tool. Here we explore a technique to create a single `Makefile` that works for both. 

## Why this is useful
- **One source of truth:** Common variables, targets and documentation live in a single `Makefile`. 
- **Platform delegation:** Tool or platform-specific rules live in small, focused include files. 
- **Controlled complexity:** The polyglot logic is isolated to a tiny, well-documented block.


## The key bit

The polyglot solution for the unified `Makefile` looks like this:

```
SHARED_VAR = some_value

shared_target:
	echo 123

# --- POLYGLOT MAGIC BEGINS
# \
!ifndef 0 # \
!include "nmake-specific.mk" # \
!else
include gnu-specific.mk
# \
!endif
# --- POLYGLOT MAGIC ENDS
```

 This single block allows each tool to include its own implementation file while sharing the same variables and targets. 

## How it works

This snippet relies on subtle but well-defined differences between GNU make and nmake parsing rules.

**What GNU make sees:**

 GNU make supports line continuation (`\`) inside comments. Because of this, the `!`-prefixed nmake directives become part of a multi-line comment and are ignored. 

```
# --- POLYGLOT MAGIC BEGINS
# \
!ifndef 0 # \
!include "nmake-specific.mk" # \
!else
include gnu-specific.mk
# \
!endif
# --- POLYGLOT MAGIC ENDS
```

**What nmake sees:**

 nmake does not support multi-line comments. It recognizes the `!ifndef`, `!include`, `!else`, and `!endif` directives and evaluates the first branch. 

 The condition `!ifndef 0` is intentionally chosen: `0` is not a predefined macro in nmake, so the condition is always true. This reliably selects the nmake-specific branch without depending on environment variables. 

```
# --- POLYGLOT MAGIC BEGINS
# \
!ifndef 0 # \
!include "nmake-specific.mk" # \
!else
include gnu-specific.mk
# \
!endif
# --- POLYGLOT MAGIC ENDS
```

## Typical file layout

```
Makefile
gnu-specific.mk
nmake-specific.mk
```

## Caveats and limitations
- This relies on GNU make’s handling of line continuation inside comments.
- The polyglot block should remain small and self-contained.
- Editors or formatters that alter trailing backslashes may silently break this construct.


## Final thoughts

 Polyglot Makefiles are a powerful technique when used sparingly. They allow a single shared build definition while preserving native workflows on each platform. 

This technique was used in the [PHL](https://github.com/alganet/PHL) repository to simplify the build process. Both Unix and Windows builds share a lot of variables and targets, leveraging a single source of truth for the built objects, dependencies and more.
