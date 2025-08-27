import os, sys, json
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "bookstore.settings")
import django
django.setup()

from django.conf import settings
from rest_framework.test import APIClient
from django.contrib.auth import get_user_model

res = {}

# --- Checagens de configuração ---
res["authtoken_app"] = "rest_framework.authtoken" in set(settings.INSTALLED_APPS)

# --- Checagens por atributos nos ViewSets (quando disponíveis) ---
order_auth_attr = False
order_perm_attr = False
product_allowany_attr = None
category_allowany_attr = None
errors = {}

try:
    from rest_framework.authentication import TokenAuthentication
    from rest_framework.permissions import IsAuthenticated, AllowAny
    from order.views import OrderViewSet
    order_auth_attr = getattr(OrderViewSet, "authentication_classes", None) is not None and TokenAuthentication in OrderViewSet.authentication_classes
    order_perm_attr = getattr(OrderViewSet, "permission_classes", None) is not None and IsAuthenticated in OrderViewSet.permission_classes
except Exception as e:
    errors["order_import_error"] = str(e)

try:
    from product.views import ProductViewSet
    from rest_framework.permissions import AllowAny
    # Se você tiver CategoryViewSet, também validamos:
    try:
        from product.views import CategoryViewSet
        category_allowany_attr = (getattr(CategoryViewSet, "permission_classes", None) and AllowAny in CategoryViewSet.permission_classes)
    except Exception:
        category_allowany_attr = None  # ok se não existir
    product_allowany_attr = (getattr(ProductViewSet, "permission_classes", None) and AllowAny in ProductViewSet.permission_classes)
except Exception as e:
    errors["product_import_error"] = str(e)

# --- Checagens de execução (HTTP real) ---
client = APIClient()

# Product deve ser público (200 sem auth)
product_status = client.get("/bookstore/v1/product/").status_code

# Order deve negar sem token (401/403)
unauth_order_status = client.get("/bookstore/v1/order/").status_code

# Order com token deve retornar 200
User = get_user_model()
u = User.objects.create_user(username="mateus-check", password="123456")
from rest_framework.authtoken.models import Token
tok, _ = Token.objects.get_or_create(user=u)

client.credentials(HTTP_AUTHORIZATION=f"Token {tok.key}")
auth_order_status = client.get("/bookstore/v1/order/").status_code

# (Opcional) endpoint /api-token-auth/
token_endpoint_ok = None
try:
    client = APIClient()
    r = client.post("/api-token-auth/", {"username": "mateus-check", "password": "123456"}, format="json")
    token_endpoint_ok = (r.status_code == 200 and "token" in getattr(r, "data", {}))
except Exception:
    token_endpoint_ok = False

res.update({
    "order_auth_attr": bool(order_auth_attr),
    "order_perm_attr": bool(order_perm_attr),
    "product_allowany_attr": bool(product_allowany_attr) if product_allowany_attr is not None else None,
    "category_allowany_attr": bool(category_allowany_attr) if category_allowany_attr is not None else None,
    "product_public_status": product_status,
    "order_unauth_status": unauth_order_status,
    "order_auth_status": auth_order_status,
    "token_endpoint_ok": token_endpoint_ok,
    "errors": errors,
})

print(json.dumps(res, indent=2))

# Critérios de aprovação (mínimos do enunciado + feedback):
passed = (
    res["authtoken_app"]
    and res["product_public_status"] == 200
    and res["order_unauth_status"] in (401, 403)
    and res["order_auth_status"] == 200
    and res["order_auth_attr"]
    and res["order_perm_attr"]
)

sys.exit(0 if passed else 1)
