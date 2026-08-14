<!--
SPDX-FileCopyrightText: 2025 Alexandre Gomes Gaigalas <alganet@gmail.com>

SPDX-License-Identifier: CC-BY-NC-SA-4.0
-->
---
alt: 2025-12-17-07-Polyglot-Makefiles
date: 17 de Dezembro de 2025
author: Alexandre Gomes Gaigalas
lang: pt
---

# Makefiles Poliglotas

 Enquanto sistemas do tipo Unix normalmente usam **GNU make**, ambientes Windows baseados nas ferramentas da Microsoft tradicionalmente usam o **nmake**. Embora existam alternativas como o GNU make no Windows (MSYS2, MinGW, WSL), muitos projetos ainda precisam suportar fluxos de trabalho nativos com o **nmake**. 

 Infelizmente, o GNU make e o nmake são ferramentas semelhantes com **sintaxe e recursos diferentes**. Isso geralmente leva a makefiles duplicados ou força os contribuidores a instalar uma ferramenta não nativa. Aqui exploramos uma técnica para criar um único `Makefile` que funciona para ambos. 

## Por que isso é útil
- **Uma única fonte da verdade:** Variáveis comuns, *targets* e documentação vivem em um único `Makefile`. 
- **Delegação de plataforma:** Regras específicas de ferramentas ou plataformas vivem em arquivos de inclusão pequenos e focados.
- **Complexidade controlada:** A lógica poliglota é isolada em um bloco minúsculo e bem documentado. 


## A parte principal

A solução poliglota para o `Makefile` unificado é mais ou menos assim:

```
SHARED_VAR = some_value

shared_target:
	echo 123

# --- COMEÇO DA MÁGICA POLIGLOTA
# \
!ifndef 0 # \
!include "nmake-specific.mk" # \
!else
include gnu-specific.mk
# \
!endif
# --- FIM DA MÁGICA POLIGLOTA
```

 Este bloco permite que cada ferramenta inclua seu próprio arquivo de implementação, compartilhando as mesmas variáveis e *targets*. 

## Como funciona

Este trecho baseia-se em diferenças sutis, mas bem definidas, entre as regras de processamento do GNU make e do nmake.

**O que o GNU make vê:**

 O GNU make suporta continuação de linha (`\`) dentro de comentários. Por causa disso, as diretivas nmake prefixadas com `!` tornam-se parte de um comentário de várias linhas e são ignoradas. 

```
# --- COMEÇO DA MÁGICA POLIGLOTA
# \
!ifndef 0 # \
!include "nmake-specific.mk" # \
!else
include gnu-specific.mk
# \
!endif
# --- FIM DA MÁGICA POLIGLOTA
```

**O que o nmake vê:**

 O nmake não suporta comentários de várias linhas. Ele reconhece as diretivas `!ifndef`, `!include`, `!else` e `!endif` e avalia o primeiro ramo. 

 A condição `!ifndef 0` é escolhida intencionalmente: `0` não é uma macro predefinida no nmake, então a condição é sempre verdadeira. Isso seleciona de forma confiável o ramo específico do nmake sem depender de variáveis de ambiente. 

```
# --- COMEÇO DA MÁGICA POLIGLOTA
# \
!ifndef 0 # \
!include "nmake-specific.mk" # \
!else
include gnu-specific.mk
# \
!endif
# --- FIM DA MÁGICA POLIGLOTA
```

## Layout típico de arquivos

```
Makefile
gnu-specific.mk
nmake-specific.mk
```

## Ressalvas e limitações
- Isso depende da forma como o GNU make lida com a continuação de linha dentro de comentários.
- O bloco poliglota deve permanecer pequeno e contido.
- Editores ou formatadores que alteram barras invertidas finais podem quebrar silenciosamente essa construção. 


## Considerações finais

 Makefiles Poliglotas são uma técnica poderosa quando usada com moderação. Eles permitem uma única definição de build compartilhada, preservando os fluxos de trabalho nativos em cada plataforma. 

Esta técnica foi usada no repositório [PHL](https://github.com/alganet/PHL) para simplificar o processo de *build*. Tanto os *builds* Unix quanto Windows compartilham muitas variáveis e *targets*, aproveitando uma única fonte da verdade para os objetos construídos, dependências e outros. 
