FROM python:3.11-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1
WORKDIR /app
RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential \
    && rm -rf /var/lib/apt/lists/*
COPY requirements.txt* /tmp/
RUN python -m pip install --upgrade pip setuptools wheel \
    && if [ -f /tmp/requirements.txt ]; then \
        pip install -r /tmp/requirements.txt ; \
    else \
        pip install "Django>=3.2,<5" djangorestframework ; \
    fi
COPY . /app
EXPOSE 8000
CMD ["sh","-c","python manage.py migrate --noinput && python manage.py runserver 0.0.0.0:8000"]