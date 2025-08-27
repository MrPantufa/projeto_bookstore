import os, sys, json, django
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "bookstore.settings")
django.setup()

from rest_framework.test import APIClient
from django.contrib.auth import get_user_model
from rest_framework.authtoken.models import Token

client = APIClient()
# Product deve ser público
prod = client.get("/bookstore/v1/product/").status_code
# Order deve negar sem token (401/403)
unauth = client.get("/bookstore/v1/order/").status_code

# Order com token deve ser 200
User = get_user_model()
u, _ = User.objects.get_or_create(username="mateus-check")
u.set_password("123456"); u.save()
tok, _ = Token.objects.get_or_create(user=u)
client.credentials(HTTP_AUTHORIZATION=f"Token {tok.key}")
auth = client.get("/bookstore/v1/order/").status_code

print(json.dumps({"product_public_status": prod, "order_unauth_status": unauth, "order_auth_status": auth}, indent=2))
sys.exit(0 if (prod==200 and unauth in (401,403) and auth==200) else 1)
