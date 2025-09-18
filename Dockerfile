FROM python:3.10-slim

# system deps for psycopg2
RUN apt-get update && apt-get install -y --no-install-recommends     build-essential libpq-dev &&     rm -rf /var/lib/apt/lists/*

WORKDIR /code

# copy project
COPY . /code/

# install poetry and deps (no venv)
RUN pip install --no-cache-dir poetry &&     poetry config virtualenvs.create false &&     poetry lock --no-interaction --no-ansi &&     poetry install --no-interaction --no-ansi

# The command is provided by docker-compose (migrate + runserver)
