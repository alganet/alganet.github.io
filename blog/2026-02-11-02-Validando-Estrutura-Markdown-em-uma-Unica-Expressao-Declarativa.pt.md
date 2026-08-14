<!--
SPDX-FileCopyrightText: 2026 Alexandre Gomes Gaigalas <alganet@gmail.com>

SPDX-License-Identifier: CC-BY-NC-SA-4.0
-->
---
alt: 2026-02-11-02-Validating-Markdown-Structure-in-a-Single-Declarative-Expression
date: 11 de Fevereiro de 2026
author: Alexandre Gomes Gaigalas
lang: pt
---

# Validando Estrutura Markdown em uma Única Expressão Declarativa

Em 2010, comecei um pequeno projeto chamado [Respect\Validation](http://github.com/Respect/Validation).

À primeira vista, é uma biblioteca simpática que usa interfaces fluentes para validar valores simples:

```
// Valida que $something é um inteiro entre 1 e 10

v::intVal()->positive()->between(1, 10)->assert($something);

```

No entanto, isso é **apenas a ponta do iceberg** do que esta biblioteca é capaz de fazer.

Ao longo dos anos, a usei não só para validar coisas, mas para construir sistemas declarativos de regras inteiros, e quase nunca compartilhei esse aspecto. Até agora!

## Criando um Exemplo Incrível

Vamos validar, em uma única expressão declarativa, um documento Markdown completo.
- **Estrutura de Cabeçalhos**: Vamos verificar se um arquivo possui certos cabeçalhos esperados, na ordem e nível corretos.
- **Blocos de Código**: Vamos garantir que os blocos de código sejam código PHP válido que execute sem erro e produza alguma saída. Também validaremos cada saída produzida pelos trechos de código.


Acredito que este exemplo pode dar uma boa perspectiva sobre o poder e a flexibilidade da validação declarativa.

Como fica na prática? A estrutura geral é algo assim:

```
try {
    // Aqui está a expressão que construiremos
    $validator = v::something()->somethingElse()->somethingMore();
    // Aqui a chamamos para validar o arquivo
    $validator->assert('example.md');
} catch (ValidationException $e) {
    // Imprime uma mensagem com todos os erros encontrados no arquivo
    echo $e->getFullMessage() . "
";
}

```

Ótimo. E que tipo de mensagens podemos esperar? Quero construir algo mais ou menos assim:

```
- A estrutura Markdown deve passar por todas as regras
  - A estrutura de cabeçalhos deve passar por todas as regras
    - `.0.literal` (<- Cabeçalho na linha 1) deve ser igual a "Hello World"
    - `.1.level` (<- Cabeçalho na linha 7) deve ser igual a 2
    - `.2.literal` (<- Cabeçalho na linha 13) deve ser igual a "Examples"
  - Blocos de código devem passar por todas as regras
    - `.1` (<- Bloco de código na linha 9) deve passar nas regras
      - "sd" não é uma saída de código válida
    - `.2` (<- Bloco de código na linha 15) deve passar nas regras
      - "asd" não é uma saída de código válida

```

Portanto, há muita complexidade aqui:
- O validador não para no primeiro erro e deve continuar, eventualmente exibindo todos os erros encontrados.
- Os erros são coletados e exibidos de forma estruturada, mostrando exatamente onde cada problema ocorreu.
- Números de linha para cada elemento são incluídos para ajudar a localizar os problemas rapidamente.


## Construindo o Validador

Começaremos da ponta pro começo, descrevendo a estrutura geral e depois nos aprofundando nas regras específicas.

```
$validator = v::after(
    get_ast_children(...),
    v::allOf($headingsValidator, $codeBlocksValidator)
);

```

A função `get_ast_children(...)` analisa o arquivo Markdown e retorna os filhos da sua AST (Abstract Syntax Tree). Vamos usar o validador [v::after](https://github.com/Respect/Validation/blob/305a7d15dbc6264619f7c0a6a51d5b872ee723af/docs/validators/After.md) para validar *o resultado desse pré-processamento*. Nosso objetivo é inspecionar a árvore de sintaxe.

O `v::after()` é, na verdade, uma joia escondida. Ele brilha quando você precisa validar e produzir mensagens, mas a entrada não está exatamente no formato que você espera.

Separamos nossos dois objetivos em mais dois validadores, `$headingsValidator` e `$codeBlocksValidator`, para lidar com cada aspecto do arquivo Markdown de forma independente.

Esta é outra característica útil do Respect\Validation: **você pode compor a cadeia** combinando múltiplos validadores em uma única expressão.

## Validando os Cabeçalhos

Vamos trabalhar primeiro em `$headingsValidator`:

```
$headingsValidator = v::after(
    filter_headings(...),
    v::allOf(
        v::key(0, make_heading_validator(level: 1, text: 'Hello World')),
        v::key(1, make_heading_validator(level: 2, text: 'Description')),
        v::key(2, make_heading_validator(level: 2, text: 'Examples')),
    )
);

```

Estamos usando `v::after()` novamente! Desta vez, para filtrar a AST usando a função `filter_headings(...)`. Essa função recebe uma AST completa e retorna apenas os elementos de cabeçalho.

Além disso, estamos abraçando totalmente a composição, e usando `make_heading_validator` para criar validadores individuais para cada cabeçalho na estrutura que esperamos. A função fica assim:

```
function make_heading_validator($level, $text): Validator
{
    return v::shortCircuit(
        v::property('level', v::equals($level)),
        v::property('firstChild', v::property('literal', v::equals($text))),
    );
}

```

Isso valida duas propriedades do nó da AST. A propriedade `level` garante que o nível do cabeçalho está correto, e a propriedade `firstChild.literal` garante que o texto do cabeçalho corresponde ao valor esperado.

O validador [v::shortCircuit](https://github.com/Respect/Validation/blob/305a7d15dbc6264619f7c0a6a51d5b872ee723af/docs/validators/ShortCircuit.md) interrompe a validação assim que uma das regras falha, apenas para aquele nó na cadeia, o que pode melhorar a performance e fornecer mensagens de erro mais claras.

## Validando os Blocos de Código

Agora, vamos passar para o `$codeBlocksValidator`:

```
$codeBlocksValidator = v::after(
    filter_code_blocks(...),
    v::each(v::allOf(
        v::property('info', v::equals('php')),
        v::property('literal', v::after(
            run_and_capture_output(...),
            v::intVal()
        ))
    ))
);
```

Aqui estamos usando outro dos meus favoritos, [v::each](https://github.com/Respect/Validation/blob/305a7d15dbc6264619f7c0a6a51d5b872ee723af/docs/validators/Each.md). Ele aplica o validador fornecido a cada elemento de um array. Neste caso, garantindo que todos os nós de blocos de código da AST tenham a estrutura e o conteúdo corretos.

Também estamos usando outra função, `run_and_capture_output(...)`, para executar os blocos de código e capturar sua saída para validação.

Nosso critério para validar o resultado desses blocos é simples: queremos que cada um retorne um inteiro (verificado por `v::intVal`), mas poderíamos validar estruturas de saída mais complexas, se necessário, aninhando mais validadores.

## Primeira Olhada nas Mensagens

Então, está completo, certo? Vamos ver a saída das mensagens:

```
- `[League\CommonMark\Extension\CommonMark\Node\Block\Heading { -$level=1 #$startLine=1 #$endLine=1 +$data=Dflydev\ ... ]` deve passar por todas as regras
  - `[League\CommonMark\Extension\CommonMark\Node\Block\Heading { -$level=1 #$startLine=1 #$endLine=1 +$data=Dflydev\ ... ]` deve passar por todas as regras
    - `.0.literal` deve ser igual a "Hello World"
    - `.1.level` deve ser igual a 2
    - `.2.literal` deve ser igual a "Examples"
  - Cada item em `[League\CommonMark\Extension\CommonMark\Node\Block\FencedCode { -$info="php" -$literal="echo 123;
" -$length=3  ... ]` deve ser válido
    - `.1` deve passar nas regras
      - `.1.literal` deve ser um inteiro
    - `.2` deve passar nas regras
      - `.2.literal` deve ser um inteiro

```

Funciona até certo ponto, mas a saída é um pouco verbosa e poderia ser mais legível. O Respect\Validation tem muitos casos de uso, e não pode suportar mensagens para todo cenário possível. Em vez disso, fornecemos maneiras poderosas de modelar essas mensagens.

## Modelando a Saída das Mensagens

Primeiro, falta algo: quero as linhas reais do arquivo Markdown que geraram o erro. Podemos extrair isso da AST e incluí-las na mensagem de forma simples?

Sim podemos! Vamos melhorar a função `make_heading_validator`:

```
function make_heading_validator ($level, $text): Validator
{
    return v::factory(static fn ($heading) => v::named(
        sprintf('Cabeçalho na linha %s', $heading->getStartLine()),
        v::shortCircuit(
            v::property('level', v::equals($level)),
            v::property('firstChild', v::property('literal', v::equals($text))),
        )
    ));
}

```

Se executarmos agora, devemos ver algumas mudanças:

```
...
- `.0.literal` (<- Cabeçalho na linha 1) deve ser igual a "Hello World"
- `.1.level` (<- Cabeçalho na linha 7) deve ser igual a 2
- `.2.literal` (<- Cabeçalho na linha 13) deve ser igual a "Examples"

```

Legal! Atingimos os critérios de aceitação (mensagens granulares e estruturadas com números de linha). Ainda podemos, no entanto, ir além.

Acabamos de ver o uso do validador [v::named](https://github.com/Respect/Validation/blob/305a7d15dbc6264619f7c0a6a51d5b872ee723af/docs/validators/Named.md). Ele não é exatamente um validador, mas uma forma de renomear o nome padrão que o motor atribui automaticamente a cada regra. Neste caso, estamos usando os números de linha diretamente no nome como uma forma de referenciá-los.

Ao aplicar `v::named` e `v::templated` em nós de validadores selecionados, podemos mudar completamente como eles são apresentados e finalmente personalizar as mensagens de saída para torná-las mais significativas e legíveis:

```
- A estrutura Markdown deve passar por todas as regras
  - A estrutura de cabeçalhos deve passar por todas as regras
    - `.0.literal` (<- Cabeçalho na linha 1) deve ser igual a "Hello World"
    - `.1.level` (<- Cabeçalho na linha 7) deve ser igual a 2
    - `.2.literal` (<- Cabeçalho na linha 13) deve ser igual a "Examples"
  - Blocos de código devem passar por todas as regras
    - `.1` (<- Bloco de código na linha 9) deve passar nas regras
      - "sd" não é uma saída de código válida
    - `.2` (<- Bloco de código na linha 15) deve passar nas regras
      - "asd" não é uma saída de código válida

```

## Obtenha o Código

Confira o [código completo deste exemplo no GitHub](https://github.com/alganet/example-commonmark-respect). Preparei três arquivos no repositório:
- [rawmessages.php](https://github.com/alganet/example-commonmark-respect/blob/main/rawmessages.php) contém a versão sem formatação de mensagens.
- [expressionbuilding.php](https://github.com/alganet/example-commonmark-respect/blob/main/expressionbuilding.php) tem a construção passo a passo da expressão.
- [expressionzilla.php](https://github.com/alganet/example-commonmark-respect/blob/main/expressionzilla.php) contém a expressão inteira sem funções ou variáveis intermediárias, em uma única cadeia mega-complexa.


## Conclusão

Neste artigo, exploramos como validar a estrutura de um documento Markdown usando uma única expressão declarativa com o Respect\Validation. Vimos como modelar mensagens de erro para incluir números de linha e torná-las mais legíveis, proporcionando uma saída clara e estruturada para facilitar a depuração e a validação.

Este exemplo demonstra claramente que o Respect\Validation vai muito além da verificação de valores simples e pode realizar validações complexas em dados estruturados, produzindo mensagens de erro de qualidade que são informativas e fáceis de entender.

Acabamos de lançar o [Respect\Validation 3.0](https://github.com/Respect/Validation/releases/tag/3.0.0) na semana passada! Não deixe de conferir e explorar esses novos recursos empolgantes.
