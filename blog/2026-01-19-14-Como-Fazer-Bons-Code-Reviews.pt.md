<!--
SPDX-FileCopyrightText: 2026 Alexandre Gomes Gaigalas <alganet@gmail.com>

SPDX-License-Identifier: CC-BY-NC-SA-4.0
-->
---
alt: 2026-01-19-14-How-To-Make-Good-Code-Reviews
date: 19 de Janeiro de 2026
author: Alexandre Gomes Gaigalas
lang: pt
---

# Como Fazer Bons Code Reviews

**Bons code reviews são uma arte.** Leva anos, e às vezes décadas, para aprender a fazer direito.

A coisa mais importante, nossa *diretiva principal*, é ser **gentil e construtivo.** Habilidades interpessoais são um dos ingredientes-chave para sustentar uma boa prática de revisão de código ao longo do tempo.

Os outros ingredientes são conhecimento técnico e atenção aos detalhes.

A seguir estão algumas das dicas mais importantes que englobam esses princípios:

## Não Reclame, Ensine

Ao encontrar um problema, em vez de apenas apontar o erro, proponha uma solução e explique por que ela é melhor.

Vamos usar esta mudança de código como exemplo:

```diff
- function ($foo, $bar = null);
+ function ($foo, $bar = null, $baz);

```

❌ Review não construtivo:

> Isso está errado porque adiciona um novo parâmetro sem valor padrão.


Esse tipo de review aponta um problema, mas não oferece orientação sobre como corrigir. Ou assume que o autor sabe como resolver, mas não quis, ou presume que o autor não sabe e o deixa sem direção.

✅ Momento de aprendizado:

> Adicionar um novo parâmetro sem valor padrão pode quebrar chamadas existentes para essa função.
>
> Você deve fornecer um valor padrão para o novo parâmetro ou atualizar todas as chamadas existentes para incluir o novo argumento.


Esse tipo de review não apenas aponta o problema, como também fornece uma orientação clara de como resolvê-lo, facilitando para o autor entender e aplicar as mudanças necessárias.

## Saiba Quando Você Está Fazendo Nitpicking

*Nitpicking* é apontar problemas pequenos que não impactam de forma relevante a funcionalidade, a legibilidade ou a manutenibilidade do código. Atenção aos detalhes é importante, mas nitpicking em excesso gera frustração e desmotivação para quem escreveu a mudança.

Vamos usar esta mudança de código como exemplo:

```diff
+ $firstPiece = 'square';
+ $middlePiece = 'circle';
+ $lastPiece = 'triangle';

```

❌ Nitpicking excessivo:

> Use `$intermediatePiece` em vez de `$middlePiece`.


Embora essa sugestão seja válida, ela pode não ser significativa a ponto de justificar uma alteração. O nome original da variável ainda é claro e compreensível.

Nitpicks frequentemente se resumem a preferências pessoais que não cabem (ou não valem) ser formalizadas em checks automáticos ou em um guia de estilo. É, no fim, sobre a preferência do revisor.

Se essas preferências acabam desacelerando o processo de revisão ou frustrando autores, a revisão deixa de ser útil e passa a ser um ponto de atrito.

✅ Sugestão amigável:

> Nitpick: eu prefiro `$intermediatePiece` em vez de `$middlePiece`.


Ao enquadrar a sugestão como preferência pessoal, e não como uma regra rígida, você mantém um tom positivo e colaborativo. Nitpicks não devem bloquear um code review e, por padrão, deveriam ser opcionais (o autor pode optar por não aplicar a mudança sugerida).

## Use Referências

Links, números de linha e referências de documentação ajudam a dar contexto e embasar seu feedback.

Vamos usar esta mudança de código como exemplo:

```diff
+ if (isValid($input)) {
+     process($input);
+ } else {
+     error_log('Invalid input');
+ }

```

❌ Feedback vago:

> Nossas diretrizes exigem `ErrorLog::create` em vez de `error_log`.


Esse feedback carece de contexto e não fornece uma referência clara à diretriz específica que está sendo violada.

✅ Feedback com referência:

> De acordo com nossos *padrões de codificação*, devemos usar `ErrorLog::create` em vez de `error_log` para maior consistência e manutenibilidade (veja a linha 42).


Esse feedback aponta a diretriz relevante e explica o motivo da sugestão.

## Não Seja Repetitivo

Às vezes, a mesma sugestão se aplica a várias partes do mesmo pull request (PR). Em vez de repetir o mesmo feedback diversas vezes, considere resumir uma única vez e referenciar onde for aplicável.

Considere esta série de mudanças:

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

❌ Feedback repetitivo:

> Em `functionA`, use parâmetros nomeados para melhor legibilidade.


> Em `functionB`, use parâmetros nomeados para melhor legibilidade.


> Em `functionC`, use parâmetros nomeados para melhor legibilidade.


Feedback repetitivo cria ruído e faz o autor sentir que está sendo soterrado pela mesma sugestão várias vezes.

Também pode ser interpretado como o revisor não tendo dedicado tempo para olhar o PR como um todo, o que indica um processo de revisão ruim: copiar e colar comentários, em vez de ser mais cuidadoso e intencional.

✅ Feedback consolidado:

> Para melhor legibilidade, considere usar parâmetros nomeados em `functionA`. O mesmo vale para `functionB` (arquivo: stores.php) e `functionC` (arquivo: houses.php).


Consolidar o feedback em um único ponto, a partir de uma das ocorrências, costuma ser bem mais eficaz e respeitoso com o tempo do autor.

## Não Chute: Tenha Certeza de que Funciona

Não há nada mais frustrante do que receber uma sugestão que, na prática, não funciona ou que introduz novos problemas.

Vamos usar esta mudança de código como exemplo:

```diff
+ "image-reader-dependency": 1.0

```

❌ Sugestão no chute:

> Você pode simplesmente trocar para 2.0, que é mais recente!


Nesse cenário, o revisor sugeriu 2.0 sem validar se realmente funciona. Isso pode quebrar builds ou causar comportamentos inesperados, o que no fim desperdiça tempo tanto do autor quanto do revisor.

✅ Sugestão verificada:

> Testei atualizar a dependência para 2.0, e funciona bem com nosso setup atual. Além disso, traz melhorias de performance e novas funcionalidades que podemos aproveitar.


Ao testar a sugestão e dizer isso explicitamente, você transmite confiança de que o conselho é confiável e não vai introduzir novos problemas.

Se você não consegue testar, talvez a melhor decisão seja simplesmente não fazer a sugestão.

## Conclusão

Bons code reviews são essenciais para manter software de alta qualidade e promover um ambiente colaborativo de desenvolvimento. Ao oferecer feedback claro, conciso e bem testado, revisores ajudam autores a melhorar o código de forma eficaz, respeitando tempo e esforço.

No fim, é uma habilidade interpessoal que exige paciência, empatia e comunicação efetiva.

Provavelmente existem muitas outras dicas e boas práticas que poderiam entrar nessa lista. Estas, no entanto, fornecem uma base inicial sólida para quem quer evoluir sua capacidade de fazer code reviews.
