import random
import json
from urllib import request as urlrequest
from urllib.error import HTTPError, URLError
from django.utils import timezone
from django.conf import settings
from datetime import timedelta
from rest_framework import viewsets, status, permissions
from rest_framework.decorators import action, api_view, permission_classes
from rest_framework.response import Response
from .models import Usuario, Producto, Categoria, Carrito, ItemCarrito, Pedido, DetallePedido, HistorialBilletera, RecompensaDiaria, RegistroReferido
from .serializers import (
    UsuarioSerializer, ProductoSerializer, CategoriaSerializer, CarritoSerializer,
    PedidoSerializer, HistorialBilleteraSerializer, RecompensaDiariaSerializer
)

class UsuarioViewSet(viewsets.ModelViewSet):
    queryset = Usuario.objects.all()
    serializer_class = UsuarioSerializer

    def get_permissions(self):
        if self.action == 'create':
            return [permissions.AllowAny()]
        return [permissions.IsAuthenticated()]

    @action(detail=False, methods=['get'])
    def mi_perfil(self, request):
        serializer = self.get_serializer(request.user)
        return Response(serializer.data)

    @action(detail=False, methods=['post'])
    def canjear_referido(self, request):
        codigo = request.data.get('codigo')
        try:
            anfitrion = Usuario.objects.get(codigo_referido_propio=codigo)
            if anfitrion == request.user:
                return Response({'error': 'No puedes referirte a ti mismo'}, status=400)
            
            # Verificar si ya fue referido
            if RegistroReferido.objects.filter(invitado=request.user).exists():
                return Response({'error': 'Ya has sido referido anteriormente'}, status=400)

            RegistroReferido.objects.create(anfitrion=anfitrion, invitado=request.user)
            
            # Lógica de recompensas
            anfitrion.saldo_disponible += 1.00 # Ejemplo de recompensa
            anfitrion.save()

            return Response({'message': 'Código de referido aplicado con éxito'})
        except Usuario.DoesNotExist:
            return Response({'error': 'Código inválido'}, status=404)

    @action(detail=False, methods=['post'])
    def premio_diario(self, request):
        user = request.user
        hoy = timezone.now().date()
        
        if RecompensaDiaria.objects.filter(usuario=user, fecha_reclamado=hoy).exists():
            return Response({'error': 'Ya reclamaste tu premio hoy. Vuelve mañana.'}, status=400)
        
        premios = [0.10, 0.20, 0.50, 1.00, 2.00]
        valor = random.choice(premios)
        
        RecompensaDiaria.objects.create(
            usuario=user,
            premio_otorgado=f"Premio Diario S/ {valor}",
            valor_premio=valor
        )
        
        user.saldo_disponible += valor
        user.save()
        
        return Response({
            'message': f'¡Felicidades! Ganaste S/ {valor}',
            'saldo': user.saldo_disponible
        })

class CategoriaViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = Categoria.objects.all()
    serializer_class = CategoriaSerializer
    permission_classes = [permissions.AllowAny]

class ProductoViewSet(viewsets.ModelViewSet):
    queryset = Producto.objects.all()
    serializer_class = ProductoSerializer
    
    def get_permissions(self):
        if self.action in ['list', 'retrieve']:
            return [permissions.AllowAny()]
        return [permissions.IsAdminUser()]

    def get_queryset(self):
        queryset = Producto.objects.all()
        
        # Filtros
        categoria_id = self.request.query_params.get('categoria_id')
        es_mas_vendido = self.request.query_params.get('es_mas_vendido')
        es_oferta_flash = self.request.query_params.get('es_oferta_flash')
        precio_max = self.request.query_params.get('precio_max')
        search = self.request.query_params.get('search')

        if categoria_id:
            queryset = queryset.filter(categoria_id=categoria_id)
        if es_mas_vendido:
            queryset = queryset.filter(es_mas_vendido=True)
        if es_oferta_flash:
            queryset = queryset.filter(es_oferta_flash=True)
        if precio_max:
            queryset = queryset.filter(precio_oferta__lte=precio_max)
        if search:
            queryset = queryset.filter(nombre_producto__icontains=search)

        # Orden aleatorio para la carga inicial si no hay filtros específicos
        if not any([categoria_id, es_mas_vendido, es_oferta_flash, precio_max, search]):
            queryset = queryset.order_by('?')
        
        return queryset

