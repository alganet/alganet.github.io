<!--
SPDX-FileCopyrightText: 2026 Alexandre Gomes Gaigalas <alganet@gmail.com>

SPDX-License-Identifier: CC-BY-NC-SA-4.0
-->
---
alt: 2026-01-19-14-Como-Fazer-Bons-Code-Reviews.pt
date: January 19, 2026
author: Alexandre Gomes Gaigalas
lang: en
---

# How To Make Good Code Reviews

**Good code reviews are an art.** It takes years or sometimes decades to learn how to do them well.

The most important thing, our *prime directive*, is to be **kind and constructive.** Soft skills are one of the key ingredients for a sustained good code review practice.

The other ingredients are technical knowledge and attention to detail.

Here are some of the most important tips that encompass these principles:

## Don't Complain, Teach

When you find an issue, instead of pointing out a mistake, propose a solution and explain why it is better.

Let's take this code change as an example:

```diff
- function ($foo, $bar = null);
+ function ($foo, $bar = null, $baz);

```

❌ Non-constructive review:

> This is wrong because it adds a new parameter without a default value.


This type of review points out a problem but does not offer any guidance on how to fix it. It either assumes the author knows how to fix it but didn't wanted to, or presumes the author doesn't know and leaves them without direction.

✅ Teachable moment:

> Adding a new parameter without a default value can break existing calls to this function. 
>
> You should either provide a default value for the new parameter or update all existing calls to include the new argument.


This type of review not only points out the issue but also provides clear guidance on how to resolve it, making it easier for the author to understand and implement the necessary changes.

## Know When You're Nitpicking 

Nitpicking refers to pointing out minor issues that do not significantly impact the functionality, readability, or maintainability of the code. While attention to detail is important, excessive nitpicking can lead to frustration and demotivation for the author.

Let's take this code change as an example:

```diff
+ $firstPiece = 'square';
+ $middlePiece = 'circle';
+ $lastPiece = 'triangle';

```

❌ Excessive nitpicking:

> Use `$intermediatePiece` instead of `$middlePiece`.


While this suggestion is valid, it may not be significant enough to warrant a change. The original variable name is still clear and understandable.

Nitpicks often come to personal preferences that can't be quite put into automated checks or style guidelines. It's all about the reviewer's preference.

If those preferences end up slowing down the review process or frustrating authors, the review stops being useful and becomes a point of friction.

✅ Friendly suggestion:

> Nitpick: I prefer `$intermediatePiece` instead of `$middlePiece`.


By framing the suggestion as a personal preference rather than a strict rule, it helps maintain a positive and collaborative tone in the review. Nitpicks should not block the code review, and should be optional by default (the author might chose not to perform the suggested change).

## Use References

Links, line numbers, and documentation references can help provide context and support your feedback.

Let's take this code change as an example:

```diff
+ if (isValid($input)) {
+     process($input);
+ } else {
+     error_log('Invalid input');
+ }

```

❌ Vague feedback:

> Our guidelines enforce `ErrorLog::create` instead of `error_log`.


This feedback lacks context and does not provide a clear reference to the specific guideline being violated.

✅ Referenced feedback:

> According to our *coding standards*, we should use `ErrorLog::create` instead of `error_log` for better consistency and maintainability (see line 42).


This feedback provides a clear link to the relevant guideline and explains the reasoning behind the suggestion. 

## Don't Be Repetitive

Sometimes the same suggestion can be applied to multiple parts of the same pull request. Instead of repeating the same feedback multiple times, consider summarizing it once and referencing it where applicable.

Let's take this series of changes:

```diff
// File: parks.php
+ functionA($param1, $param2);

```

```diff
// File: stores.php
+ functionA($param1, $param2);

```

```diff
// File: houses.php
+ functionA($param1, $param2);

```

❌ Repetitive feedback:

> In `functionA`, use named parameters for better readability.


> In `functionB`, use named parameters for better readability.


> In `functionC`, use named parameters for better readability.


The repetitive feedback creates noise and makes the author feel like they are being overwhelmed with the same suggestion multiple times.

It can be also interpreted as the reviewer not taking his time to see the overall pull request as a whole, indicating a poor review process, copying and pasting feedback instead of being more thoughtful.

✅ Consolidated feedback:

> For better readability, consider using named parameters in `functionA`. The same can be applied for `functionB` (file: stores.php), and `functionC` (file: houses.php).


A consolidated feedback on one of the violations is much more effective and respectful of the author's time.

## Don't Guess, Be Sure It Works

There is nothing more frustrating than receiving a suggestion that doesn't actually work or causes new issues.

Let's take this code change as an example:

```diff
+ "image-reader-dependency": 1.0

```

❌ Guess Suggestion:

> You can just replace this for 2.0 which is more recent!


In this scenario, the reviewer suggested 2.0 without testing if it actually works. This can lead to broken builds or unexpected behavior, which ultimately wastes time for both the author and the reviewer.

✅ Verified Suggestion:

> I tested updating the dependency to 2.0, and it works well with our current setup. It also brings performance improvements and new features that we can leverage.


By testing the suggestion and explicitly saying so, you provide confidence that the suggestion is reliable and won't introduce new issues.

If you are not able to test it, perhaps the best course of action is to not make the suggestion at all.

## Conclusion

Good code reviews are essential for maintaining high-quality software and fostering a collaborative development environment. By providing clear, concise, and well-tested feedback, reviewers can help authors improve their code effectively while respecting their time and effort.

It is, ultimately, a soft-skill that requires patience, empathy, and effective communication.

There are probably many other tips and best practices that can be added to this list. These, however, should give a strong initial foundation for anyone looking to improve their code review skills.
