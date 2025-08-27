from django.test import TestCase
from django.conf import settings
from django.utils.module_loading import import_string
from rest_framework.pagination import PageNumberPagination
from rest_framework.test import APIClient
from product.models import Product

class DRFPaginationIntegrationTests(TestCase):
    def setUp(self):
        # cria 12 produtos mínimos
        Product.objects.bulk_create([Product(title=f"Produto {i}") for i in range(1, 13)])
        self.client = APIClient()

    def test_rest_framework_pagination_settings(self):
        # Agora usamos uma classe custom (bookstore.pagination.DefaultPagination)
        # Verificamos que ela herda de PageNumberPagination e expõe os atributos esperados.
        cls_path = settings.REST_FRAMEWORK["DEFAULT_PAGINATION_CLASS"]
        paginator_cls = import_string(cls_path)
        assert issubclass(paginator_cls, PageNumberPagination)
        p = paginator_cls()
        assert p.page_size == 5
        assert getattr(p, "page_size_query_param", None) == "page_size"
        assert getattr(p, "max_page_size", None) == 100

    def test_paginated_endpoint_product(self):
        url = "/bookstore/v1/product/"
        r1 = self.client.get(url)                # page=1, default page_size=5
        assert r1.status_code == 200
        data = r1.json()
        assert {"count","next","previous","results"}.issubset(data.keys())
        assert len(data["results"]) == 5

        r2 = self.client.get(url, {"page": 2})
        assert r2.status_code == 200
        assert len(r2.json()["results"]) == 5

        r3 = self.client.get(url, {"page_size": 7})
        assert r3.status_code == 200
        assert len(r3.json()["results"]) == 7

class DebugToolbarConfigTests(TestCase):
    def test_debug_toolbar_present(self):
        assert "debug_toolbar" in settings.INSTALLED_APPS
        assert any("DebugToolbarMiddleware" in m for m in settings.MIDDLEWARE)
