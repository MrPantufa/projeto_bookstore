import os, sys, json
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "bookstore.settings")

import django
django.setup()

from django.conf import settings
# evitar DisallowedHost com APIClient
try:
    hosts = list(settings.ALLOWED_HOSTS) if isinstance(settings.ALLOWED_HOSTS, (list, tuple)) else []
except Exception:
    hosts = []
for h in ["testserver","localhost","127.0.0.1"]:
    if h not in hosts: hosts.append(h)
settings.ALLOWED_HOSTS = hosts

from rest_framework.test import APIClient
from django.contrib.auth import get_user_model
from rest_framework.authtoken.models import Token

client = APIClient()
product_status = client.get("/bookstore/v1/product/").status_code
unauth_order_status = client.get("/bookstore/v1/order/").status_code

User = get_user_model()
uname = "mateus-check"
if not User.objects.filter(username=uname).exists():
    u = User.objects.create_user(username=uname, password="123456")
else:
    u = User.objects.get(username=uname)
tok, _ = Token.objects.get_or_create(user=u)

client.credentials(HTTP_AUTHORIZATION=f"Token {tok.key}")
auth_order_status = client.get("/bookstore/v1/order/").status_code

res = {
    "product_public_status": product_status,
    "order_unauth_status": unauth_order_status,
    "order_auth_status": auth_order_status,
}
print(json.dumps(res, indent=2))
sys.exit(0 if (product_status==200 and unauth_order_status in (401,403) and auth_order_status==200) else 1)
