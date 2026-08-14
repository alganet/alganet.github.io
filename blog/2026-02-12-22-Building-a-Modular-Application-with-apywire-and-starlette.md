<!--
SPDX-FileCopyrightText: 2026 Alexandre Gomes Gaigalas <alganet@gmail.com>

SPDX-License-Identifier: CC-BY-NC-SA-4.0
-->
---
alt: 2026-02-12-22-Construindo-uma-Aplicacao-Modular-com-apywire-e-starlette.pt
date: February 12, 2026
author: Alexandre Gomes Gaigalas
lang: en
---

# Building a Modular Application with apywire and starlette

This blog post explains how to use **apywire** to build a modular, dependency-injected **starlette** application. We’ll go step-by-step to wire up services, handlers, and a database using a declarative `config.yaml`.

The complete code for this tutorial is available at [github.com/alganet/apywire-starlette](https://github.com/alganet/apywire-starlette).

## The Problem

In many Python web applications, wiring dependencies (like database connections, services, and controllers) is often done manually in the application entrypoint or using frameworks that rely heavily on runtime reflection and decorators. This can lead to:
- **Tightly coupled code**: Hard to test and refactor.
- **Runtime overhead**: Reflection slows down startup and request handling.
- **Implicit dependencies**: Hard to see the full dependency graph.


**apywire** solves this by providing a **declarative** way to define your dependency graph in a YAML file, which is then **compiled** into efficient, transparent Python code.

## Step 1: The Components

First, let’s define our application components as plain Python classes. Notice they have no dependency on `apywire` or any DI framework. They just declare what they need in `__init__`.

### Services (`src/services.py`)

```
class UserService:
    def __init__(self, db):
        self.db = db

    def get_user(self, screen_name: str):
        # ... logic to fetch user ...
        pass

class MigrationService:
    def __init__(self, db):
        self.db = db

    def run(self):
        # ... logic to run migrations ...
        pass

```

### Handlers (`src/handlers.py`)

Our handlers (controllers) are simple callables that take dependencies.

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
        # ... return response ...

```

## Step 2: The Wiring (`config.yaml`)

This is where the magic happens. We declare our dependency graph in `config.yaml`.

```
# 1. Define the Database Connection - We use apsw directly, no wrapper needed.
apsw.Connection db:
  filename: "db.sqlite"

# 2. Wire the Services - We inject the 'db' defined above into our services.
services.UserService users:
  db: {db}

services.MigrationService migrations:
  db: {db}

# 3. Wire the Handlers - We inject the 'users' service into the UserHandler.
handlers.UserHandler user_handler:
  users: {users}

handlers.HomeHandler home_handler: {}

# 4. Define Routes - We bind the 'user_handler' to a path.
starlette.routing.Route user_route:
  path: "/users/{screen_name}"
  endpoint: {user_handler}
  methods: ["GET"]

starlette.routing.Route hello_route:
  path: "/"
  endpoint: {home_handler}

# 5. The Application - We assemble the app with our routes.
starlette.applications.starlette app:
  routes:
    - {user_route}
    - {hello_route}

```

**Key takeaways**:
- `{db}`: References the component named `db`.
- **Fully Qualified Names**: We use `module.ClassName` to specify types.
- **No Code Changes**: We didn't touch our Python classes to wire them up.


## Step 3: Compilation

apywire compiles this YAML into a Python file (`src/container.py`). This generated code is what your application actually uses. It handles lazy loading and ensures singletons are shared correctly.

To compile:

```
python src/app.py --compile
```

This generates `src/container.py`. You don't edit this file, but you can inspect it to see exactly how your application is wired. It’s just plain Python code!

## Step 4: Running the App

Our entrypoint `src/app.py` simply imports the compiled container and uses it.

```
from container import compiled

def create_app():
    return compiled.app()

if __name__ == "__main__":
    # ... CLI logic ...
    uvicorn.run("app:create_app", factory=True)

```

Because `compiled` is imported from a generated file, there is **zero** framework overhead at runtime.

## Conclusion

By isolating wiring into `config.yaml`, we achieved:
1. **Clean Architecture**: Business logic knows nothing about the framework.
2. **Performance**: Compilation effectively "bakes" the dependency graph into optimized code.
3. **Flexibility**: Changing the database implementation or swapping a service is just a config change.


Give [apywire](https://github.com/alganet/apywire) a try for your next Python project!
