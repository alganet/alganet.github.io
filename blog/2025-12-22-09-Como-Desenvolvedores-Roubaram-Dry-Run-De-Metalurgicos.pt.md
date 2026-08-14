<!--
SPDX-FileCopyrightText: 2025 Alexandre Gomes Gaigalas <alganet@gmail.com>

SPDX-License-Identifier: CC-BY-NC-SA-4.0
-->
---
alt: 2025-12-22-09-How-Developers-Stole-Dry-Runs-From-Machinists
date: 22 de Dezembro de 2025
author: Alexandre Gomes Gaigalas
lang: pt
---

# Como Desenvolvedores Roubaram "Dry Run" De Metalúrgicos

Se você já executou um comando com a flag `--dry-run`, provavelmente sabia o que ela fazia. O comando era executado, mas não *a coisa toda*.

Mais especificamente, um *dry run* executa **todas as partes, exceto as irreversíveis** de uma operação. 

## Um Exemplo Rápido

Por exemplo, digamos que você tenha um programa de linha de comando chamado `cleanup-database`:

```
$ cleanup-database --help
usage: cleanup-database [options]
Removes old data from the database.

Options:
--dry-run     Show what would be deleted, but don't actually delete anything
--force       Actually delete the data

```

Quando você executa esse programa passando a flag `--dry-run`, ele mostra o que faria sem realizar nenhuma alteração:

```
$ cleanup-database --dry-run
The following records would be deleted:
- Record ID 12345
- Record ID 67890
No changes have been made.

```

Isso é particularmente útil para comandos que executam ações destrutivas, como excluir arquivos ou modificar bancos de dados.

Dry runs não se limitam a ferramentas de linha de comando. Eles também podem ser encontrados em diversas bibliotecas e frameworks de programação, onde permitem que desenvolvedores simulem operações sem realizar alterações permanentes.

## Mas Por Que "Dry Run"?

Quero dizer, por que não `--simulate` ou `--preview`? De onde vem afinal o termo "*dry run*"?

**Ele vem do mundo da usinagem.**

Primeiro, deixe-me mostrar o que realmente é um *"wet run"*:

![Uma operação de wet run de uma máquina](/images/wet-run.jpg)
*Uma máquina realizando uma operação *wet run*, com fluidos de lubrificação reais sendo aplicados à peça. *

Essas operações são chamadas de "*wet*" porque um fluxo constante de fluido de lubrificação é necessário para que a operação ocorra suavemente.

Quando você está testando apenas os movimentos sem realizar nenhuma alteração de fato, não há atrito nem geração de calor, portanto o fluido de lubrificação não é necessário. Isso é um **dry run**, e é daí que o termo vem.
