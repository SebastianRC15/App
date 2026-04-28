import uuid
from django.db import models
from django.contrib.auth.models import AbstractUser
from django.contrib.postgres.fields import ArrayField
from django.utils import timezone

class Usuario(AbstractUser):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    nombre_completo = models.TextField()
    dni_ruc = models.CharField(max_length=20, unique=True, null=True, blank=True)
    correo_electronico = models.EmailField(unique=True)
    telefono = models.TextField(null=True, blank=True)
    direccion_referencia = models.TextField(null=True, blank=True)
    distrito = models.TextField(null=True, blank=True)
    codigo_referido_propio = models.CharField(max_length=10, unique=True, null=True, blank=True)
    id_referido_por = models.ForeignKey('self', on_delete=models.SET_NULL, null=True, blank=True)
    saldo_disponible = models.DecimalField(max_digits=10, decimal_places=2, default=0.00)
    fecha_registro = models.DateTimeField(auto_now_add=True)

    def save(self, *args, **kwargs):
        if not self.codigo_referido_propio:
            self.codigo_referido_propio = uuid.uuid4().hex[:6].upper()
        if not self.email:
            self.email = self.correo_electronico
        if not self.username:
            self.username = self.correo_electronico
        super().save(*args, **kwargs)

    def __str__(self):
        return self.username

class Categoria(models.Model):
    nombre = models.TextField()
    slug = models.TextField(unique=True)
    url_icono = models.URLField(null=True, blank=True)

    def __str__(self):
        return self.nombre

class Producto(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    categoria = models.ForeignKey(Categoria, on_delete=models.CASCADE, related_name='productos')
    nombre_tienda = models.TextField()
    nombre_producto = models.TextField()
    descripcion = models.TextField(null=True, blank=True)
    precio_normal = models.DecimalField(max_digits=10, decimal_places=2)
    precio_oferta = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    stock_disponible = models.IntegerField(default=0)
    imagenes = ArrayField(models.TextField())
    calificacion_promedio = models.DecimalField(max_digits=2, decimal_places=1, default=0.0)
    es_mas_vendido = models.BooleanField(default=False)
    es_oferta_flash = models.BooleanField(default=False)
    es_liquidacion = models.BooleanField(default=False)
    es_gancho_menor_9_90 = models.BooleanField(default=False)
    fecha_creacion = models.DateTimeField(auto_now_add=True)

    @property
    def descuento_porcentaje(self):
        if self.precio_normal and self.precio_oferta and self.precio_normal > self.precio_oferta:
            descuento = ((self.precio_normal - self.precio_oferta) / self.precio_normal) * 100
            return round(descuento)
        return 0

    def __str__(self):
        return self.nombre_producto

class Carrito(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    usuario = models.OneToOneField(Usuario, on_delete=models.CASCADE, related_name='carrito')
    creado_en = models.DateTimeField(auto_now_add=True)
    fecha_actualizacion = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Carrito de {self.usuario.username}"

class ItemCarrito(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    carrito = models.ForeignKey(Carrito, on_delete=models.CASCADE, related_name='items')
    producto = models.ForeignKey(Producto, on_delete=models.CASCADE, related_name='items_en_carrito')
    cantidad = models.PositiveIntegerField(default=1)
    fecha_agregado = models.DateTimeField(default=timezone.now)

    class Meta:
        unique_together = ('carrito', 'producto')

    def __str__(self):
        return f"{self.producto.nombre_producto} x{self.cantidad}"

class Pedido(models.Model):
    ESTADO_CHOICES = [
        ('pendiente', 'Pendiente'),
        ('pagado', 'Pagado'),
        ('enviado', 'Enviado'),
        ('entregado', 'Entregado'),
    ]
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    usuario = models.ForeignKey(Usuario, on_delete=models.CASCADE, related_name='pedidos')
    estado_pedido = models.CharField(max_length=20, choices=ESTADO_CHOICES, default='pendiente')
    monto_subtotal = models.DecimalField(max_digits=10, decimal_places=2)
    costo_envio = models.DecimalField(max_digits=10, decimal_places=2, default=0.00)
    monto_total_pagar = models.DecimalField(max_digits=10, decimal_places=2)
    whatsapp_contacto = models.TextField(null=True, blank=True)
    dni_ruc_comprobante = models.CharField(max_length=20, null=True, blank=True)
    direccion_envio = models.TextField(null=True, blank=True)
    tipo_envio = models.TextField(null=True, blank=True)
    fecha_pedido = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Pedido #{self.id} - {self.usuario.username}"

class DetallePedido(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    pedido = models.ForeignKey(Pedido, on_delete=models.CASCADE, related_name='detalles')
    producto = models.ForeignKey(Producto, on_delete=models.CASCADE)
    cantidad = models.IntegerField()
    precio_unitario_historico = models.DecimalField(max_digits=10, decimal_places=2)
    subtotal_item = models.DecimalField(max_digits=10, decimal_places=2)

class HistorialBilletera(models.Model):
    MOVIMIENTO_CHOICES = [
        ('ingreso', 'Ingreso'),
        ('egreso', 'Egreso'),
    ]
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    usuario = models.ForeignKey(Usuario, on_delete=models.CASCADE, related_name='historial_billetera')
    monto = models.DecimalField(max_digits=10, decimal_places=2)
    tipo_movimiento = models.CharField(max_length=10, choices=MOVIMIENTO_CHOICES)
    descripcion = models.TextField(null=True, blank=True)
    fecha = models.DateTimeField(auto_now_add=True)

class RecompensaDiaria(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    usuario = models.ForeignKey(Usuario, on_delete=models.CASCADE, related_name='recompensas')
    fecha_reclamado = models.DateField(auto_now_add=True)
    premio_otorgado = models.TextField()
    valor_premio = models.DecimalField(max_digits=10, decimal_places=2)

    class Meta:
        unique_together = ('usuario', 'fecha_reclamado')

class RegistroReferido(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    anfitrion = models.ForeignKey(Usuario, on_delete=models.CASCADE, related_name='referidos_invitados')
    invitado = models.ForeignKey(Usuario, on_delete=models.CASCADE, related_name='referido_por_usuario')
    recompensa_aplicada = models.BooleanField(default=False)
    fecha_registro = models.DateTimeField(auto_now_add=True)
