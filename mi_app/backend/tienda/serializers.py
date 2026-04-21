from rest_framework import serializers
from .models import Usuario, Producto, Carrito, ItemCarrito

class UsuarioSerializer(serializers.ModelSerializer):
    class Meta:
        model = Usuario
        fields = ('id', 'username', 'email', 'password')
        extra_kwargs = {'password': {'write_only': True}}

    def create(self, validated_data):
        user = Usuario.objects.create_user(**validated_data)
        return user

class ProductoSerializer(serializers.ModelSerializer):
    descuento_porcentaje = serializers.ReadOnlyField()
    class Meta:
        model = Producto
        fields = '__all__'

class ItemCarritoSerializer(serializers.ModelSerializer):
    producto = ProductoSerializer(read_only=True)
    producto_id = serializers.PrimaryKeyRelatedField(queryset=Producto.objects.all(), source='producto', write_only=True)

    class Meta:
        model = ItemCarrito
        fields = ('id', 'producto', 'producto_id', 'cantidad')

class CarritoSerializer(serializers.ModelSerializer):
    items = ItemCarritoSerializer(many=True, read_only=True)
    class Meta:
        model = Carrito
        fields = ('id', 'usuario', 'items')
