<!--
SPDX-FileCopyrightText: 2026 Alexandre Gomes Gaigalas <alganet@gmail.com>

SPDX-License-Identifier: CC-BY-NC-SA-4.0
-->
---
alt: 2026-01-22-11-The-Five-Levels-of-PHP-8-5-Pipes
date: 22 de Janeiro de 2026
author: Alexandre Gomes Gaigalas
lang: pt
---

# Os Cinco Níveis de Pipes no PHP 8.5

![Uma imagem ilustrativa de uma linha de produção](/images/production-pipeline.png)

[O operador pipe do PHP](https://www.php.net/pipe) possibilita um estilo funcional muito legível. Abaixo descrevo cinco "níveis" conceituais de uso de pipes: da simples "linha de produção" até functors compostos.

Você pode usar estes exemplos como modelos e estendê-los em seus próprios projetos.

## Nível 1: Linha de Produção

Cada etapa transforma o valor em uma sequência, como uma esteira de fábrica.

```
$input = '   pipes & fun   ';
$output = $input
    |> html_entity_decode(...)
    |> ucwords(...)
    |> trim(...);

var_dump($output); // string(11) "Pipes & Fun"

```

## Nível 2: Wrappers com Closures

Encapsule operações em closures para parametrizar comportamentos e reutilizar etapas.

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

## Nível 3: Composição de Closures

Componha etapas em um pipeline e execute-o depois com entradas.

Essa técnica permite colocar a entrada *por último* e compor as etapas primeiro, o que abre oportunidades para reutilização.

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

## Nível 4: Geradores como Pipelines

Geradores permitem definir etapas flexíveis, coletar mensagens ou interromper validações prematuramente.

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

Essa versão não só permite colocar a entrada por último, como também obter uma sequência (stream) de respostas do pipeline.

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

## Nível 5: Objetos Functor (OOP + Funcional)

Encapsule comportamentos em objetos com `__invoke` para uma API fácil de compor.

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

O PHP é ótimo para combinar POO e programação funcional. A classe definida aqui é simples, mas você pode ir tão longe quanto quiser com herança, interfaces e traits para construir uma rica biblioteca de componentes reutilizáveis para pipelines.

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

## Bônus: Helpers Estáticos para Sintaxe

Use métodos mágicos para fazer a API parecer chamadas de função estáticas.

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

Com cada novo recurso do PHP, há uma grande oportunidade para criar APIs mais simples, expressivas e reutilizáveis. O operador pipe é um ótimo exemplo disso, permitindo um estilo funcional que se integra bem com POO. Divirta-se experimentando esses níveis de pipes em seus próprios projetos!
