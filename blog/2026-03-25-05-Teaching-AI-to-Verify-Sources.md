<!--
SPDX-FileCopyrightText: 2026 Alexandre Gomes Gaigalas <alganet@gmail.com>

SPDX-License-Identifier: CC-BY-NC-SA-4.0
-->
---
alt: 2026-03-25-05-Ensinando-IA-a-Verificar-Fontes.pt
date: March 25, 2026
author: Alexandre Gomes Gaigalas
lang: en
---

# Teaching AI to Verify Its Sources

LLMs confidently cite documentation that doesn't exist.

“According to MDN, `Promise.allSettled()` returns a promise that resolves when all promises have completed.”

That *sounds* right. But MDN actually says “fulfills when all of the input's promises settle”. Different verb, different semantics. A human might not catch this. But a tool can.

This post shows how to make an AI verify its own claims before writing them, using [apysource](https://github.com/alganet/apysource) and a simple instruction file.

A working demo of this workflow lives at [alganet/ecmascript-featurecard](https://github.com/alganet/ecmascript-featurecard).

## The Instruction File

Most coding agents support project-level instruction files: a markdown file in the repo root that the agent reads before starting work. Drop this into yours:

```
# Source Verification

When writing documentation that references external sources, prefer
direct quotes over paraphrasing. Every factual claim about what a
source says should be backed by an exact snippet from that source.

1. Before claiming "X says Y", verify the quote:
       apysource locate "<url>" "<exact quote>"
   If the snippet is not found, do not make the claim.

2. After verifying, register the claim:
       apysource add sources.yaml "<url>" "<exact quote>" --label "<claim name>"

3. After all documentation is written, run the full check:
       apysource check sources.yaml
   All checks must pass before considering the task complete.
```

Think of it as an automated `[citation needed]`, the kind Wikipedia editors tag on unsourced claims, except here the agent is both the writer and the fact-checker, and the tag is enforced before the text is ever committed.

That's the entire integration. The agent reads this file, gains access to three shell commands, and follows the workflow: **locate -> add -> check**.

## The Happy Path

A user asks the agent to add `Array.findLast()` to the reference card.

The agent first verifies a quote from the MDN page:

```
$ apysource locate \
    "https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/findLast" \
    "iterates the array in reverse order"
```

```
# Found in: https://developer.mozilla.org/en-US/docs/.../Array/findLast
# Targetter: section

- label: ''
  section: Array.prototype.findLast(), paragraph 2
  snippet: iterates the array in reverse order
```

The snippet exists. The agent registers it:

```
$ apysource add sources.yaml \
    "https://developer.mozilla.org/.../Array/findLast" \
    "iterates the array in reverse order" \
    --label "Array.findLast() iteration"
```

```output
  Located: section -> Array.prototype.findLast(), paragraph 2
  Added new source: https://developer.mozilla.org/.../Array/findLast
  Added fragment "Array.findLast() iteration" to sources.yaml
```

Then runs the full check:

```
$ apysource check sources.yaml
```

```output
  [PASS] Fragments: cache resolution............. 8/8
  [PASS] Fragments: content extraction........... 8/8
  [PASS] Fragments: snippet verified............. 8/8
```

All 8 fragments (the original 7 plus the new one) pass. The agent proceeds to regenerate the reference card with `python generate.py`.

## The Hallucination

Now the agent tries a different quote, one it *thinks* MDN says:

```
$ apysource locate \
    "https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/findLast" \
    "returns the first matching element from the end of the array"
```

```output
Error: snippet not found in https://developer.mozilla.org/.../Array/findLast
```

Exit code 1. The instruction is clear: *“If the snippet is not found, do not make the claim.”*

The agent doesn't write the hallucinated quote. Instead, it goes back to `locate` with a shorter phrase, finds what MDN actually says, and uses that instead.

This is not post-hoc correction. The agent never wrote the wrong claim. The verification happened *before* the documentation was produced.

## CI as Safety Net

Even with the instruction file, agents make mistakes. The CI pipeline is the final gate:

```
# .github/workflows/verify-sources.yml
name: Verify Sources
on: [push, pull_request]
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: pip install apysource
      - run: apysource check sources.yaml
```

If any quote drifts, whether the agent introduced it or MDN changed the page, the build fails. The `sources.yaml` manifest is the contract between the documentation and its sources.

## Final Remarks

Without source verification, AI-generated documentation is a liability. You can't distinguish accurate citations from hallucinations without manually checking every link.

With apysource in the loop, the agent becomes a *verified* documentation author. Every claim is grounded. Every quote is checked. The provenance graph records when it was verified and what the outcome was.

The `sources.yaml` file is a machine-readable bibliography. It can generate reference cards, feed dashboards, or serve as an audit trail.
