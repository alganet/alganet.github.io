<!--
SPDX-FileCopyrightText: 2026 Alexandre Gomes Gaigalas <alganet@gmail.com>

SPDX-License-Identifier: CC-BY-NC-SA-4.0
-->
---
alt: 2026-01-08-23-A-true-hello-world-LLM-pipeline
date: 8 de Janeiro de 2026
author: Alexandre Gomes Gaigalas
lang: pt
---

# Um verdadeiro 'hello world' para LLM pipelines

Já faz algum tempo que venho procurando o exemplo mais simples e, ao mesmo tempo, *útil* de pipeline para LLMs. Algo como um **hello world** que iniciantes possam entender rapidamente e sobre o qual possam iterar.

Quero também algo pensado para engenheiros de software, não para cientistas de dados. Engenheiros de software são um perfil diferente e, embora eventualmente precisem aprender os fundamentos de machine learning para avançar na área, muitas vezes preferem começar por exemplos práticos e mãos na massa.

Portanto, um verdadeiro 'hello world' de pipeline para LLMs deve ser simples, prático e acessível. Honestamente, não dá pra pedir pra um engenheiro alugar uma máquina ou gastar créditos na nuvem para rodar um simples hello world. **Tem de haver um jeito melhor**.

## E quanto a X ou Z?

Existem muitos exemplos de pipelines "pequenos" por aí, mas elas não são um 'hello world' propriamente dito.

Por exemplo, [o nanochat do Karpathy](https://github.com/karpathy/nanochat) afirma ser muito pequeno, mas isso é relativo. Para alguém já imerso na indústria, de fato é bem pequeno. No entanto, para um completo iniciante, é um enorme esforço que exige hardware especializado, dinheiro e considerável tempo e dedicação.

Para rodar o nanochat é preciso uma GPU comercial muito poderosa. Em 2025 essas GPUs não são algo que você normalmente compra. Você, de fato, só pode alugá-las.

O próprio Karpathy diz que você pode rodar o nanochat por $100. Você pagaria $100 por um hello world?

## Procurando bons exemplos

Um dos desafios de criar um pipeline super 'hello world' é que é muito difícil gerar output de qualidade com recursos limitados.

Isso fica claro quando você segue algum tutorial, como o popular exemplo [tiny Shakespeare](https://github.com/karpathy/char-rnn). Os primeiros checkpoints de treinamento demoram e produzem uma saída completamente incompreensível. Eles melhoram com o tempo, e isso é esperado nesse tipo de trabalho, mas certamente não causam uma boa primeira impressão para iniciantes.

Para conseguir um ciclo de execução, modificação e entendimento mais rápido e iterável para fins educacionais, precisamos pensar fora da caixa.

## A solução: reduzir o escopo de geração

Enquanto grandes LLMs geram textos inteiros, cheios de sentenças, na verdade não precisamos disso para entender como elas funcionam. Em vez disso, podemos focar em unidades de geração bem menores, como *uma única palavra*.

Gerar uma única palavra é suficiente para exercitar ideias importantes:
- Tokenização: entender como o texto é quebrado em tokens.
- Arquitetura do modelo: captar o básico de como LLMs são estruturados.
- Processo de treinamento: aprender como modelos são treinados com dados.
- Avaliação: avaliar o desempenho do modelo em uma tarefa simples.


## O repositório wordgen

Com isso em mente, eu criei o **wordgen**.

O [repositório wordgen](https://github.com/alganet/wordgen) contém o código e exemplos para essa abordagem de pipeline completo focada em palavras únicas.

Você pode rodá-lo em minutos na CPU, ou até em segundos se tiver uma GPU de jogos decente.

É simples assim:

```
python train.py
```

Rode e você verá as etapas de treinamento, obtendo algumas palavras no final:

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

O mais importante é que essa primeira execução não produz um Shakespeare meio estranho e sem sentido. Ela gera, em vez disso, palavras parecidas com inglês plausível.

## O que você pode fazer com isso

Primeiro, você deve rodar do jeito que está. Ele fará tudo, desde baixar os dados até gerar palavras, em questão de minutos, e você verá os resultados imediatamente.

O próximo passo provavelmente é **brincar com os hiperparâmetros**. Eu poderia ter deixado exemplos prontos para você testar, mas acredito que a experimentação é a melhor forma de aprender. Com um pipeline que roda tão rápido, incentivar você a experimentar é mais valioso do que fornecer exemplos enlatados.

Depois disso, você pode tentar **tokenizar com BPE**. Foi uma das primeiras coisas que fiz, e quase incluí no repositório, mas quero que os engenheiros experimentem a descoberta de como a tokenização impacta o desempenho do modelo e a qualidade da saída por conta própria.

Na verdade, você pode expandir essa abordagem inicial como quiser. Você pode introduzir **safetensors**, ajustar a geração de samples, ou aumentar o tamanho do modelo. Com alguns ajustes, é possível fazê-lo gerar sentenças em vez de palavras.

## É isso

Não dá para dizer muito sobre um hello world. Agora ele existe. Está lá, simples e rápido. Se você é um engenheiro backend ou frontend querendo experimentar LLMs, este é um ótimo ponto de partida. Você pode rapidamente entender conceitos importantes e depois partir para projetos mais robustos.
