<!--
SPDX-FileCopyrightText: 2026 Alexandre Gomes Gaigalas <alganet@gmail.com>

SPDX-License-Identifier: CC-BY-NC-SA-4.0
-->
---
alt: 2026-03-12-20-Feng-Shui-Refactoring
date: 12 de Março de 2026
author: Alexandre Gomes Gaigalas
lang: pt
---

# Refatoração Feng Shui

Se você já trabalhou em uma base de código grande por tempo suficiente, provavelmente já viu um certo tipo de refatoração que *parece* produtiva mas não melhora o sistema de verdade.

Alguns arquivos são renomeados, funções mudam de lugar, diretórios e namespaces são reorganizados, mas **nada muda**.

O diff é grande, a estrutura parece diferente, e a descrição do pull request diz algo como "limpar estrutura do projeto". Muitas coisas mudam, mas a legibilidade não melhorou de verdade e o comportamento continua o mesmo.

## Como Identificar

Um refactoring feng shui reorganiza código sem melhorar sua estrutura. O sistema parece diferente, mas se comporta da mesma forma e continua igualmente difícil de entender.

Um exemplo comum é **renomear sem esclarecer comportamento**.

Antes:

```
def handle(x):
    return process(x)
```

Depois:

```
def process_event(event):
    return process(event)
```

Os nomes soam melhor, mas o problema de design não mudou: a função ainda esconde o que realmente faz. Nomes específicos como "handle", "manage", "orchestrate" e namespaces como "common" e "utils" frequentemente funcionam como ímãs para esse tipo de pseudo-refatoração.

Outro exemplo é **mover código sem mudar dependências**.

Antes:

```
services/
    billing.py
    notifications.py
```

Depois:

```
domain/
    billing_service.py
    notification_service.py
```

Se ambos os módulos ainda importam metade da aplicação e se chamam mutuamente de formas complexas, a arquitetura não melhorou. Os móveis apenas mudaram de lugar.

## Por Que Isso Acontece

Esse tipo de mudança é atraente porque transmite a *intenção de melhoria*. Você pode pensar que nomes melhores vão fomentar melhor modularização depois, ou que dividir algo sem desemaranhar as dependências vai levar a mais modularização no futuro.

Refatoração de verdade requer entender o sistema bem o suficiente para identificar problemas estruturais. Isso normalmente significa ler código, rastrear comportamento e formar um modelo mental **antes** de mexer em qualquer coisa.

## Boas Renomeações

As refatorações mais úteis tendem a remover algo: duplicação, acoplamento oculto, indireção desnecessária.

Às vezes, renomear *pode de fato ser útil*, como esclarecer uma regra de negócio enterrada.

Antes:

```
def process(order):
    if order.total > 100:
        order.discount = order.total * 0.1
```

Depois:

```
def apply_loyalty_discount(order):
    if order.total > 100:
        order.discount = order.total * 0.1
```

Curiosamente, esse tipo de refatoração costuma produzir diffs *menores* do que grandes reorganizações.

## Como É uma Refatoração de Verdade

Refatoração de verdade tende a simplificar como o sistema funciona, não como ele é organizado.

Um bom exemplo é **remover conhecimento hard-coded** que se espalha silenciosamente pelo sistema.

Antes:

```
def shipping_cost(order):
    if order.country == "US":
        return 5
    return 15
```

Depois:

```
SHIPPING_RATES = {
    "US": 5,
    "INTL": 15,
}

def shipping_cost(order):
    region = "US" if order.country == "US" else "INTL"
    return SHIPPING_RATES[region]
```

O comportamento não mudou, mas a regra agora é visível e centralizada em vez de enterrada dentro de um condicional. Quando os preços inevitavelmente mudarem, há um lugar claro para atualizá-los.

Esse tipo de mudança raramente produz diffs dramáticos. Frequentemente envolve deletar código, colapsar camadas ou tornar relações mais explícitas.

Mas elas reduzem continuamente a quantidade de trabalho necessária para entender e modificar o sistema.

## Uma Pequena Pergunta

Antes de começar uma refatoração, pode ajudar fazer uma pergunta simples:

Que problema concreto essa mudança vai resolver?

Às vezes a resposta é clara: lógica duplicada desaparece, uma dependência circular é quebrada, ou um conceito de domínio se torna explícito.

Outras vezes a resposta é mais difícil de articular. A mudança afeta principalmente como o código *parece*.

## Reorganizando o Quarto

Às vezes mover coisas de lugar *de fato melhora*, mas sem um propósito claro, é um sinal de alerta. Se você não consegue explicar qual problema a mudança resolve, pode ser apenas mais um desses refactorings feng shui.
