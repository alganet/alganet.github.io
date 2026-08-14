<!--
SPDX-FileCopyrightText: 2026 Alexandre Gomes Gaigalas <alganet@gmail.com>

SPDX-License-Identifier: CC-BY-NC-SA-4.0
-->
---
alt: 2026-02-12-22-Building-a-Modular-Application-with-apywire-and-starlette
date: 12 de Fevereiro de 2026
author: Alexandre Gomes Gaigalas
lang: pt
---

# Construindo uma Aplicação Modular com apywire e starlette

Este post explica como usar o **apywire** para construir uma aplicação modular com injeção de dependências usando **starlette**. Vamos passo a passo para conectar serviços, handlers e um banco de dados usando um `config.yaml` declarativo.

O código completo deste tutorial está disponível em [github.com/alganet/apywire-starlette](https://github.com/alganet/apywire-starlette).

## O problema

Em muitas aplicações web Python, a cola entre dependências (conexões com banco, serviços e controllers) é feita manualmente no ponto de entrada da aplicação ou usando frameworks que dependem muito de reflection em tempo de execução e decorators. Isso pode causar:
- **Código fortemente acoplado**: difícil de testar e refatorar.
- **Overhead em tempo de execução**: reflection atrasa inicialização e o tempo de resposta de requisições.
- **Dependências implícitas**: o grafo de dependências fica difícil de visualizar.


O **apywire** resolve isso oferecendo uma maneira **declarativa** de definir o grafo de dependências em um arquivo YAML, que é então **compilado** em código Python eficiente e transparente.

## Passo 1: Os componentes

Primeiro, definimos nossos componentes como classes Python simples. Note que elas não dependem de `apywire` nem de nenhum framework de DI — apenas declaram o que precisam em `__init__`.

### Serviços (`src/services.py`)

```
class UserService:
    def __init__(self, db):
        self.db = db

    def get_user(self, screen_name: str):
        # ... lógica pra obter o usuário ...
        pass

class MigrationService:
    def __init__(self, db):
        self.db = db

    def run(self):
        # ... lógica pra executar as migrações ...
        pass

```

### Handlers (`src/handlers.py`)

Os handlers (controllers) são callables simples que recebem dependências.

```
from starlette.responses import JSONResponse
from starlette.requests import Request
import services

class UserHandler:
    def __init__(self, users: services.UserService):
        self.users = users

    async def __call__(self, scope, receive, send):
        request = Request(scope, receive)
        screen_name = request.path_params["screen_name"]
        user = self.users.get_user(screen_name)
        # ... retorna a resposta ...

```

## Passo 2: A ligação (`config.yaml`)

Aqui acontece a mágica. Declaramos nosso grafo de dependências em `config.yaml`.

```
# 1. Define a conexão com o banco de dados. Usa APSW diretamente, sem necessidade de wrapper.
apsw.Connection db:
  filename: "db.sqlite"

# 2. Conecta os serviços. Injetamos o 'db' definido acima nos nossos serviços.
services.UserService users:
  db: {db}

services.MigrationService migrations:
  db: {db}

# 3. Conecta os handlers. Injetamos o serviço 'users' no UserHandler.
handlers.UserHandler user_handler:
  users: {users}

handlers.HomeHandler home_handler: {}

# 4. Define as rotas. Vinculamos o 'user_handler' a um path.
starlette.routing.Route user_route:
  path: "/users/{screen_name}"
  endpoint: {user_handler}
  methods: ["GET"]

starlette.routing.Route hello_route:
  path: "/"
  endpoint: {home_handler}

# 5. A Aplicação - Montamos a aplicação com nossas rotas.
starlette.applications.starlette app:
  routes:
    - {user_route}
    - {hello_route}

```

**Principais observações**:
- `{db}`: referencia o componente chamado `db`.
- **Nomes totalmente qualificados**: usamos `module.ClassName` para especificar tipos.
- **Sem mudanças no código**: não alteramos as classes Python para fazer o wiring.


## Passo 3: Compilação

O apywire compila esse YAML em um arquivo Python (`src/container.py`). Esse código gerado é o que sua aplicação realmente usa — ele lida com carregamento preguiçoso e garante que singletons sejam compartilhados corretamente.

Para compilar:

```
python src/app.py --compile
```

Isso gera `src/container.py`. Você não edita esse arquivo, mas pode inspecioná‑lo para ver exatamente como sua aplicação foi ligada — é apenas código Python comum!

## Passo 4: Executando a aplicação

O entrypoint `src/app.py` simplesmente importa o container compilado e o utiliza.

```
from container import compiled

def create_app():
    return compiled.app()

if __name__ == "__main__":
    # ... lógica da CLI ...
    uvicorn.run("app:create_app", factory=True)

```

Como `compiled` é importado de um arquivo gerado, não há overhead de framework em tempo de execução.

## Conclusão

Ao isolar o wiring em `config.yaml`, alcançamos:
1. **Arquitetura limpa**: a lógica de negócio não conhece o framework.
2. **Performance**: a compilação "assenta" o grafo de dependências em código otimizado.
3. **Flexibilidade**: trocar a implementação do banco ou de um serviço é apenas uma mudança de configuração.


Experimente o [apywire](https://github.com/alganet/apywire) no seu próximo projeto Python!
