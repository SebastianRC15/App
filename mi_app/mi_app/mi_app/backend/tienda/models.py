from django.db import models
from django.contrib.auth.models import AbstractUser

class Usuario(AbstractUser):
    def __str__(self):
        return self.username

class Producto(models.Model):
    TIPO_OFERTA_CHOICES = [
        ('NORMAL', 'Normal'),
        ('MAS_VENDIDO', 'Más Vendido'),
        ('FLASH', 'Oferta Flash'),
        ('LIQUIDACION', 'En Liquidación'),
    ]

    nombre = models.CharField(max_length=100)
    descripcion = models.TextField()
    categoria = models.CharField(max_length=50, default="General")
    tipo_oferta = models.CharField(max_length=20, choices=TIPO_OFERTA_CHOICES, default='NORMAL')
    precio = models.DecimalField(max_digits=10, decimal_places=2) # Precio actual
    precio_normal = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    imagen = models.URLField() # Imagen principal
    imagen2 = models.URLField(null=True, blank=True)
    imagen3 = models.URLField(null=True, blank=True)
    imagen4 = models.URLField(null=True, blank=True)
    stock = models.IntegerField(default=0)
    calificacion = models.FloatField(default=0.0)
    tienda = models.CharField(max_length=100, default="Tienda General") # "Vendido por..."
    creado_en = models.DateTimeField(auto_now_add=True, null=True)

    @property
    def descuento_porcentaje(self):
        if self.precio_normal and self.precio_normal > self.precio:
            descuento = ((self.precio_normal - self.precio) / self.precio_normal) * 100
            return round(descuento)
        return 0

    def __str__(self):
        return self.nombre

class Carrito(models.Model):
    usuario = models.OneToOneField(Usuario, on_delete=models.CASCADE, related_name='carrito')
    creado_en = models.DateTimeField(auto_now_add=True)

class ItemCarrito(models.Model):
    carrito = models.ForeignKey(Carrito, on_delete=models.CASCADE, related_name='items')
    producto = models.ForeignKey(Producto, on_delete=models.CASCADE)
    cantidad = models.PositiveIntegerField(default=1)
