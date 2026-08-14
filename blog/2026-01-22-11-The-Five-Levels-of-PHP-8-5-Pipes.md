<!--
SPDX-FileCopyrightText: 2026 Alexandre Gomes Gaigalas <alganet@gmail.com>

SPDX-License-Identifier: CC-BY-NC-SA-4.0
-->
---
alt: 2026-01-22-11-Os-Cinco-Niveis-de-Pipes-no-PHP-8-5.pt
date: January 22, 2026
author: Alexandre Gomes Gaigalas
lang: en
---

# The Five Levels of PHP 8.5 Pipes

![An illustrative image of a production pipeline](/images/production-pipeline.png)

[PHP's pipe operator](https://www.php.net/pipe) unlocks a very readable, functional style. Below I walk through five conceptual "levels" of using pipes: from the simple production line to composed functor objects.

You can use these as templates that you can extend upon in your own projects.

## Level 1: The Production Line

Each step transforms the value in sequence, like a factory conveyor belt.

```
$input = '   pipes & fun   ';
$output = $input
    |> html_entity_decode(...)
    |> ucwords(...)
    |> trim(...);

var_dump($output); // string(11) "Pipes & Fun"

```

## Level 2: Closure Wrappers

Wrap operations in closures so you can parameterize behavior and reuse steps.

```
function add(int $x): Closure {
    return static fn (int $v): int => $v + $x;
}
function multiply(int $x): Closure {
    return static fn (int $v): int => $v * $x;
}

$input = 42;
$output = $input
    |> add(5)
    |> multiply(2);

var_dump($output); // int(94)

```

## Level 3: Closure Composition

Compose steps into a pipeline and run it later against inputs.

This technique allows you to put the input *last* and compose the steps first, which opens opportunities for reusability.

```
function with(Closure $step): Closure {
    return static fn (Closure $acc): Closure => static fn ($v) => $step($acc($v));
}

function run($input): Closure {
    return static fn (Closure $pipeline) => $pipeline($input);
}

function begin(): Closure {
    return static fn ($v) => $v;
}

$input = 42;
$output = begin()
    |> with(add(10))
    |> with(multiply(2))
    |> run($input);

var_dump($output); // int(104)

```

## Level 4: Generators as Pipelines

Generators let you define flexible steps, collect messages, or short-circuit validations.

```
function stream(): Generator {
    yield from [];
}

function check(Closure $fn, string $message): Closure {
    return static fn (Generator $it): Generator => yield from [
        ...$it,
        static fn ($v) => $fn($v) ? null : $message
    ];
}

function collect(): Closure {
    return static fn (Generator $it): Closure => static function ($v) use ($it) {
        $messages = [];
        foreach ($it as $fn) {
            $m = $fn($v);
            if ($m !== null) {
                $messages[] = $m;
            }
        }
        return (static fn () => yield from $messages)();
    };
}

```

This version not only allows you to set the input last, but also obtain a stream of responses from the pipeline.

```
$input = -3.14;
$output = stream()
    |> check(is_int(...), 'must be an integer')
    |> check(fn ($v) => $v > 0, 'must be positive')
    |> collect();

foreach ($output($input) as $message) {
    var_dump($message);
}

```

## Level 5: Functor Objects (OOP + Functional)

Wrap behavior in objects with `__invoke` for a smooth composer-friendly API.

```
class Check
{
    public function __construct(
        private Closure $fn,
        private string $message,
    ) {}

    public function __invoke(Generator $it): Generator
    {
        yield from [
            ...$it,
            fn ($v) => ($this->fn)($v) ? null : $this->message
        ];
    }
}

```

PHP is great for combining OOP and functional programming. The class we defined here is simple, however, you can go as far as you like with inheritance, interfaces, and traits to build a rich library of reusable pipeline components. 

```
$input = ['arr'];
$output = stream()
    |> new Check(is_int(...), 'must be an integer')
    |> new Check(is_scalar(...), 'must be scalar')
    |> collect();

foreach ($output($input) as $message) {
    var_dump($message);
}

```

## Bonus: Static Helpers for Syntactic Sugar

Use magic to make the API feel like static function calls.

```
class Func extends Check
{
    public static function __callStatic(string $name, array $arguments): static
    {
        return new static($name(...), ...$arguments);
    }
}

$input = ['arr'];
$output = stream()
    |> Func::is_int('must be an integer')
    |> Func::is_scalar('must be scalar')
    |> collect();

foreach ($output($input) as $message) {
    var_dump($message);
}

```

With every new PHP feature, there's a great opportunity to make simpler APIs that are more expressive and reusable. The pipe operator is a great example of that, enabling a functional style that integrates well with OOP. Enjoy experimenting with these levels of pipes in your own projects! 
