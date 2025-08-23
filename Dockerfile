FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Dependências de sistema (curl, build essentials, libpq para psycopg2 e netcat)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    build-essential \
    libpq-dev \
    netcat-traditional \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /code

# Copia o projeto inteiro
COPY . /code/

# Instala via Poetry (pyproject.toml)
RUN pip install --no-cache-dir poetry \
 && poetry config virtualenvs.create false \
 && poetry install --no-interaction --no-ansi

EXPOSE 8000

# Se o compose não definir 'command', roda o dev server
CMD ["python","manage.py","runserver","0.0.0.0:8000"]
