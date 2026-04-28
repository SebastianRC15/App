from rest_framework import serializers
from .models import Usuario, Producto, Categoria, Carrito, ItemCarrito, Pedido, DetallePedido, HistorialBilletera, RecompensaDiaria

class UsuarioSerializer(serializers.ModelSerializer):
    class Meta:
        model = Usuario
        fields = ('id', 'username', 'nombre_completo', 'dni_ruc', 'correo_electronico', 'telefono', 'direccion_referencia', 'distrito', 'codigo_referido_propio', 'id_referido_por', 'saldo_disponible', 'fecha_registro', 'password')
        extra_kwargs = {
            'password': {'write_only': True, 'required': False},
            'codigo_referido_propio': {'read_only': True},
            'saldo_disponible': {'read_only': True},
            'fecha_registro': {'read_only': True},
        }

    def create(self, validated_data):
        user = Usuario.objects.create_user(**validated_data)
        return user

class CategoriaSerializer(serializers.ModelSerializer):
    class Meta:
        model = Categoria
        fields = '__all__'

class DetallePedidoSerializer(serializers.ModelSerializer):
    producto_nombre = serializers.ReadOnlyField(source='producto.nombre_producto')
    class Meta:
        model = DetallePedido
        fields = ('id', 'producto', 'producto_nombre', 'cantidad', 'precio_unitario_historico', 'subtotal_item')

class PedidoSerializer(serializers.ModelSerializer):
    detalles = DetallePedidoSerializer(many=True, read_only=True)
    class Meta:
        model = Pedido
        fields = '__all__'

class ProductoSerializer(serializers.ModelSerializer):
    descuento_porcentaje = serializers.ReadOnlyField()
    class Meta:
        model = Producto
        fields = '__all__'

class ItemCarritoSerializer(serializers.ModelSerializer):
    producto_detalle = ProductoSerializer(source='producto', read_only=True)

    class Meta:
        model = ItemCarrito
        fields = ('id', 'producto', 'producto_detalle', 'cantidad', 'fecha_agregado')

class CarritoSerializer(serializers.ModelSerializer):
    items = ItemCarritoSerializer(many=True, read_only=True)

    class Meta:
        model = Carrito
        fields = ('id', 'usuario', 'items', 'creado_en', 'fecha_actualizacion')
        read_only_fields = ('usuario',)

class HistorialBilleteraSerializer(serializers.ModelSerializer):
    class Meta:
        model = HistorialBilletera
        fields = '__all__'

class RecompensaDiariaSerializer(serializers.ModelSerializer):
    class Meta:
        model = RecompensaDiaria
        fields = '__all__'