class PedidoViewSet(viewsets.ModelViewSet):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = PedidoSerializer

    def get_queryset(self):
        return Pedido.objects.filter(usuario=self.request.user).order_by('-fecha_pedido')

    def create(self, request):
        items_data = request.data.get('items', [])
        if not items_data:
            return Response({'error': 'No hay items en el pedido'}, status=400)

        # Crear el pedido
        pedido = Pedido.objects.create(
            usuario=request.user,
            monto_subtotal=request.data.get('monto_subtotal'),
            costo_envio=request.data.get('costo_envio', 0),
            monto_total_pagar=request.data.get('monto_total_pagar'),
            whatsapp_contacto=request.data.get('whatsapp_contacto'),
            dni_ruc_comprobante=request.data.get('dni_ruc_comprobante'),
            direccion_envio=request.data.get('direccion_envio'),
            tipo_envio=request.data.get('tipo_envio'),
            estado_pedido='pendiente'
        )

        # Crear detalles
        for item in items_data:
            producto = Producto.objects.get(id=item['producto_id'])
            DetallePedido.objects.create(
                pedido=pedido,
                producto=producto,
                cantidad=item['cantidad'],
                precio_unitario_historico=item['precio_unitario'],
                subtotal_item=item['subtotal']
            )

        serializer = self.get_serializer(pedido)
        return Response(serializer.data, status=status.HTTP_201_CREATED)

class CarritoViewSet(viewsets.ViewSet):
    permission_classes = [permissions.IsAuthenticated]

    def list(self, request):
        carrito, _ = Carrito.objects.get_or_create(usuario=request.user)
        serializer = CarritoSerializer(carrito)
        return Response(serializer.data)

    @action(detail=False, methods=['post'])
    def agregar_item(self, request):
        producto_id = request.data.get('producto_id')
        try:
            cantidad = int(request.data.get('cantidad', 1))
        except (TypeError, ValueError):
            return Response({'error': 'Cantidad inválida'}, status=400)
        if cantidad <= 0:
            return Response({'error': 'La cantidad debe ser mayor a 0'}, status=400)

        try:
            producto = Producto.objects.get(id=producto_id)
        except Producto.DoesNotExist:
            return Response({'error': 'Producto no encontrado'}, status=404)

        carrito, _ = Carrito.objects.get_or_create(usuario=request.user)
        item, creado = ItemCarrito.objects.get_or_create(
            carrito=carrito,
            producto=producto,
            defaults={'cantidad': cantidad},
        )
        if not creado:
            item.cantidad += cantidad
            item.save()

        serializer = CarritoSerializer(carrito)
        return Response(serializer.data, status=201 if creado else 200)

    @action(detail=False, methods=['patch'])
    def actualizar_item(self, request):
        item_id = request.data.get('item_id')
        try:
            cantidad = int(request.data.get('cantidad', 1))
        except (TypeError, ValueError):
            return Response({'error': 'Cantidad inválida'}, status=400)

        try:
            item = ItemCarrito.objects.get(id=item_id, carrito__usuario=request.user)
        except ItemCarrito.DoesNotExist:
            return Response({'error': 'Item no encontrado'}, status=404)

        if cantidad <= 0:
            item.delete()
        else:
            item.cantidad = cantidad
            item.save()

        carrito = item.carrito
        serializer = CarritoSerializer(carrito)
        return Response(serializer.data)

    @action(detail=False, methods=['delete'])
    def eliminar_item(self, request):
        item_id = request.data.get('item_id')
        try:
            item = ItemCarrito.objects.get(id=item_id, carrito__usuario=request.user)
        except ItemCarrito.DoesNotExist:
            return Response({'error': 'Item no encontrado'}, status=404)

        carrito = item.carrito
        item.delete()
        serializer = CarritoSerializer(carrito)
        return Response(serializer.data)

    @action(detail=False, methods=['delete'])
    def vaciar(self, request):
        carrito, _ = Carrito.objects.get_or_create(usuario=request.user)
        carrito.items.all().delete()
        serializer = CarritoSerializer(carrito)
        return Response(serializer.data)


@api_view(['GET'])
@permission_classes([permissions.AllowAny])
def supabase_health(request):
    supabase_url = settings.SUPABASE_REST_URL
    api_key = settings.SUPABASE_API_KEY

    req = urlrequest.Request(
        supabase_url,
        headers={
            'apikey': api_key,
            'Authorization': f'Bearer {api_key}',
            'Accept': 'application/json',
        },
        method='GET',
    )

    try:
        with urlrequest.urlopen(req, timeout=10) as response:
            body = response.read().decode('utf-8')
            parsed_body = json.loads(body) if body else {}
            return Response(
                {
                    'connected': True,
                    'supabase_status': response.status,
                    'supabase_url': supabase_url,
                    'data': parsed_body,
                },
                status=200,
            )
    except HTTPError as error:
        error_body = error.read().decode('utf-8', errors='replace')
        return Response(
            {
                'connected': False,
                'supabase_status': error.code,
                'supabase_url': supabase_url,
                'error': error_body,
            },
            status=502,
        )
    except URLError as error:
        return Response(
            {
                'connected': False,
                'supabase_status': None,
                'supabase_url': supabase_url,
                'error': str(error.reason),
            },
            status=502,
        )
