<!--
SPDX-FileCopyrightText: 2026 Alexandre Gomes Gaigalas <alganet@gmail.com>

SPDX-License-Identifier: CC-BY-NC-SA-4.0
-->
---
alt: 2026-01-08-23-Um-verdadeiro-hello-world-para-LLM-pipelines.pt
date: January 8, 2026
author: Alexandre Gomes Gaigalas
lang: en
---

# A true 'hello world' LLM pipeline

For a while now, I've been searching for the simplest, *useful* LLM pipeline example. Some kind of **hello world** that beginners can quickly understand and iterate upon. 

I also want something for software engineers, not data scientists. Software engineers are a different breed, and although they need to eventually learn the machine learning fundamentals involved if they want to move forward in this area, they often prefer to start with practical, hands-on examples.

Therefore, a true 'hello world' LLM pipeline should be simple, practical, and accessible. I can't honestly ask engineers to rent a machine or spend cloud credits running a simple hello world. **There must be a better way**.

## What about X or Z?

There are many existing claims of "small" pipelines out there, but they don't qualify as true 'hello world' stuff. 

For example, [Karpathy's nanochat](https://github.com/karpathy/nanochat) claims to be very small, but that is quite relative. For someone already immersed in the industry, it is indeed very small. However, for a complete beginner, it is a huge undertaking requiring specialized hardware, money, and considerable time and effort.

To run nanochat, you need a very powerful commercial GPU. You cannot buy those (in 2025) unless you're a company. All you can do is rent them.

Karpathy himself claims you can run nanochat for $100. Would you pay $100 for a hello world?

## Hunting For Good Examples

One of the challenges of making a super 'hello world'-size LLM pipeline is that it's very difficult to generate good stuff with limited resources.

This becomes very clear when you follow some tutorial, like the popular [tiny Shakespeare](https://github.com/karpathy/char-rnn) example. The very first training checkpoints take a long time, and produce completely garbled output. They do get better, and that's the nature of this kind of work, but it's definitely not a good first impression for beginners.

To achieve a faster run-modify-understand iterable loop for educational purposes, we need to think outside the box.

## The Solution: Shrink the Generation Scope

While large LLMs generate complete text, full of sentences, we don't actually need that to understand how they work. Instead, we can focus on much smaller units of text generation, such as *a single word*.

Generating a single word is enough to exercise some important ideas:
- Tokenization: Understanding how text is broken down into tokens.
- Model Architecture: Grasping the basics of how LLMs are structured.
- Training Process: Learning how models are trained on data.
- Evaluation: Assessing model performance on a simple task.


## The wordgen Repository

With that in mind, I made **wordgen**.

The [wordgen repository](https://github.com/alganet/wordgen) contains the code and examples for this single-word, full pipeline approach.

You can run it in minutes on CPU, or even seconds if you have a decent gaming GPU.

It's as simple as this:

```
python train.py
```

Run it and you'll see the training steps, getting some words in the end:

```
...
Generating samples...
Generated word 1: coales
Generated word 2: tereed
Generated word 3: healable
Generated word 4: thines
Generated word 5: unitlerable
Generated word 6: loteroformated
Generated word 7: rearmaz
Generated word 8: Debrowing
Generated word 9: unpatates
Generated word 10: unatined
```

Most importantly, this first run doesn't generate a completely garbled Shakespeare. It instead generates plausible English-like words.

## Stuff You Can Do With It

First, you should run it as it is. It will do the whole thing from downloading the data to generating words in a matter of minutes, and you'll see the results immediately.

The next thing is probably to **play with the hyperparameters**. I could have left examples for you to try, but I believe experimentation is the best way to learn. With a pipeline that runs this fast, encouraging you to dig is better than providing canned examples.

After that, you can try **tokenizing with BPE**. This was one of the first things I did, and I almost included it as part of the repository, but I want engineers to experience the realization of how tokenization impacts model performance and output quality for themselves.

In fact, you can grow that initial approach however you like. You can introduce **safetensors**, tweak sample generation, or make the model larger. With a few tweaks, you can make it generate sentences instead of words.

## That's It

You can't really say much of a hello world. It exists now. It's there, and it's simple and fast. If you are a backend or frontend engineer wanting to dip your toes into LLMs, this is a great place to start. You can quickly grasp important concepts, then move on to more robust projects.
