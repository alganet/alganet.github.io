<!--
SPDX-FileCopyrightText: 2026 Alexandre Gomes Gaigalas <alganet@gmail.com>

SPDX-License-Identifier: CC-BY-NC-SA-4.0
-->
---
alt: 2026-03-23-20-The-Universal-Plug--Connecting-Containers-to-Callables
date: 23 de Março de 2026
author: Alexandre Gomes Gaigalas
lang: pt
---

# O Plugue Universal: Conectando Containers a Callables

A PSR-11 resolveu um problema importante no PHP: nos deu uma **tomada universal** para containers de dependência. Qualquer framework, qualquer biblioteca, qualquer aplicação pode expor seus serviços através da `ContainerInterface`, e qualquer consumidor pode obtê-los sem se preocupar com a implementação.

Mas existe um problema. Você tem um container cheio de serviços, e tem uma função que precisa de alguns deles. Como você conecta os dois?

## O Problema

Considere um handler de requisição:

```
function handleOrder(Mailer $mailer, Logger $logger, string $orderId) {
    $logger->info("Processing order $orderId");
    $mailer->send("Order $orderId confirmed");
}
```

Seu container sabe como construir um `Mailer` e um `Logger`. A função declara que precisa deles. Mas alguém ainda tem que fazer a ligação:

```
$mailer = $container->get(Mailer::class);
$logger = $container->get(Logger::class);
handleOrder($mailer, $logger, $orderId);
```

Funciona, mas é manual. Você está lendo a assinatura da função com os olhos e traduzindo-a em chamadas ao container à mão. Cada vez que a assinatura muda, você atualiza a ligação. Cada novo handler significa mais código de cola.

Se o container é a tomada, esse código de cola é um fio soldado à mão. Funciona, mas não escala.

## O Plugue

[Respect\Parameter](https://github.com/Respect/Parameter) é uma biblioteca pequena que automatiza essa conexão. Forneça um container e uma assinatura de função, e ela descobre quais parâmetros vêm do container e quais vêm de você.

```
use Respect\Parameter\Resolver;

$resolver = new Resolver($container);
$reflection = Resolver::reflectCallable('handleOrder');

$args = $resolver->resolve($reflection, ['ORD-42']);
handleOrder(...$args);
```

Só isso. O resolver vê que `Mailer` e `Logger` são tipos de classe disponíveis no container, puxa-os automaticamente, e encaixa `'ORD-42'` no parâmetro `string` restante. O resultado é um array nomeado que você pode espalhar diretamente na chamada da função.

## Argumentos Nomeados

Às vezes argumentos posicionais não são suficientes. Você pode querer ser explícito sobre qual parâmetro recebe qual valor, especialmente quando uma função tem múltiplos parâmetros string. O método `resolveNamed` cuida disso:

```
$args = $resolver->resolveNamed($reflection, ['orderId' => 'ORD-42']);
handleOrder(...$args);
```

Argumentos nomeados sempre vencem. Se você passa explicitamente `'orderId'`, o resolver usa seu valor. Todo o resto ainda cai para o container e depois para os valores padrão.

## Refletindo Qualquer Callable

O PHP tem muitas formas de expressar um callable: closures, pares de array, objetos invocáveis, nomes de função, strings de método estático. O método estático `reflectCallable` normaliza todas elas em um `ReflectionFunctionAbstract`:

```
// Closure
Resolver::reflectCallable(fn(Mailer $m) => $m->send('hi'));

// Método de objeto
Resolver::reflectCallable([$controller, 'index']);

// Objeto invocável
Resolver::reflectCallable($middleware);

// String de método estático
Resolver::reflectCallable('Cache::warmUp');
```

Isso é útil por si só, mesmo fora da resolução de parâmetros. Sempre que você precisa introspectar a assinatura de um callable, isso evita escrever uma cascata de verificações `instanceof`.

## Onde Isso Se Encaixa

A biblioteca é intencionalmente mínima. Ela não constrói containers, não gerencia ciclos de vida, não faz roteamento. Ela faz uma coisa: dado um container e um callable, resolve os parâmetros.

Isso a torna uma peça natural como bloco de construção para:
- **Dispatchers de requisição** que fazem autowiring de ações de controllers.
- **Sistemas de eventos** que resolvem dependências de listeners.
- **Runners de CLI** que injetam serviços em handlers de comando.
- **Pipelines de middleware** que conectam dependências em cada camada.


Em todos esses casos, o padrão é o mesmo: você sabe *o que* chamar, o container sabe *o que existe*, e o resolver conecta os dois.

## Tomada e Plugue

A PSR-11 padronizou como *puxar* dependências de um container. Mas deixou a questão de como *empurrá-las* para callables arbitrários como exercício para o leitor.

Esse exercício geralmente acaba como lógica de autowiring específica do framework, fortemente acoplada a um container de DI ou router particular. O mesmo problema, resolvido de forma ligeiramente diferente, em cada projeto.

[Respect\Parameter](https://github.com/Respect/Parameter) é uma resposta pequena e portátil. Se a `ContainerInterface` é a tomada universal, então o `Resolver` é o plugue universal.
