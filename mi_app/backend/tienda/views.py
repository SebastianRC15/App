from rest_framework import viewsets, status, permissions
from rest_framework.decorators import action
from rest_framework.response import Response
from .models import Usuario, Producto, Carrito, ItemCarrito
from .serializers import (
    UsuarioSerializer, ProductoSerializer, CarritoSerializer, 
    ItemCarritoSerializer
)

class UsuarioViewSet(viewsets.ModelViewSet):
    queryset = Usuario.objects.all()
    serializer_class = UsuarioSerializer

    def get_permissions(self):
        if self.action == 'create':
            return [permissions.AllowAny()]
        return [permissions.IsAuthenticated()]

class ProductoViewSet(viewsets.ModelViewSet):
    queryset = Producto.objects.all()
    serializer_class = ProductoSerializer
    
    def get_permissions(self):
        if self.action in ['list', 'retrieve', 'categorias']:
            return [permissions.AllowAny()]
        return [permissions.IsAdminUser()]

    def get_queryset(self):
        queryset = Producto.objects.all()
        
        # Filtros
        categoria = self.request.query_params.get('categoria')
        tipo_oferta = self.request.query_params.get('tipo_oferta')
        precio_max = self.request.query_params.get('precio_max')
        search = self.request.query_params.get('search')

        if categoria:
            queryset = queryset.filter(categoria=categoria)
        if tipo_oferta:
            queryset = queryset.filter(tipo_oferta=tipo_oferta)
        if precio_max:
            queryset = queryset.filter(precio__lte=precio_max)
        if search:
            queryset = queryset.filter(nombre__icontains=search)

        # Orden aleatorio para la carga inicial si no hay filtros específicos
        if not any([categoria, tipo_oferta, precio_max, search]):
            queryset = queryset.order_by('?')
        
        return queryset

    @action(detail=False, methods=['get'])
    def categorias(self, request):
        categorias = Producto.objects.values_list('categoria', flat=True).distinct()
        return Response(list(categorias))

class CarritoViewSet(viewsets.ViewSet):
    permission_classes = [permissions.IsAuthenticated]

    def list(self, request):
        carrito, created = Carrito.objects.get_or_create(usuario=request.user)
        serializer = CarritoSerializer(carrito)
        return Response(serializer.data)

    @action(detail=False, methods=['post'])
    def agregar(self, request):
        carrito, created = Carrito.objects.get_or_create(usuario=request.user)
        producto_id = request.data.get('producto_id')
        cantidad = int(request.data.get('cantidad', 1))
        
        try:
            producto = Producto.objects.get(id=producto_id)
        except Producto.DoesNotExist:
            return Response({'error': 'Producto no encontrado'}, status=status.HTTP_404_NOT_FOUND)

        item, created = ItemCarrito.objects.get_or_create(carrito=carrito, producto=producto)
        if not created:
            item.cantidad += cantidad
        else:
            item.cantidad = cantidad
        item.save()
        
        return Response({'message': 'Producto agregado al carrito'})

    @action(detail=False, methods=['post'])
    def vaciar(self, request):
        carrito, created = Carrito.objects.get_or_create(usuario=request.user)
        carrito.items.all().delete()
        return Response({'message': 'Carrito vaciado'})
