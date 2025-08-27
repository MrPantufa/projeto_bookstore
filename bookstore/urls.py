import debug_toolbar
from django.contrib import admin
from django.urls import include, path, re_path

urlpatterns = [
    path("admin/", admin.site.urls),
    path("__debug__/", include(debug_toolbar.urls)),
    re_path(r"^bookstore/(?P<version>(v1|v2))/", include("order.urls")),
    re_path(r"^bookstore/(?P<version>(v1|v2))/", include("product.urls")),
]
