from django.conf import settings
from django.utils.module_loading import import_string
import pytest

def test_installed_apps_middleware_hosts_debug_toolbar():
    inst = set(settings.INSTALLED_APPS)
    assert "rest_framework" in inst, "rest_framework não está em INSTALLED_APPS"
    assert "debug_toolbar" in inst, "debug_toolbar não está em INSTALLED_APPS"
    assert any("DebugToolbarMiddleware" in m for m in settings.MIDDLEWARE), \
        "DebugToolbarMiddleware não configurado em MIDDLEWARE"
    ips = set(getattr(settings, "INTERNAL_IPS", []))
    assert "127.0.0.1" in ips, "INTERNAL_IPS deve conter 127.0.0.1"
    ah = set(getattr(settings, "ALLOWED_HOSTS", []))
    assert ah.intersection({"127.0.0.1", "localhost", "*" }), \
        "ALLOWED_HOSTS deve permitir 127.0.0.1/localhost/*"

def test_rest_framework_e_paginacao_configurada():
    rf = getattr(settings, "REST_FRAMEWORK", {})
    assert rf, "REST_FRAMEWORK não definido"
    cls_path = rf.get("DEFAULT_PAGINATION_CLASS")
    assert cls_path, "DEFAULT_PAGINATION_CLASS ausente"
    cls = import_string(cls_path)
    p = cls()
    assert getattr(p, "page_size", None) == 5, "page_size deve ser 5"
    assert getattr(p, "page_size_query_param", None) == "page_size", \
        "page_size_query_param deve ser 'page_size'"

@pytest.mark.django_db
def test_debug_toolbar_rota_habilitada_quando_debug(client):
    if settings.DEBUG and "debug_toolbar" in settings.INSTALLED_APPS:
        resp = client.get("/__debug__/")
        assert resp.status_code in {200, 302, 301}, \
            f"Rota /__debug__/ não respondeu como esperado (status {resp.status_code})"
    else:
        pytest.skip("DEBUG=False ou debug_toolbar não disponível – teste ignorado.")
