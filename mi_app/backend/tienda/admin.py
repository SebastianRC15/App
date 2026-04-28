from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from .models import Usuario, Producto, Carrito, ItemCarrito

@admin.register(Usuario)
class CustomUserAdmin(UserAdmin):
    list_display = ('username', 'email', 'is_staff')

@admin.register(Producto)
class ProductoAdmin(admin.ModelAdmin):
    list_display = ('nombre_producto', 'nombre_tienda', 'precio_normal', 'stock_disponible')
    search_fields = ('nombre_producto', 'nombre_tienda')

admin.site.register(Carrito)
admin.site.register(ItemCarrito)
