import os, sys, json
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "bookstore.settings")

import django
django.setup()

from django.conf import settings
# Permite testserver para o APIClient
try:
    if isinstance(settings.ALLOWED_HOSTS, (list, tuple)):
        hosts = list(settings.ALLOWED_HOSTS)
        if "testserver" not in hosts:
            hosts.append("testserver")
        settings.ALLOWED_HOSTS[:] = hosts
    else:
        settings.ALLOWED_HOSTS = ["testserver"]
except Exception:
    settings.ALLOWED_HOSTS = ["testserver"]

from rest_framework.test import APIClient
from django.contrib.auth import get_user_model
from rest_framework.authtoken.models import Token

res = {}
res["authtoken_app"] = "rest_framework.authtoken" in set(settings.INSTALLED_APPS)

client = APIClient()
product_status = client.get("/bookstore/v1/product/").status_code
unauth_order_status = client.get("/bookstore/v1/order/").status_code

User = get_user_model()
uname = "mateus-check"
u, _ = User.objects.get_or_create(username=uname)
u.set_password("123456"); u.save()
tok, _ = Token.objects.get_or_create(user=u)

client.credentials(HTTP_AUTHORIZATION=f"Token {tok.key}")
auth_order_status = client.get("/bookstore/v1/order/").status_code

# (Opcional) endpoint de token
client = APIClient()
r = client.post("/api-token-auth/", {"username": uname, "password": "123456"}, format="json")
token_endpoint_ok = (r.status_code == 200 and "token" in getattr(r, "data", {}))

res.update({
    "product_public_status": product_status,
    "order_unauth_status": unauth_order_status,
    "order_auth_status": auth_order_status,
    "token_endpoint_ok": token_endpoint_ok,
})

print(json.dumps(res, indent=2))

passed = (
    res["product_public_status"] == 200 and
    res["order_unauth_status"] in (401, 403) and
    res["order_auth_status"] == 200
)
sys.exit(0 if passed else 1)
