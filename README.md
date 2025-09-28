# Bookstore — Django + Postgres + Docker Compose

API de exemplo para uma livraria, com Django 3.2 + DRF e Postgres, empacotada com Docker Compose.

## Pré-requisitos
- Docker 20+  
- Docker Compose V2 (`docker compose …`)

## Subir o ambiente (build + run)
```bash
docker compose up -d --build
docker compose ps       # db = healthy e web = Up
# Acesse: http://localhost:8000/admin/login/
```

> Se o `web` iniciar antes do `db`, o Django pode tentar conectar e falhar. É só aguardar o `db` ficar **healthy** e o `web` sobe normalmente (ou rode `docker compose up -d` de novo).

## Primeira configuração (uma vez)
```bash
# Garantir migrações aplicadas
docker compose exec web python manage.py migrate

# Criar superusuário (opcional, para acessar /admin)
docker compose exec -it web python manage.py createsuperuser

# Gerar token de API para o usuário (substitua <seu_usuario>)
docker compose exec web python manage.py drf_create_token <seu_usuario>
```

## Como usar a API
Base URL: `http://localhost:8000/bookstore/v1/`  
Autenticação: Token DRF no header `Authorization: Token <seu_token>`

### Endpoints principais
- `POST /api-token-auth/` — também emite token informando `username` e `password`  
- `GET/POST /bookstore/v1/category/`
- `GET/POST /bookstore/v1/product/`
- `GET/POST /bookstore/v1/order/`

### Exemplos (curl)
```bash
# Listar categorias
curl -s -H "Authorization: Token $TOKEN"   http://localhost:8000/bookstore/v1/category/

# Criar categoria
curl -s -X POST -H "Content-Type: application/json"   -H "Authorization: Token $TOKEN"   -d '{"title":"Sci-Fi","slug":""}'   http://localhost:8000/bookstore/v1/category/

# Criar produto (price inteiro; categories_id = lista de IDs)
curl -s -X POST -H "Content-Type: application/json"   -H "Authorization: Token $TOKEN"   -d '{"title":"Django Unleashed","price":99,"categories_id":[1]}'   http://localhost:8000/bookstore/v1/product/
```

## Admin
- `http://localhost:8000/admin/` (use o superusuário que você criou)

## Testes (opcional)
```bash
docker compose exec web pytest -q
```

## Desligar e limpar
```bash
docker compose down -v
# (opcional) docker network prune -f
```

## Dicas de troubleshooting
- Ver logs:
  ```bash
  docker compose logs -f db
  docker compose logs -f web
  ```
- Se o `web` estiver `Exited (1)` por conexão ao banco, aguarde o `db` ficar healthy e rode `docker compose up -d` novamente.
- Os scripts `.ps1` do repositório são **apenas conveniência**; a validação oficial é por estes comandos genéricos aqui do README.

## Observação sobre empacotamento
O projeto inclui `pyproject.toml` com `package-mode=true`. Isso permite instalar o app via `pip install .` dentro do container, mas **não é necessário** para rodar/validar com Docker.
