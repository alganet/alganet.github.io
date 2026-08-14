<!--
SPDX-FileCopyrightText: 2026 Alexandre Gomes Gaigalas <alganet@gmail.com>

SPDX-License-Identifier: CC-BY-NC-SA-4.0
-->
---
alt: 2026-03-12-20-Refatoracao-Feng-Shui.pt
date: March 12, 2026
author: Alexandre Gomes Gaigalas
lang: en
---

# Feng Shui Refactoring

If you've worked on a large codebase long enough, you've probably seen a certain kind of refactoring that *feels* productive but doesn't actually improve the system.

Some files get renamed, functions move around, directories and namespaces are reorganized, but **nothing changes**.

The diff is large, the structure looks different, and the pull request description says something like "clean up project structure". Lots of things change, but readability hasn't really improved and the behavior stays the same.

## What It Looks Like

A feng shui refactor rearranges code without improving its structure. The system looks different, but it behaves the same and remains just as hard to reason about.

A common example is **renaming without clarifying behavior**.

Before:

```
def handle(x):
    return process(x)
```

After:

```
def process_event(event):
    return process(event)
```

The names sound nicer, but the design problem hasn't changed: the function still hides what it actually does. Specific names like "handle", "manage", "orchestrate" and namespaces such as "common" and "utils" often act as magnets for this kind of pseudo-refactoring.

Another example is **moving code without changing dependencies**.

Before:

```
services/
    billing.py
    notifications.py
```

After:

```
domain/
    billing_service.py
    notification_service.py
```

If both modules still import half the application and call each other in complex ways, the architecture hasn't improved. The furniture just moved.

## Why It Happens

This kind of change is attractive because it transmit the *intent of improvement*. You might think better names will foster better modularization later, or breaking up something without untangling the dependencies will lead to more modularization later.

Real refactoring requires understanding the system well enough to identify structural problems. That usually means reading code, tracing behavior, and forming a mental model **before** touching anything.

## Good Renames

The most useful refactors tend to remove something: duplication, hidden coupling, unnecessary indirection.

Sometimes, renaming *can in fact be useful*, such as clarifying a buried business rule.

Before:

```
def process(order):
    if order.total > 100:
        order.discount = order.total * 0.1
```

After:

```
def apply_loyalty_discount(order):
    if order.total > 100:
        order.discount = order.total * 0.1
```

Interestingly, these kinds of refactors often produce *smaller* diffs than large reorganizations.

## What Real Refactoring Looks Like

Real refactoring tends to simplify how the system works rather than how it is arranged.

A good example is **removing hard-coded knowledge** that quietly spreads through the system.

Before:

```
def shipping_cost(order):
    if order.country == "US":
        return 5
    return 15
```

After:

```
SHIPPING_RATES = {
    "US": 5,
    "INTL": 15,
}

def shipping_cost(order):
    region = "US" if order.country == "US" else "INTL"
    return SHIPPING_RATES[region]
```

The behavior hasn't changed, but the rule is now visible and centralized instead of buried inside a conditional. When the pricing inevitably changes, there is a clear place to update it.

These kinds of changes rarely produce dramatic diffs. Often they involve deleting code, collapsing layers, or making relationships more explicit.

But they steadily reduce the amount of work required to understand and modify the system.

## A Small Question

Before starting a refactor, it can help to ask a simple question:

What concrete problem will this change solve?

Sometimes the answer is clear: duplicated logic disappears, a circular dependency breaks, or a domain concept becomes explicit.

Other times the answer is harder to articulate. The change mostly affects how the code *looks*.

## Rearranging the Room

Sometimes moving things around *does in fact improve them*, but without a clear purpose, it's a red flag. If you can't explain what problem it solves, it might be just one of these feng shui refactors.
