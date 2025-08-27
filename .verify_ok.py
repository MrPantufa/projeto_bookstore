import os, sys, json
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "bookstore.settings")
import django
django.setup()

from rest_framework.test import APIClient
from django.contrib.auth import get_user_model
from rest_framework.authtoken.models import Token

client = APIClient()

product_status = client.get("/bookstore/v1/product/").status_code
unauth_order_status = client.get("/bookstore/v1/order/").status_code

User = get_user_model()
uname = "mateus-check"
u, _ = User.objects.get_or_create(username=uname, defaults={"email": "m@x.y"})
u.set_password("123456"); u.save()
tok, _ = Token.objects.get_or_create(user=u)

client.credentials(HTTP_AUTHORIZATION=f"Token {tok.key}")
auth_order_status = client.get("/bookstore/v1/order/").status_code

# endpoint de token (opcional)
client = APIClient()
r = client.post("/api-token-auth/", {"username": uname, "password": "123456"}, format="json")
token_ok = (r.status_code == 200 and "token" in getattr(r, "data", {}))

print(json.dumps({
  "product_public_status": product_status,
  "order_unauth_status": unauth_order_status,
  "order_auth_status": auth_order_status,
  "token_endpoint_ok": token_ok
}, indent=2))

sys.exit(0 if (product_status==200 and unauth_order_status in (401,403) and auth_order_status==200) else 1)
