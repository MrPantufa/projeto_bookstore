import re
import pathlib
import pytest
from django.db import connection

URLS = pathlib.Path("bookstore/urls.py")

def _read(p: pathlib.Path) -> str:
    assert p.exists(), f"Arquivo esperado não encontrado: {p}"
    return p.read_text(encoding="utf-8")

def test_urls_tem_includes_e_prefixo_versionado():
    txt = _read(URLS)
    assert re.search(r'include\(\s*["\']product\.urls', txt), "bookstore/urls.py precisa incluir product.urls"
    assert re.search(r'include\(\s*["\']order\.urls', txt),   "bookstore/urls.py precisa incluir order.urls"
    assert re.search(r'(?m)re_path\(\s*r["\']\^?bookstore/\(\?P<version>\((?:v1\|v2)\)\)/', txt), \
        "Prefixo versionado ^bookstore/(?P<version>(v1|v2))/ ausente"

@pytest.mark.django_db
def test_migrations_aplicadas_para_product():
    tables = set(connection.introspection.table_names())
    assert any(t.startswith("product_") for t in tables), \
        "Tabelas do app product não foram migradas (rode 'python manage.py migrate')."

@pytest.mark.django_db
def test_endpoint_paginado_funciona(client):
    from product.models import Product
    Product.objects.all().delete()
    Product.objects.bulk_create([Product(title=f"Produto {i}") for i in range(1, 13)])

    base = "/bookstore/v1/product/"
    r1 = client.get(base);  assert r1.status_code == 200
    d1 = r1.json()
    assert d1.get("count") == 12
    assert len(d1.get("results", [])) == 5

    r2 = client.get(base + "?page=2");  assert r2.status_code == 200
    d2 = r2.json()
    assert len(d2.get("results", [])) == 5

    r3 = client.get(base + "?page_size=7");  assert r3.status_code == 200
    d3 = r3.json()
    assert len(d3.get("results", [])) == 7
