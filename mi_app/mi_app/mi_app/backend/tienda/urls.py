from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import UsuarioViewSet, ProductoViewSet, CarritoViewSet

router = DefaultRouter()
router.register(r'usuarios', UsuarioViewSet)
router.register(r'productos', ProductoViewSet)

urlpatterns = [
    path('', include(router.urls)),
    path('carrito/', CarritoViewSet.as_view({'get': 'list'}), name='carrito-detalle'),
    path('carrito/agregar/', CarritoViewSet.as_view({'post': 'agregar'}), name='carrito-agregar'),
    path('carrito/vaciar/', CarritoViewSet.as_view({'post': 'vaciar'}), name='carrito-vaciar'),
]
