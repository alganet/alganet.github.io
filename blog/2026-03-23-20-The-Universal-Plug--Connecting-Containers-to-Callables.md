<!--
SPDX-FileCopyrightText: 2026 Alexandre Gomes Gaigalas <alganet@gmail.com>

SPDX-License-Identifier: CC-BY-NC-SA-4.0
-->
---
alt: 2026-03-23-20-O-Plugue-Universal--Conectando-Containers-a-Callables.pt
date: March 23, 2026
author: Alexandre Gomes Gaigalas
lang: en
---

# The Universal Plug: Connecting Containers to Callables

PSR-11 solved an important problem in PHP: it gave us a **universal socket** for dependency containers. Any framework, any library, any application can expose its services through `ContainerInterface`, and any consumer can pull from it without caring about the implementation.

But there's a gap. You have a container full of services, and you have a function that needs some of them. How do you connect the two?

## The Gap

Consider a request handler:

```
function handleOrder(Mailer $mailer, Logger $logger, string $orderId) {
    $logger->info("Processing order $orderId");
    $mailer->send("Order $orderId confirmed");
}
```

Your container knows how to build a `Mailer` and a `Logger`. The function declares it needs them. But someone still has to do the wiring:

```
$mailer = $container->get(Mailer::class);
$logger = $container->get(Logger::class);
handleOrder($mailer, $logger, $orderId);
```

This works, but it's manual. You're reading the function signature with your eyes and translating it into container calls by hand. Every time the signature changes, you update the wiring. Every new handler means more glue code.

If the container is the socket, this glue code is a hand-soldered wire. It works, but it doesn't scale.

## The Plug

[Respect\Parameter](https://github.com/Respect/Parameter) is a small library that automates this connection. Give it a container and a function signature, and it figures out which parameters come from the container and which come from you.

```
use Respect\Parameter\Resolver;

$resolver = new Resolver($container);
$reflection = Resolver::reflectCallable('handleOrder');

$args = $resolver->resolve($reflection, ['ORD-42']);
handleOrder(...$args);
```

That's it. The resolver sees that `Mailer` and `Logger` are class types available in the container, pulls them automatically, and slots `'ORD-42'` into the remaining `string` parameter. The result is a named array you can spread directly into the function call.

## Named Arguments

Sometimes positional arguments aren't enough. You might want to be explicit about which parameter gets which value, especially when a function has multiple string parameters. The `resolveNamed` method handles this:

```
$args = $resolver->resolveNamed($reflection, ['orderId' => 'ORD-42']);
handleOrder(...$args);
```

Named arguments always win. If you explicitly pass `'orderId'`, the resolver uses your value. Everything else still falls through to the container and then to defaults.

## Reflecting Any Callable

PHP has many ways to express a callable: closures, array pairs, invocable objects, function names, static method strings. The `reflectCallable` static method normalizes all of them into a `ReflectionFunctionAbstract`:

```
// Closure
Resolver::reflectCallable(fn(Mailer $m) => $m->send('hi'));

// Object method
Resolver::reflectCallable([$controller, 'index']);

// Invocable object
Resolver::reflectCallable($middleware);

// Static method string
Resolver::reflectCallable('Cache::warmUp');
```

This is useful on its own, even outside parameter resolution. Any time you need to introspect a callable's signature, this saves you from writing a cascade of `instanceof` checks.

## Where This Fits

The library is intentionally minimal. It doesn't build containers, doesn't manage lifecycles, doesn't do routing. It does one thing: given a container and a callable, resolve the parameters.

This makes it a natural fit as a building block for:
- **Request dispatchers** that autowire controller actions.
- **Event systems** that resolve listener dependencies.
- **CLI runners** that inject services into command handlers.
- **Middleware pipelines** that wire dependencies into each layer.


In all these cases, the pattern is the same: you know *what* to call, the container knows *what exists*, and the resolver connects the two.

## Socket and Plug

PSR-11 standardized how to *pull* dependencies out of a container. But it left the question of how to *push* them into arbitrary callables as an exercise for the reader.

That exercise usually ends up as framework-specific autowiring logic, tightly coupled to a particular DI container or router. The same problem, solved slightly differently, in every project.

[Respect\Parameter](https://github.com/Respect/Parameter) is a small, portable answer. If `ContainerInterface` is the universal socket, then `Resolver` is the universal plug.
