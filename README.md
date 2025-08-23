# Bookstore

## Pré-requisitos
- **Python 3.8+**
- **Poetry**
- (Opcional) **Docker Desktop** com Compose v2
- **Git**

## Local do projeto
```
C:\Users\Mateus\Desktop\projeto_bookstore_corrigido
```

---

## Uso (sem Docker)

1. Abrir o PowerShell na pasta do projeto:
```powershell
cd "C:\Users\Mateus\Desktop\projeto_bookstore_corrigido"
```

2. Instalar dependências:
```powershell
poetry install
```

3. Aplicar migrações e subir o servidor:
```powershell
poetry run python manage.py migrate
poetry run python manage.py runserver
```

4. (Opcional) Criar superusuário:
```powershell
poetry run python manage.py createsuperuser
```

5. Rodar testes:
```powershell
poetry run python manage.py test -v 2
```

---

## Uso com Docker

1. Abrir o PowerShell na pasta do projeto:
```powershell
cd "C:\Users\Mateus\Desktop\projeto_bookstore_corrigido"
```

2. Subir os serviços:
```powershell
docker compose up -d --build
```

3. Aplicar migrações (dentro do container `web`):
```powershell
docker compose exec web python manage.py migrate
```

4. (Opcional) Criar superusuário:
```powershell
docker compose exec web python manage.py createsuperuser
```

5. Rodar testes dentro do container:
```powershell
docker compose exec web python manage.py test -v 2
```

---

## Endpoints (exemplos)
- Desenvolvimento (sem Docker): `http://127.0.0.1:8000/`
- Com Docker: `http://localhost:8000/`

> Para listar as rotas reais registradas no projeto use `manage.py show_urls` (se `django-extensions` estiver instalado).

---

## Variáveis de ambiente (opcional, para Postgres via Docker)
Se usar Postgres, configure um `.env` com os valores abaixo e **garanta** que o `settings.py` lê essas variáveis:
```
SQL_ENGINE=django.db.backends.postgresql
SQL_DATABASE=bookstore
SQL_USER=bookstore
SQL_PASSWORD=bookstore
SQL_HOST=db
SQL_PORT=5432
```

---

## Roteiro de verificação

### Sem Docker
```powershell
# 1) Ir para a pasta do projeto
cd "C:\Users\Mateus\Desktop\projeto_bookstore_corrigido"

# 2) Conferir versões
python --version
poetry --version

# 3) Instalar deps e migrar
poetry install
poetry run python manage.py showmigrations
poetry run python manage.py migrate

# 4) Subir o servidor em nova janela para não travar este terminal
Start-Process powershell -ArgumentList 'cd "C:\Users\Mateus\Desktop\projeto_bookstore_corrigido"; poetry run python manage.py runserver'

# 5) Listar rotas (se disponível) e filtrar por palavras-chave
poetry run python manage.py show_urls | Select-String -Pattern "product|order|api|bookstore|auth"

# 6) Criar superusuário (opcional)
poetry run python manage.py createsuperuser

# 7) (Token Auth) Obter token via endpoint padrão do DRF (ajuste user/senha)
curl.exe -X POST http://127.0.0.1:8000/api-token-auth/ -H "Content-Type: application/json" -d "{\"username\":\"<user>\",\"password\":\"<senha>\"}"

# 8) (Token Auth) Testar endpoint protegido (ajuste a URL conforme suas rotas)
$env:TOKEN="<cole-o-token-aqui>"
$env:API_URL="http://127.0.0.1:8000/bookstore/v1/product/"
curl.exe $env:API_URL -H "Authorization: Token $env:TOKEN"

# 9) Rodar testes
poetry run python manage.py test -v 2
```

### Com Docker
```powershell
# 1) Ir para a pasta do projeto
cd "C:\Users\Mateus\Desktop\projeto_bookstore_corrigido"

# 2) Subir containers
docker compose up -d --build

# 3) Migrações
docker compose exec web python manage.py showmigrations
docker compose exec web python manage.py migrate

# 4) Listar rotas (se disponível)
docker compose exec web python manage.py show_urls | Select-String -Pattern "product|order|api|bookstore|auth"

# 5) Criar superusuário (opcional)
docker compose exec web python manage.py createsuperuser

# 6) (Token Auth) Obter token
curl.exe -X POST http://localhost:8000/api-token-auth/ -H "Content-Type: application/json" -d "{\"username\":\"<user>\",\"password\":\"<senha>\"}"

# 7) (Token Auth) Testar endpoint protegido
$env:TOKEN="<cole-o-token-aqui>"
$env:API_URL="http://localhost:8000/bookstore/v1/product/"
curl.exe $env:API_URL -H "Authorization: Token $env:TOKEN"

# 8) Rodar testes
docker compose exec web python manage.py test -v 2
```
