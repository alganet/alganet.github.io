<!--
SPDX-FileCopyrightText: 2026 Alexandre Gomes Gaigalas <alganet@gmail.com>

SPDX-License-Identifier: CC-BY-NC-SA-4.0
-->
---
alt: 2026-06-28-12-POSIX-Is-Not-A-Shell
date: 28 de Junho de 2026
author: Alexandre Gomes Gaigalas
lang: pt
---

# POSIX Não É Um Shell

Quando alguém diz "escreva em shell POSIX para garantir portabilidade", a intenção é boa.

POSIX é uma especificação. Não um programa. O que de fato executa o seu script é o bash, o dash, o ash, o ksh, o yash, ou um entre uma dúzia de outros. Cada um implementa o POSIX com suas próprias lacunas, extensões e acidentes históricos.

Aqui vai um pequeno experimento. Uma linha, sem flags, sem funções, nada de exótico:

```
#!/bin/sh
echo "C:\new"
```

No bash, no ksh e em alguns outros, você recebe de volta exatamente o que digitou:

```output
C:\new
```

No dash (que *é* o `/bin/sh` no Debian, no Ubuntu e no Alpine) a mesma linha imprime:

```output
C:
ew
```

O `echo` do dash interpreta `\n` como uma quebra de linha. O do bash não. Rode isso em todos os [shell-versions](https://github.com/alganet/shell-versions) e os shells se dividem quase pela metade: cerca de metade trata a barra invertida de forma literal, a outra metade a expande.

```
docker run --rm alganet/shell-versions:all -c 'echo "C:\new"'
```

O POSIX não desempata. O padrão explicitamente deixa o [tratamento que o `echo` dá às sequências de escape com barra invertida como **definido pela implementação**](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/echo.html#tag_20_37_05), e [recomenda que você use `printf` no lugar](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/echo.html#tag_20_37_16). Então "o `echo` POSIX" não é um comportamento contra o qual você possa escrever um script. É uma divergência documentada.

Este não é um caso extremo forçado. O `echo` é o primeiro comando que qualquer um aprende. É o que "compatível com POSIX" significa na prática: compatível com as partes que a especificação de fato fixa, nas versões que por acaso vieram instaladas.

## O Problema Com Dialetos

Línguas naturais têm dialetos. O português brasileiro e o português europeu são ambos português. Um falante nativo de um entende o outro com algum esforço, mas não são a mesma coisa. Você não pode escrever em português e esperar que funcione de forma idêntica em todo lugar.

O scripting de shell tem o mesmo problema. O bash não é *o* shell. É *um* shell com um conjunto específico de comportamentos, muitos dos quais não estão no POSIX e alguns dos quais contradizem implementações que são tecnicamente mais compatíveis (como o dash).

A comunidade finge o contrário. Dizemos "script sh" e queremos dizer "bash com `-e -u -o pipefail`". Dizemos "compatível com POSIX" e queremos dizer "funcionou na CI". Dizemos "portável" e queremos dizer "rodou nas duas máquinas que testei".

## Como É a Validação na Prática

Venho construindo o [shell-docs](https://github.com/alganet/shell-docs), uma referência multi-shell que valida cada recurso documentado em 14 shells. O processo é mecânico: escreva um exemplo, rode em cada shell, registre a saída, verifique se há divergência.

A maioria dos recursos funciona igual. Alguns não.

`$#` - a contagem de parâmetros posicionais. Funciona em todo lugar, sem surpresas.

`local` - não está no POSIX de jeito nenhum. Todo shell tem assim mesmo, com regras de escopo diferentes.

`$(( ))` - [expansão aritmética](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html#tag_18_06_04), suportada universalmente. Divisão por zero: varia conforme a implementação.

`[[ ]]` - não é POSIX, não existe no dash. Se o seu script usa isso sob `#!/bin/sh`, ele vai falhar silenciosamente em todo sistema onde o `/bin/sh` é o dash (Debian, Ubuntu, Alpine).

Os que divergem não são bugs. São decisões acumuladas por décadas de implementações independentes, cada uma mirando um ponto ligeiramente diferente na história da especificação: 1988, 2001, 2017.

## A Versão Honesta de "Portável"

Portável significa: testado na variedade de shells em que ele vai de fato rodar.

A ferramenta [shell-versions](https://github.com/alganet/shell-versions) rastreia qual versão de cada shell vem com as principais distribuições. No momento em que escrevo, o `/bin/sh` é:
- `dash 0.5.12` no Ubuntu 24.04
- `bash 3.2.57` no macOS (inalterado há quinze anos; a GPL v3 manteve o bash 4.x fora do sistema base)
- `busybox ash` no Alpine
- `ksh93` em algumas distribuições Linux corporativas


Não são o mesmo programa. Não têm nem a mesma idade.

Se você escreve `#!/bin/bash` e fala sério, tudo bem. Pelo menos é honesto. Escreva `#!/bin/sh` e você está prometendo algo que deveria verificar.

## Verificação É Um Hábito

O harness de validação do shell-docs roda cada exemplo contra todos os 14 shells isoladamente, captura a saída padrão e os códigos de saída, e os compara com uma tabela de referência conhecida. Quando uma nova versão de um shell é lançada, você roda de novo.

Isso não é complexo. É só um trabalho que não acontece por padrão.

A recompensa é que "funciona no sh POSIX" pode significar algo concreto: funciona nos catorze shells que testei, e aqui estão os resultados. Essa é uma afirmação diferente de "rodei no bash e pareceu funcionar".

POSIX não é um shell. É uma promessa sobre o que os shells deveriam fazer. A verificação é como você descobre quais delas foram cumpridas.
