<!--
SPDX-FileCopyrightText: 2026 Alexandre Gomes Gaigalas <alganet@gmail.com>

SPDX-License-Identifier: CC-BY-NC-SA-4.0
-->
---
alt: 2026-07-21-00-Bash-for-Browser-Frontend
date: 21 de Julho de 2026
author: Alexandre Gomes Gaigalas
lang: pt
---

# Bash para Frontend no Navegador

O título é bait. E, irritantemente, é verdade.

Se você tiver um terminal disponível, roda isso:

```
bash -c "$(curl -fsSL https://alganet.dev/terminal/index.sh)"
```

O que aparece não é uma captura de tela do site nem um dump de texto, mas o próprio site, feito navegável, de modo que as setas scrollam, o Tab percorre os links, o Enter abre um post, e a tecla `y` copia um trecho de código. Se você preferir ficar só no navegador, o mesmo programa roda ali também, seja na [versão terminal do site](/terminal/) ou pelo pequeno interruptor `$ []` ali no canto superior de cada página.

É um único script que roda nos dois lugares sem se importar muito com qual deles vai encontrar, e a stack usada é curta o bastante para explicar inteiramente.

## wasi-sh

[wasi-sh](https://github.com/alganet/wasi-sh) é o BusyBox compilado para WebAssembly: um shell POSIX de verdade, sem fork, que carrega uns cinquenta coreutils como builtins no próprio processo e roda dentro de uma aba do navegador sem servidor algum por trás. Ele consegue montar uma árvore de arquivos e mover bytes para dentro e para fora, o que é quase tudo de que um programa precisa para se sentir em casa.

## tuish

[tuish](https://github.com/alganet/tuish) é um toolkit de interface de terminal escrito em shell script portável. Ele não compila nada e não gera subprocessos, desenhando em vez disso sequências de escape ANSI diretamente, e por conta própria dá conta de eventos de teclado e mouse, decorações de caixa, truecolor, Unicode e viewports scrolláveis.

Junte os dois e um shell script vira um frontend, o que é o truque inteiro e a razão de o título ser apenas meia piada.

## Não é bash, na verdade. Mas é shell mesmo.

O shell que roda no navegador não é bash, e sim o `ash` do BusyBox, e o toolkit que faz o trabalho de verdade roda sem modificação em cinco deles:

```output
bash        4+
zsh         5+
ksh93       AJM 93u+
mksh        R59+
busybox sh  1.30+
```

Isso deixa o `bash`, a única palavra em que o título se apoia, como o shell que menos contribui. A parte que merece atenção é o shell portável embaixo da solução, que apenas por acaso chega ao seu navegador como uma build do BusyBox.

O resto fica para você descobrir, já que a fonte inteira é um único [shell script](/terminal/index.sh) que você está convidado a ler e, melhor ainda, a rodar.
