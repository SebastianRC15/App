import random
import json
from urllib import request as urlrequest
from urllib.error import HTTPError, URLError
from django.conf import settings
from datetime import timedelta
from django.core.mail import send_mail
from django.utils import timezone
from django.core import signing
from django.db.utils import OperationalError
from django.db import connection
from rest_framework import viewsets, status, permissions
from rest_framework.decorators import action, api_view, permission_classes
from rest_framework.response import Response
from .models import Usuario, Producto, Categoria, Carrito, ItemCarrito, Pedido, DetallePedido, HistorialBilletera, RecompensaDiaria, RegistroReferido
from .serializers import (
    UsuarioSerializer, ProductoSerializer, CategoriaSerializer, CarritoSerializer,
    PedidoSerializer, HistorialBilleteraSerializer, RecompensaDiariaSerializer
)

from google.oauth2 import id_token
from google.auth.transport import requests as google_requests
from rest_framework_simplejwt.tokens import RefreshToken

class UsuarioViewSet(viewsets.ModelViewSet):
    queryset = Usuario.objects.all()
    serializer_class = UsuarioSerializer

    def get_permissions(self):
        if self.action in ['create', 'google_login', 'verify_email', 'password_reset_request', 'password_reset_confirm', 'resend_verification']:
            return [permissions.AllowAny()]
        return [permissions.IsAuthenticated()]

    def get_queryset(self):
        if self.request.user.is_staff:
            return Usuario.objects.all()
        return Usuario.objects.filter(id=self.request.user.id)

    @action(detail=False, methods=['get'])
    def mi_perfil(self, request):
        serializer = self.get_serializer(request.user)
        return Response(serializer.data)

    @action(detail=False, methods=['post'])
    def google_login(self, request):
        token = request.data.get('id_token')
        client_id = getattr(settings, 'GOOGLE_CLIENT_ID', '')
        
        if not token:
            return Response({'error': 'id_token es requerido'}, status=400)
        if not client_id:
            return Response({'error': 'GOOGLE_CLIENT_ID no está configurado en el servidor'}, status=500)

        try:
            idinfo = id_token.verify_oauth2_token(token, google_requests.Request(), client_id)

            if idinfo['iss'] not in ['accounts.google.com', 'https://accounts.google.com']:
                raise ValueError('Wrong issuer.')

            # Obtener o crear usuario
            email = idinfo['email']
            user, created = Usuario.objects.get_or_create(
                correo_electronico=email,
                defaults={
                    'username': email,
                    'nombre_completo': idinfo.get('name', ''),
                    'first_name': idinfo.get('given_name', ''),
                    'last_name': idinfo.get('family_name', ''),
                }
            )

            # Generar JWT para el usuario
            refresh = RefreshToken.for_user(user)
            return Response({
                'refresh': str(refresh),
                'access': str(refresh.access_token),
                'user': UsuarioSerializer(user).data
            })

        except ValueError as e:
            return Response({'error': f'Token inválido: {str(e)}'}, status=400)
        except Exception as e:
            return Response({'error': f'Error en autenticación Google: {str(e)}'}, status=500)

    @action(detail=False, methods=['post'])
    def canjear_referido(self, request):
        codigo = request.data.get('codigo')
        user = request.user
        try:
            anfitrion = Usuario.objects.get(codigo_referido_propio=codigo)
            
            # CONTROL DE FRAUDE
            if anfitrion == user:
                return Response({'error': 'No puedes referirte a ti mismo'}, status=400)
            
            if RegistroReferido.objects.filter(invitado=user).exists():
                return Response({'error': 'Ya has sido referido anteriormente'}, status=400)

            # Opcional: Solo permitir referidos si la cuenta del invitado tiene cierta antigüedad
            # o si el anfitrión tiene cuenta verificada.
            
            RegistroReferido.objects.create(anfitrion=anfitrion, invitado=user)
            
            # Lógica de recompensas: El anfitrión recibe el premio
            anfitrion.saldo_disponible += 1.00
            anfitrion.save()
            
            # El invitado también podría recibir un pequeño bono inicial
            user.saldo_disponible += 0.50
            user.save()

            return Response({'message': '¡Código aplicado! Tú ganaste S/ 0.50 y tu amigo S/ 1.00'})
        except Usuario.DoesNotExist:
            return Response({'error': 'Código inválido'}, status=404)

    def create(self, request, *args, **kwargs):
        try:
            response = super().create(request, *args, **kwargs)
        except OperationalError as e:
            return Response(
                {
                    'error': 'Error de base de datos (OperationalError). Verifica DATABASE_URL y que las migraciones estén aplicadas.',
                    'detail': str(e),
                },
                status=503,
            )
        except Exception as e:
            return Response(
                {
                    'error': 'Error interno del servidor al registrar.',
                    'type': e.__class__.__name__,
                    'detail': str(e) if getattr(settings, 'DEBUG', False) else 'Revisa los logs del servidor.',
                },
                status=500,
            )
        try:
            if response.status_code in (200, 201):
                payload = response.data if isinstance(response.data, dict) else {}
                user_id = payload.get('id')
                if user_id:
                    user = Usuario.objects.filter(id=user_id).first()
                else:
                    user = Usuario.objects.filter(correo_electronico=request.data.get('correo_electronico')).first()
                if user:
                    token = signing.dumps({'uid': str(user.id), 'email': user.correo_electronico}, salt='email-verify')
                    link = f"{settings.BACKEND_PUBLIC_URL}/api/usuarios/verify_email/?token={token}"
                    send_mail(
                        subject='Verifica tu correo',
                        message=f'Para activar tu cuenta, abre este enlace:\n\n{link}\n\nSi no solicitaste esto, ignora este mensaje.',
                        from_email=settings.DEFAULT_FROM_EMAIL,
                        recipient_list=[user.correo_electronico],
                        fail_silently=True,
                    )
        except Exception:
            pass
        return response

    @action(detail=False, methods=['post'])
    def resend_verification(self, request):
        email = request.data.get('correo_electronico') or request.data.get('email')
        if not email:
            return Response({'error': 'correo_electronico es requerido'}, status=400)
        user = Usuario.objects.filter(correo_electronico=email).first()
        if user and not user.is_active:
            token = signing.dumps({'uid': str(user.id), 'email': user.correo_electronico}, salt='email-verify')
            link = f"{settings.BACKEND_PUBLIC_URL}/api/usuarios/verify_email/?token={token}"
            send_mail(
                subject='Verifica tu correo',
                message=f'Para activar tu cuenta, abre este enlace:\n\n{link}\n\nSi no solicitaste esto, ignora este mensaje.',
                from_email=settings.DEFAULT_FROM_EMAIL,
                recipient_list=[user.correo_electronico],
                fail_silently=True,
            )
        return Response({'message': 'Si el correo existe, se reenvió el mensaje de verificación.'})

    @action(detail=False, methods=['get'])
    def verify_email(self, request):
        token = request.query_params.get('token') or request.data.get('token')
        if not token:
            return Response({'error': 'token es requerido'}, status=400)
        try:
            data = signing.loads(token, salt='email-verify', max_age=60 * 60 * 24)
            uid = data.get('uid')
            email = data.get('email')
            user = Usuario.objects.filter(id=uid, correo_electronico=email).first()
            if not user:
                return Response({'error': 'Token inválido'}, status=400)
            if not user.is_active:
                user.is_active = True
                user.save(update_fields=['is_active'])
            return Response({'message': 'Correo verificado. Ya puedes iniciar sesión.'})
        except signing.SignatureExpired:
            return Response({'error': 'Token expirado'}, status=400)
        except signing.BadSignature:
            return Response({'error': 'Token inválido'}, status=400)

    @action(detail=False, methods=['post'])
    def password_reset_request(self, request):
        email = request.data.get('correo_electronico') or request.data.get('email')
        if not email:
            return Response({'error': 'correo_electronico es requerido'}, status=400)
        user = Usuario.objects.filter(correo_electronico=email).first()
        if user:
            token = signing.dumps({'uid': str(user.id), 'email': user.correo_electronico}, salt='pwd-reset')
            send_mail(
                subject='Recuperación de contraseña',
                message=f'Usa este token para restablecer tu contraseña:\n\n{token}\n\nSi no solicitaste esto, ignora este mensaje.',
                from_email=settings.DEFAULT_FROM_EMAIL,
                recipient_list=[user.correo_electronico],
                fail_silently=True,
            )
        return Response({'message': 'Si el correo existe, se envió un mensaje de recuperación.'})

    @action(detail=False, methods=['post'])
    def password_reset_confirm(self, request):
        token = request.data.get('token')
        new_password = request.data.get('new_password')
        if not token or not new_password:
            return Response({'error': 'token y new_password son requeridos'}, status=400)
        try:
            data = signing.loads(token, salt='pwd-reset', max_age=60 * 30)
            uid = data.get('uid')
            email = data.get('email')
            user = Usuario.objects.filter(id=uid, correo_electronico=email).first()
            if not user:
                return Response({'error': 'Token inválido'}, status=400)
            user.set_password(new_password)
            user.save(update_fields=['password'])
            return Response({'message': 'Contraseña actualizada.'})
        except signing.SignatureExpired:
            return Response({'error': 'Token expirado'}, status=400)
        except signing.BadSignature:
            return Response({'error': 'Token inválido'}, status=400)

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

    @action(detail=True, methods=['post'])
    def confirmar_pago(self, request, pk=None):
        pedido = self.get_object()
        
        # Simulación de validación de pago (ej. verificar con pasarela)
        # En un caso real, aquí recibiríamos un ID de transacción o webhook
        transaccion_id = request.data.get('transaccion_id')
        
        if not transaccion_id:
            return Response({'error': 'ID de transacción requerido para validar el pago'}, status=400)
        
        # Lógica de validación (Mock)
        if transaccion_id.startswith('TEST_OK'):
            pedido.estado_pedido = 'pagado'
            pedido.save()
            return Response({'message': 'Pago confirmado con éxito', 'estado': pedido.estado_pedido})
        else:
            return Response({'error': 'La validación del pago falló. Transacción no encontrada o rechazada.'}, status=400)

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


@api_view(['GET'])
@permission_classes([permissions.AllowAny])
def google_health(request):
    client_id = getattr(settings, 'GOOGLE_CLIENT_ID', '')
    return Response({'configured': bool(client_id)})


@api_view(['GET'])
@permission_classes([permissions.AllowAny])
def db_health(request):
    try:
        with connection.cursor() as cursor:
            cursor.execute('SELECT 1;')
            cursor.fetchone()
        return Response({'status': 'ok'})
    except OperationalError as e:
        return Response({'status': 'error', 'error': 'OperationalError', 'detail': str(e)}, status=503)
    except Exception as e:
        return Response({'status': 'error', 'error': e.__class__.__name__, 'detail': str(e)}, status=500)
