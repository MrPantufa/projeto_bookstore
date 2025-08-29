FROM python:3.10-slim

RUN apt-get update && apt-get install -y --no-install-recommends build-essential libpq-dev && rm -rf /var/lib/apt/lists/*

WORKDIR /code
COPY . /code/

RUN pip install --no-cache-dir poetry && poetry config virtualenvs.create false && poetry lock --no-interaction --no-ansi && poetry install --no-interaction --no-ansi

EXPOSE 8000
CMD ["python","manage.py","runserver","0.0.0.0:8000"]
