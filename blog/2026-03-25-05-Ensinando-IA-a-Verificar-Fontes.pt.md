<!--
SPDX-FileCopyrightText: 2026 Alexandre Gomes Gaigalas <alganet@gmail.com>

SPDX-License-Identifier: CC-BY-NC-SA-4.0
-->
---
alt: 2026-03-25-05-Teaching-AI-to-Verify-Sources
date: 25 de Março de 2026
author: Alexandre Gomes Gaigalas
lang: pt
---

# Ensinando IA a Verificar Suas Fontes

LLMs citam documentação que não existe com total confiança.

“De acordo com o MDN, `Promise.allSettled()` retorna uma promise que resolve quando todas as promises são completadas (*“returns a promise that resolves when all promises have completed”*).”

Isso *parece* correto. Mas o MDN na verdade diz *“fulfills when all of the input's promises settle”* (“cumpre quando todas as promises da entrada se estabelecem”). Verbo diferente, semântica diferente. Um humano pode não perceber isso. Mas uma ferramenta pode.

Este post mostra como fazer uma IA verificar suas próprias afirmações antes de escrevê-las, usando [apysource](https://github.com/alganet/apysource) e um simples arquivo de instruções.

Uma demonstração funcional deste fluxo de trabalho está em [alganet/ecmascript-featurecard](https://github.com/alganet/ecmascript-featurecard).

## O Arquivo de Instruções

A maioria dos agentes de código suporta arquivos de instruções em nível de projeto: um arquivo markdown na raiz do repositório que o agente lê antes de começar o trabalho. Coloque isto no seu:

```
# Verificação de Fontes

Ao escrever documentação que referencia fontes externas, prefira
citações diretas em vez de paráfrases. Toda afirmação factual sobre o
que uma fonte diz deve ser respaldada por um trecho exato dessa fonte.

1. Antes de afirmar "X diz Y", verifique a citação:
       apysource locate "<url>" "<citação exata>"
   Se o trecho não for encontrado, não faça a afirmação.

2. Após verificar, registre a afirmação:
       apysource add sources.yaml "<url>" "<citação exata>" --label "<nome da afirmação>"

3. Após toda a documentação ser escrita, execute a verificação completa:
       apysource check sources.yaml
   Todas as verificações devem passar antes de considerar a tarefa concluída.
```

Pense nisso como um `[citação necessária]` automatizado, do tipo que editores da Wikipédia colocam em afirmações sem fonte, exceto que aqui o agente é tanto o escritor quanto o verificador, e a tag é aplicada antes do texto ser commitado.

Essa é toda a integração. O agente lê este arquivo, ganha acesso a três comandos shell, e segue o fluxo: **locate -> add -> check**.

## O Caminho Feliz

Um usuário pede ao agente para adicionar `Array.findLast()` ao cartão de referência.

O agente primeiro verifica uma citação da página do MDN:

```
$ apysource locate \
    "https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/findLast" \
    "iterates the array in reverse order"
```

```
# Found in: https://developer.mozilla.org/en-US/docs/.../Array/findLast
# Targetter: section

- label: ''
  section: Array.prototype.findLast(), paragraph 2
  snippet: iterates the array in reverse order
```

O trecho existe. O agente o registra:

```
$ apysource add sources.yaml \
    "https://developer.mozilla.org/.../Array/findLast" \
    "iterates the array in reverse order" \
    --label "Array.findLast() iteration"
```

```output
  Located: section -> Array.prototype.findLast(), paragraph 2
  Added new source: https://developer.mozilla.org/.../Array/findLast
  Added fragment "Array.findLast() iteration" to sources.yaml
```

Então executa a verificação completa:

```
$ apysource check sources.yaml
```

```output
  [PASS] Fragments: cache resolution............. 8/8
  [PASS] Fragments: content extraction........... 8/8
  [PASS] Fragments: snippet verified............. 8/8
```

Todos os 8 fragmentos (os 7 originais mais o novo) passam. O agente prossegue para regenerar o cartão de referência com `python generate.py`.

## A Alucinação

Agora o agente tenta uma citação diferente, uma que ele *acha* que o MDN diz:

```
$ apysource locate \
    "https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/findLast" \
    "returns the first matching element from the end of the array"
```

```output
Error: snippet not found in https://developer.mozilla.org/.../Array/findLast
```

Código de saída 1. A instrução é clara: *“Se o trecho não for encontrado, não faça a afirmação.”*

O agente não escreve a citação alucinada. Em vez disso, volta ao `locate` com uma frase mais curta, encontra o que o MDN realmente diz, e usa isso.

Isso não é correção após o fato. O agente nunca escreveu a afirmação errada. A verificação aconteceu *antes* da documentação ser produzida.

## CI como Mecanismo de Segurança

Mesmo com o arquivo de instruções, agentes cometem erros. O pipeline de CI é o portão final:

```
# .github/workflows/verify-sources.yml
name: Verify Sources
on: [push, pull_request]
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: pip install apysource
      - run: apysource check sources.yaml
```

Se qualquer citação divergir, seja porque o agente a introduziu ou porque o MDN mudou a página, o build falha. O manifesto `sources.yaml` é o contrato entre a documentação e suas fontes.

## Considerações Finais

Sem verificação de fontes, documentação gerada por IA é um passivo. Você não consegue distinguir citações precisas de alucinações sem verificar manualmente cada link.

Com apysource no fluxo, o agente se torna um autor de documentação *verificado*. Cada afirmação é fundamentada. Cada citação é checada. O grafo de proveninência registra quando foi verificado e qual foi o resultado.

O arquivo `sources.yaml` é uma bibliografia legível por máquina. Ele pode gerar cartões de referência, alimentar dashboards, ou servir como trilha de auditoria.
