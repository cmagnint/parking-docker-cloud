
from tokenize import String
from django.contrib.auth import authenticate
from datetime import datetime, time, timedelta
from django.core.mail import send_mail, EmailMessage
from django.shortcuts import get_object_or_404
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from django.db.models import Q, F
from django.utils import timezone
import pandas as pd
from oauth2_provider.settings import oauth2_settings
from math import trunc, ceil
from django.core.exceptions import ObjectDoesNotExist
from oauth2_provider.models import AccessToken, Application
from oauth2_provider.contrib.rest_framework import OAuth2Authentication
import pytz
import json
import random
from oauthlib.common import generate_token
import secrets
from rest_framework.permissions import IsAuthenticated, AllowAny
from .permissions import TokenHasAnyScope

from .models import (
    ClientesRegistrados,
    Servicios,
    Usuario,
    Registro,
    Sociedad,
    Parametro,
    Servicios,
    RegistroServicios,
    ClientesServicios,
    TipoVehiculo,
)

from .serializers import (
    ClientesRegistradosSerializer,
    LoginSerializer,
    UsuarioSerializer,
    ServiciosSerializer,
    RegistroServiciosSerializer,
    ClientesServiciosSerializer,
    TipoVehiculoSerializer,
)

def hora_santiago():
    return timezone.now().astimezone(pytz.timezone('America/Santiago'))

#-------------------------------LOGIN------------------------------------------
class CheckTokenView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]
    
    def post(self, request):
        token = request.data.get('token')
        
        if not token:
            return Response({
                'status': 'error', 
                'message': 'Token requerido',
                'valid': False
            }, status=status.HTTP_400_BAD_REQUEST)
        
        try:
            # Buscar el token en la base de datos
            access_token = AccessToken.objects.get(token=token)
            
            # Verificar si el token no ha expirado
            if access_token.expires > timezone.now():
                # Token válido, devolver información del usuario
                usuario = access_token.user
                sociedad_id = usuario.sociedad.id if usuario.sociedad else None
                
                # Obtener parámetros
                parametro = None
                if sociedad_id:
                    parametro = Parametro.objects.filter(sociedad_id=sociedad_id).first()
                
                return Response({
                    'status': 'success',
                    'valid': True,
                    'admin': usuario.is_admin,
                    'sociedad_id': sociedad_id,
                    'correo': usuario.correo,
                    'superadmin': usuario.is_superadmin,
                    'name': usuario.nombre,
                    'rut': usuario.rut,
                    'expires': access_token.expires,
                    'intervalo_parametro': parametro.intervalo_minutos if parametro else None,
                    'valor_parametro': parametro.monto_por_intervalo if parametro else None,
                    'monto_minimo': parametro.monto_minimo if parametro else None,
                    'intervalo_minimo': parametro.intervalo_minimo if parametro else None,
                })
            else:
                # Token expirado
                return Response({
                    'status': 'error',
                    'message': 'Token expirado',
                    'valid': False
                }, status=status.HTTP_401_UNAUTHORIZED)
                
        except AccessToken.DoesNotExist:
            # Token no existe
            return Response({
                'status': 'error',
                'message': 'Token inválido',
                'valid': False
            }, status=status.HTTP_401_UNAUTHORIZED)
        
class LoginView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]
    
    def post(self, request):
        print(request.data)
        serializer = LoginSerializer(data=request.data)
        if serializer.is_valid():
            user = authenticate(
                username=serializer.validated_data['rut'], # type: ignore
                password=serializer.validated_data['password'] # type: ignore
            )
            if user is not None and user.is_active:
                # Obtener datos del usuario
                usuario = Usuario.objects.filter(id=user.id).first() # type: ignore
                
                # Obtener información del cliente
                id_sociedad = usuario.sociedad.id if usuario is not None and usuario.sociedad is not None and usuario.sociedad.id is not None else None
                 
                # Obtener parámetros
                parametro = Parametro.objects.filter(sociedad_id=id_sociedad).first()
                intervalo_parametro = parametro.intervalo_minutos if parametro else None
                valor_parametro = parametro.monto_por_intervalo if parametro else None
                
                # Crear token de acceso
                token = self.create_access_token(user)
                
                return Response({
                    'status': 'success',
                    'message': 'Inicio de sesión exitoso',
                    'admin': usuario.is_admin,
                    'rut': usuario.rut, 
                    'sociedad_id': id_sociedad,
                    'correo': usuario.correo, # type: ignore
                    'superadmin': usuario.is_superadmin, # type: ignore
                    'token': token.token,
                    'token_expires': token.expires,
                    'intervalo_parametro': intervalo_parametro,
                    'valor_parametro': valor_parametro
                })
            
            else:
                return Response({'status': 'error', 'message': 'Usuario o contraseña incorrectos'}, status=status.HTTP_401_UNAUTHORIZED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

   
    def create_access_token(self, user):
        app = Application.objects.get(client_id="k0zgOA8ivuyxvPlEEhxO4XADLAb8uqYbA9Fs8zpd")
        expires = timezone.now() + timedelta(seconds=oauth2_settings.ACCESS_TOKEN_EXPIRE_SECONDS) # type: ignore
        
        if user.is_superuser:
            user_scope = 'superadmin_access'
        elif user.is_admin:
            user_scope = 'admin'
        else:
            user_scope = 'write'
        
        token = AccessToken.objects.create(
            user=user,
            application=app,
            token=generate_token(),
            expires=expires,
            scope=user_scope  
        )
        return token

class GenerarCodigoView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]

    def post(self, request):
        data = (request.data)
        rut = data['rut']
        print(rut)
        usuario = Usuario.objects.filter(rut=rut).first()
        if usuario:
            codigo = ''.join([str(random.randint(0, 9)) for _ in range(6)])
            usuario.codigo = codigo
            usuario.codigo_expiracion = timezone.now() + timedelta(hours=3)
            usuario.save()

            send_mail(
                'Tu código de verificación',
                f'Tu código es: {codigo}',
                'contacto.terrasoft.23@gmail.com',
                [usuario.correo],
                fail_silently=False,
            )
            return Response({'status': 'success', 'message': 'Codigo enviado exitosamente.'})
        else:
            return Response({'status': 'error', 'message': 'RUT no encontrado.'})

class VerificarCodigoView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]

    def post(self, request):
        data = request.data
        rut = data['rut']
        codigo = data['codigo']
        usuario = Usuario.objects.filter(rut=rut, codigo=codigo).first()
        if usuario:
            if usuario.codigo_expiracion and usuario.codigo_expiracion > timezone.now():
                return Response({'status': 'success', 'message': 'Codigo verificado exitosamente.'})
            else:
                return Response({'status': 'error', 'message': 'El codigo ha expirado.'})
        else:
            return Response({'status': 'error', 'message': 'RUT o codigo incorrectos.'})

class CambiarContrasenaView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]

    def post(self, request):
        data = request.data
        rut = data['rut']
        nuevaContrasena = data['nuevaContrasena']

        usuario = Usuario.objects.filter(rut=rut).first()

        if usuario:
            usuario.set_password(nuevaContrasena)
            usuario.save()
            return Response({'status': 'success', 'message': 'Contrasena actualizada con exito.'})
        else:
            return Response({'status': 'error', 'message': 'Usuario no encontrado.'})

#|===================================================================================|
#|---------------------------SUPERADMINISTRACION-------------------------------------|
#|===================================================================================|

class ConsultarRegistrosSociedadView(APIView):
    """
    Vista para consultar registros de una sociedad por rango de fechas
    GET: Obtener resumen y detalle de registros
    """
    authentication_classes = [OAuth2Authentication]
    permission_classes = [IsAuthenticated, TokenHasAnyScope]

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.required_scopes = []

    def dispatch(self, request, *args, **kwargs):
        if request.method == 'GET':
            self.required_scopes = ['superadmin_access', 'write']
        return super().dispatch(request, *args, **kwargs)

    def get(self, request):
        """
        GET: Obtener registros de una sociedad por rango de fechas
        
        Query params:
        - sociedad_id: ID de la sociedad
        - fecha_inicio: Fecha inicio en formato DD/MM/YYYY
        - fecha_fin: Fecha fin en formato DD/MM/YYYY
        """
        try:
            sociedad_id = request.query_params.get('sociedad_id')
            fecha_inicio_str = request.query_params.get('fecha_inicio')
            fecha_fin_str = request.query_params.get('fecha_fin')

            if not all([sociedad_id, fecha_inicio_str, fecha_fin_str]):
                return Response({
                    'status': 'error',
                    'message': 'Faltan parámetros requeridos: sociedad_id, fecha_inicio, fecha_fin'
                }, status=status.HTTP_400_BAD_REQUEST)

            # Verificar que la sociedad existe
            try:
                sociedad = Sociedad.objects.get(id=sociedad_id)
            except Sociedad.DoesNotExist:
                return Response({
                    'status': 'error',
                    'message': f'Sociedad con ID {sociedad_id} no encontrada'
                }, status=status.HTTP_404_NOT_FOUND)

            # Parsear fechas
            try:
                fecha_inicio = datetime.strptime(fecha_inicio_str, '%d/%m/%Y')
                fecha_fin = datetime.strptime(fecha_fin_str, '%d/%m/%Y')
                
                # Ajustar fecha_fin para incluir todo el día
                fecha_fin = fecha_fin.replace(hour=23, minute=59, second=59)
            except ValueError:
                return Response({
                    'status': 'error',
                    'message': 'Formato de fecha inválido. Use DD/MM/YYYY'
                }, status=status.HTTP_400_BAD_REQUEST)

            # Obtener registros del rango de fechas para esta sociedad
            registros = Registro.objects.filter(
                sociedad_id=sociedad_id,
                hora_inicio__gte=fecha_inicio,
                hora_inicio__lte=fecha_fin
            ).select_related('usuario_registrador', 'cliente_registrado').order_by('-hora_inicio')

            # Preparar datos de resumen
            total_registros = registros.count()
            total_ingresos = sum(
                registro.tarifa if registro.tarifa else 0 
                for registro in registros
            )

            # Preparar lista de registros detallados
            registros_detalle = []
            for registro in registros:
                registros_detalle.append({
                    'id': registro.id,
                    'patente': registro.patente,
                    'hora_inicio': registro.hora_inicio.strftime('%d/%m/%Y %H:%M:%S'),
                    'hora_termino': registro.hora_termino.strftime('%d/%m/%Y %H:%M:%S') if registro.hora_termino else None,
                    'tarifa': float(registro.tarifa) if registro.tarifa else 0,
                    'cancelado': float(registro.cancelado) if registro.cancelado else 0,
                    'saldo': float(registro.saldo) if registro.saldo else 0,
                    'rut_trabajador': registro.usuario_registrador.rut,
                    'nombre_trabajador': registro.usuario_registrador.nombre,
                    'cliente_registrado': {
                        'nombre': registro.cliente_registrado.nombre_cliente,
                        'rut': registro.cliente_registrado.rut_cliente,
                        'tipo': registro.cliente_registrado.tipo
                    } if registro.cliente_registrado else None
                })

            return Response({
                'status': 'success',
                'data': {
                    'sociedad': {
                        'id': sociedad.id,
                        'nombre': sociedad.razon_social,
                        'rut': sociedad.rut_formateado
                    },
                    'periodo': {
                        'fecha_inicio': fecha_inicio_str,
                        'fecha_fin': fecha_fin_str
                    },
                    'resumen': {
                        'total_registros': total_registros,
                        'total_ingresos': round(total_ingresos, 2)
                    },
                    'registros': registros_detalle
                }
            })

        except Exception as e:
            print(f"Error en ConsultarRegistrosSociedadView: {str(e)}")
            import traceback
            traceback.print_exc()
            return Response({
                'status': 'error',
                'message': f'Error interno del servidor: {str(e)}'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
            
class AdministrarSociedadView(APIView):
    """
    Endpoint RESTful completo para administrar sociedades
    GET: Listar todas las sociedades o una específica por ID
    POST: Crear una nueva sociedad
    PUT: Modificar una sociedad existente
    """
    authentication_classes = [OAuth2Authentication]
    permission_classes = [IsAuthenticated, TokenHasAnyScope]

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.required_scopes = []

    def dispatch(self, request, *args, **kwargs):
        if request.method in ['POST', 'PUT', 'PATCH']:
            self.required_scopes = ['superadmin_access', 'write']
        elif request.method == 'GET':
            self.required_scopes = ['superadmin_access', 'write']
        return super().dispatch(request, *args, **kwargs)

    def get(self, request, sociedad_id=None):
        """
        GET: Obtener todas las sociedades o una específica
        
        URL: /administrar_sociedad/ - Lista todas
        URL: /administrar_sociedad/<id>/ - Obtiene una específica
        """
        try:
            # Si se proporciona ID, devolver una sociedad específica
            if sociedad_id:
                try:
                    sociedad = Sociedad.objects.get(id=sociedad_id)
                    usuario_admin = Usuario.objects.filter(
                        sociedad_id=sociedad.id,  # CORREGIDO: era cliente_id
                        is_admin=True
                    ).first()
                    
                    # Contar usuarios
                    total_usuarios = Usuario.objects.filter(
                        sociedad_id=sociedad.id,  # CORREGIDO: era cliente_id
                        is_admin=False
                    ).count()
                    
                    usuarios_activos = Usuario.objects.filter(
                        sociedad_id=sociedad.id,  # CORREGIDO: era cliente_id
                        is_admin=False,
                        estado='ACT'  # CORREGIDO: era 'ON'
                    ).count()
                    
                    data_sociedad = {
                        'id': sociedad.id,
                        'tipo_cliente': sociedad.tipo_cliente,
                        'razon_social': sociedad.razon_social,
                        'rut_sociedad': sociedad.rut_sociedad,
                        'rut_formateado': sociedad.rut_formateado,
                        'giro': sociedad.giro,
                        # Representante legal
                        'rut_representante': sociedad.rut_representante,
                        'rut_representante_formateado': sociedad.rut_representante_formateado,
                        'nombre_representante': sociedad.nombre_representante,
                        'correo': sociedad.correo,
                        'telefono': sociedad.telefono,
                        # Ubicación
                        'direccion': sociedad.direccion,
                        'comuna': sociedad.comuna,
                        'ciudad': sociedad.ciudad,
                        'region': sociedad.region,
                        'nota': sociedad.nota,
                        # Estado
                        'estado': sociedad.estado,
                        'activo': sociedad.activo,
                        'fecha_registro': sociedad.fecha_registro,
                        # Usuario admin
                        'correo_admin': usuario_admin.correo if usuario_admin else '',
                        'nombre_admin': usuario_admin.nombre if usuario_admin else '',
                        'rut_admin': usuario_admin.rut if usuario_admin else '',
                        'estado_admin': usuario_admin.estado if usuario_admin else 'INA',
                        # Contadores
                        'total_usuarios': total_usuarios,
                        'usuarios_activos': usuarios_activos
                    }
                    
                    return Response({
                        'status': 'success',
                        'sociedad': data_sociedad
                    })
                    
                except Sociedad.DoesNotExist:
                    return Response({
                        'status': 'error',
                        'message': 'Sociedad no encontrada'
                    }, status=status.HTTP_404_NOT_FOUND)
            
            # Si no hay ID, devolver todas las sociedades
            sociedades = Sociedad.objects.all()
            data_sociedades = []
            
            for sociedad in sociedades:
                usuario_admin = Usuario.objects.filter(
                    sociedad_id=sociedad.id,  # CORREGIDO: era cliente_id
                    is_admin=True
                ).first()
                
                total_usuarios = Usuario.objects.filter(
                    sociedad_id=sociedad.id,  # CORREGIDO: era cliente_id
                    is_admin=False
                ).count()
                
                usuarios_activos = Usuario.objects.filter(
                    sociedad_id=sociedad.id,  # CORREGIDO: era cliente_id
                    is_admin=False,
                    estado='ACT'  # CORREGIDO: era 'ON'
                ).count()
                
                data_sociedades.append({
                    'id': sociedad.id,
                    'tipo_cliente': sociedad.tipo_cliente,
                    'razon_social': sociedad.razon_social,
                    'rut_sociedad': sociedad.rut_sociedad,
                    'rut_formateado': sociedad.rut_formateado,
                    'nombre_representante': sociedad.nombre_representante,
                    'estado': sociedad.estado,
                    'activo': sociedad.activo,
                    'correo_admin': usuario_admin.correo if usuario_admin else '',
                    'nombre_admin': usuario_admin.nombre if usuario_admin else '',
                    'estado_admin': usuario_admin.estado if usuario_admin else 'INA',
                    'total_usuarios': total_usuarios,
                    'usuarios_activos': usuarios_activos
                })
            
            return Response({
                'status': 'success',
                'sociedades': data_sociedades,
                'total': len(data_sociedades)
            })
            
        except Exception as e:
            print(f"Error en GET sociedades: {str(e)}")
            import traceback
            traceback.print_exc()
            return Response({
                'status': 'error',
                'message': f'Error al obtener sociedades: {str(e)}'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    def post(self, request):
        """
        POST: Crear una nueva sociedad con su usuario administrador
        
        Body JSON requerido:
        {
            "tipo_cliente": "SOCIEDAD",  // o "PERSONA"
            
            // Campos del representante legal (SIEMPRE OBLIGATORIOS):
            "rut_representante": "123456789",
            "nombre_representante": "Juan Pérez",
            "correo": "juan@email.com",
            "telefono": "+56912345678",  // Opcional
            
            // Campos de la sociedad (SOLO SI tipo_cliente=SOCIEDAD):
            "razon_social": "Empresa SpA",  // Obligatorio si SOCIEDAD
            "rut_sociedad": "987654321",    // Obligatorio si SOCIEDAD
            "giro": "Servicios TI",         // Opcional
            
            // Campos comunes (SIEMPRE OBLIGATORIOS):
            "direccion": "Av. Principal 123",
            "comuna": "Santiago",
            "ciudad": "Santiago",
            "region": "Metropolitana",
            "nota": "Observaciones",  // Opcional
            "estado": "ACTIVO"  // Opcional: ACTIVO, INACTIVO, PRUEBA
        }
        """
        try:
            # Usar request.data en lugar de request.body
            data = request.data
            
            if not data:
                return Response({
                    'status': 'error',
                    'message': 'No se proporcionaron datos'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Obtener tipo de cliente
            tipo_cliente = data.get('tipo_cliente', 'SOCIEDAD')
            
            # Validar tipo de cliente
            if tipo_cliente not in ['SOCIEDAD', 'PERSONA']:
                return Response({
                    'status': 'error',
                    'message': 'Tipo de cliente debe ser SOCIEDAD o PERSONA'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Campos siempre obligatorios (representante legal y ubicación)
            campos_siempre_requeridos = [
                'rut_representante', 'nombre_representante', 'correo',
                'direccion', 'comuna', 'ciudad', 'region'
            ]
            
            # Si es SOCIEDAD, agregar campos adicionales obligatorios
            if tipo_cliente == 'SOCIEDAD':
                campos_siempre_requeridos.extend(['razon_social', 'rut_sociedad'])
            
            # Validar campos requeridos
            campos_faltantes = [campo for campo in campos_siempre_requeridos if campo not in data or not str(data[campo]).strip()]
            
            if campos_faltantes:
                return Response({
                    'status': 'error',
                    'message': f'Campos requeridos faltantes: {", ".join(campos_faltantes)}'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Limpiar datos obligatorios
            rut_representante = data['rut_representante'].strip()
            nombre_representante = data['nombre_representante'].strip()
            correo = data['correo'].strip().lower()
            telefono = data.get('telefono', '').strip()
            
            direccion = data['direccion'].strip()
            comuna = data['comuna'].strip()
            ciudad = data['ciudad'].strip()
            region = data['region'].strip()
            nota = data.get('nota', '').strip()
            estado = data.get('estado', 'PRUEBA')
            
            # Campos específicos de SOCIEDAD
            razon_social = data.get('razon_social', '').strip() if tipo_cliente == 'SOCIEDAD' else nombre_representante
            rut_sociedad = data.get('rut_sociedad', '').strip() if tipo_cliente == 'SOCIEDAD' else None
            giro = data.get('giro', '').strip() if tipo_cliente == 'SOCIEDAD' else None
            
            # Validar formato de correo
            if '@' not in correo or '.' not in correo:
                return Response({
                    'status': 'error',
                    'message': 'Formato de correo inválido'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Validar RUT representante (debe tener 7-9 dígitos)
            if not rut_representante.isdigit() or len(rut_representante) < 7 or len(rut_representante) > 9:
                return Response({
                    'status': 'error',
                    'message': 'RUT del representante debe contener entre 7 y 9 dígitos'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Si es SOCIEDAD, validar RUT de sociedad
            if tipo_cliente == 'SOCIEDAD':
                if not rut_sociedad.isdigit() or len(rut_sociedad) < 7 or len(rut_sociedad) > 9:
                    return Response({
                        'status': 'error',
                        'message': 'RUT de la sociedad debe contener entre 7 y 9 dígitos'
                    }, status=status.HTTP_400_BAD_REQUEST)
                
                # Verificar si ya existe la sociedad con ese RUT
                if Sociedad.objects.filter(rut_sociedad=rut_sociedad).exists():
                    return Response({
                        'status': 'error',
                        'message': f'Ya existe una sociedad registrada con RUT {rut_sociedad}'
                    }, status=status.HTTP_400_BAD_REQUEST)
            
            # Validar estado
            if estado not in ['ACTIVO', 'INACTIVO', 'PRUEBA']:
                return Response({
                    'status': 'error',
                    'message': 'Estado debe ser ACTIVO, INACTIVO o PRUEBA'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Verificar si ya existe el RUT del representante
            if Sociedad.objects.filter(rut_representante=rut_representante).exists():
                return Response({
                    'status': 'error',
                    'message': f'Ya existe un registro con el RUT de representante {rut_representante}'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Verificar si ya existe el correo
            if Usuario.objects.filter(correo=correo).exists():
                return Response({
                    'status': 'error',
                    'message': f'El correo {correo} ya está registrado'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Separar RUT y DV del representante para crear usuario
            rut_representante = rut_representante
            
            # Verificar si ya existe el RUT de usuario
            if Usuario.objects.filter(rut=rut_representante).exists():
                return Response({
                    'status': 'error',
                    'message': f'El RUT {rut_representante} ya está registrado como usuario'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Crear la sociedad
            sociedad = Sociedad.objects.create(
                tipo_cliente=tipo_cliente,
                # Representante legal (siempre)
                rut_representante=rut_representante,
                nombre_representante=nombre_representante,
                correo=correo,
                telefono=telefono if telefono else None,
                # Sociedad (solo si aplica)
                razon_social=razon_social,
                rut_sociedad=rut_sociedad,
                giro=giro if giro else None,
                # Ubicación
                direccion=direccion,
                comuna=comuna,
                ciudad=ciudad,
                region=region,
                nota=nota if nota else None,
                # Estado
                estado=estado,
                activo=True
            )
            
            # Crear el usuario administrador (usando datos del representante)
            usuario_admin = Usuario.objects.create(
                nombre=nombre_representante,
                rut=rut_representante,
                correo=correo,
                sociedad_id=sociedad.id,
                estado='ACT' if estado == 'ACTIVO' else 'INA',
                is_admin=True,
                is_superadmin=False
            )
            
            # Generar contraseña aleatoria
            random_password = secrets.token_urlsafe(16)
            usuario_admin.set_password(random_password)
            usuario_admin.save()
            
            # Crear parámetros por defecto para el cliente
            Parametro.objects.create(
                sociedad=sociedad,
                monto_por_intervalo=1000,  # Valores por defecto
                intervalo_minutos=30,
                monto_minimo=500,
                intervalo_minimo=15
            )
            
            nombre_cliente = razon_social if tipo_cliente == 'SOCIEDAD' else nombre_representante
            print(f"Cliente creado: {nombre_cliente} (ID: {sociedad.id}, Tipo: {tipo_cliente})")
            print(f"Usuario admin creado: {usuario_admin.nombre} (RUT: {usuario_admin.rut})")
            print(f"Contraseña generada: {random_password}")
            
            return Response({
                'status': 'success',
                'message': f'Cliente "{nombre_cliente}" creado exitosamente',
                'sociedad': {
                    'id': sociedad.id,
                    'tipo_cliente': sociedad.tipo_cliente,
                    'razon_social': sociedad.razon_social,
                    'rut_sociedad': sociedad.rut_sociedad,
                    'rut_representante': sociedad.rut_representante,
                    'nombre_representante': sociedad.nombre_representante,
                    'rut_formateado': sociedad.rut_formateado,
                    'estado': sociedad.estado
                },
                'usuario_admin': {
                    'nombre': usuario_admin.nombre,
                    'correo': usuario_admin.correo,
                    'rut': f"{usuario_admin.rut}",
                    'password_temporal': random_password
                }
            }, status=status.HTTP_201_CREATED)
            
        except Exception as e:
            print(f"Error al crear sociedad: {str(e)}")
            import traceback
            traceback.print_exc()
            return Response({
                'status': 'error',
                'message': f'Error interno del servidor: {str(e)}'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    def put(self, request, sociedad_id=None):
        """
        PUT: Modificar una sociedad existente y/o su usuario administrador
        
        URL: /administrar_sociedad/<id>/
        
        Body JSON (todos opcionales):
        {
            "razon_social": "Nuevo nombre",
            "giro": "Nuevo giro",
            "direccion": "Nueva dirección",
            "comuna": "Nueva comuna",
            "ciudad": "Nueva ciudad",
            "region": "Nueva región",
            "telefono_empresa": "+56987654321",
            "nota": "Nueva nota",
            "estado": "ACTIVO",  // ACTIVO, INACTIVO, PRUEBA
            "nombre_admin": "Nuevo nombre admin",
            "correo_admin": "nuevo@email.com",
            "nueva_password": "opcional123"
        }
        """
        try:
            if not sociedad_id:
                return Response({
                    'status': 'error',
                    'message': 'ID de sociedad requerido para modificar'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Buscar la sociedad
            try:
                sociedad = Sociedad.objects.get(id=sociedad_id)
            except Sociedad.DoesNotExist:
                return Response({
                    'status': 'error',
                    'message': f'Sociedad con ID {sociedad_id} no encontrada'
                }, status=status.HTTP_404_NOT_FOUND)
            
            # Buscar usuario admin
            usuario_admin = Usuario.objects.filter(
                sociedad_id=sociedad.id,
                is_admin=True
            ).first()
            
            if not usuario_admin:
                return Response({
                    'status': 'error',
                    'message': 'Usuario administrador no encontrado para esta sociedad'
                }, status=status.HTTP_404_NOT_FOUND)
            
            # Procesar datos (USAR request.data, nunca request.body)
            data = request.data
            if not data:
                return Response({
                    'status': 'error',
                    'message': 'No se proporcionaron datos para modificar'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            campos_modificados = []
            
            # Modificar campos de la sociedad
            if 'razon_social' in data and data['razon_social'].strip():
                nuevo_valor = data['razon_social'].strip()
                if nuevo_valor != sociedad.razon_social:
                    sociedad.razon_social = nuevo_valor
                    campos_modificados.append('razon_social')
            
            if 'giro' in data:
                nuevo_valor = data['giro'].strip() if data['giro'] else None
                if nuevo_valor != sociedad.giro:
                    sociedad.giro = nuevo_valor
                    campos_modificados.append('giro')
            
            if 'direccion' in data and data['direccion'].strip():
                nuevo_valor = data['direccion'].strip()
                if nuevo_valor != sociedad.direccion:
                    sociedad.direccion = nuevo_valor
                    campos_modificados.append('direccion')
            
            if 'comuna' in data and data['comuna'].strip():
                nuevo_valor = data['comuna'].strip()
                if nuevo_valor != sociedad.comuna:
                    sociedad.comuna = nuevo_valor
                    campos_modificados.append('comuna')
            
            if 'ciudad' in data and data['ciudad'].strip():
                nuevo_valor = data['ciudad'].strip()
                if nuevo_valor != sociedad.ciudad:
                    sociedad.ciudad = nuevo_valor
                    campos_modificados.append('ciudad')
            
            if 'region' in data and data['region'].strip():
                nuevo_valor = data['region'].strip()
                if nuevo_valor != sociedad.region:
                    sociedad.region = nuevo_valor
                    campos_modificados.append('region')
            
            if 'telefono_empresa' in data:
                nuevo_valor = data['telefono_empresa'].strip() if data['telefono_empresa'] else None
                if nuevo_valor != sociedad.telefono_empresa:
                    sociedad.telefono_empresa = nuevo_valor
                    campos_modificados.append('telefono_empresa')
            
            if 'nota' in data:
                nuevo_valor = data['nota'].strip() if data['nota'] else None
                if nuevo_valor != sociedad.nota:
                    sociedad.nota = nuevo_valor
                    campos_modificados.append('nota')
            
            # Modificar estado
            if 'estado' in data:
                nuevo_estado = data['estado']
                
                if nuevo_estado not in ['ACTIVO', 'INACTIVO', 'PRUEBA']:
                    return Response({
                        'status': 'error',
                        'message': 'Estado debe ser ACTIVO, INACTIVO o PRUEBA'
                    }, status=status.HTTP_400_BAD_REQUEST)
                
                if nuevo_estado != sociedad.estado:
                    sociedad.estado = nuevo_estado
                    sociedad.activo = (nuevo_estado != 'INACTIVO')
                    campos_modificados.append('estado')
                    
                    # Actualizar estado del admin
                    nuevo_estado_usuario = 'ON' if nuevo_estado == 'ACTIVO' else 'OFF'
                    if usuario_admin.estado != nuevo_estado_usuario:
                        usuario_admin.estado = nuevo_estado_usuario
                        campos_modificados.append('estado_admin')
                    
                    # Si se desactiva, desactivar todos los usuarios
                    if nuevo_estado == 'INACTIVO':
                        usuarios_desactivados = Usuario.objects.filter(
                            sociedad_id=sociedad.id,
                            is_admin=False
                        ).update(estado='OFF')
                        
                        if usuarios_desactivados > 0:
                            campos_modificados.append(f'{usuarios_desactivados} usuarios desactivados')
            
            # Guardar cambios en sociedad
            if any(campo in campos_modificados for campo in [
                'razon_social', 'giro', 'direccion', 'comuna', 'ciudad',
                'region', 'telefono_empresa', 'nota', 'estado'
            ]):
                sociedad.save()
            
            # Modificar nombre del admin
            if 'nombre_admin' in data and data['nombre_admin'].strip():
                nuevo_nombre = data['nombre_admin'].strip()
                if nuevo_nombre != usuario_admin.nombre:
                    usuario_admin.nombre = nuevo_nombre
                    campos_modificados.append('nombre_admin')
            
            # Modificar correo del admin
            if 'correo_admin' in data and data['correo_admin'].strip():
                nuevo_correo = data['correo_admin'].strip().lower()
                
                if '@' not in nuevo_correo or '.' not in nuevo_correo:
                    return Response({
                        'status': 'error',
                        'message': 'Formato de correo inválido'
                    }, status=status.HTTP_400_BAD_REQUEST)
                
                if Usuario.objects.filter(correo=nuevo_correo).exclude(id=usuario_admin.id).exists():
                    return Response({
                        'status': 'error',
                        'message': f'El correo {nuevo_correo} ya está en uso'
                    }, status=status.HTTP_400_BAD_REQUEST)
                
                if nuevo_correo != usuario_admin.correo:
                    usuario_admin.correo = nuevo_correo
                    campos_modificados.append('correo_admin')
            
            # Cambiar contraseña si se proporciona
            if 'nueva_password' in data and data['nueva_password']:
                nueva_password = data['nueva_password']
                if len(nueva_password) < 6:
                    return Response({
                        'status': 'error',
                        'message': 'La contraseña debe tener al menos 6 caracteres'
                    }, status=status.HTTP_400_BAD_REQUEST)
                
                usuario_admin.set_password(nueva_password)
                campos_modificados.append('password')
            
            # Guardar cambios en usuario
            if any(campo in campos_modificados for campo in [
                'nombre_admin', 'correo_admin', 'password', 'estado_admin'
            ]):
                usuario_admin.save()
            
            if not campos_modificados:
                return Response({
                    'status': 'warning',
                    'message': 'No se realizaron modificaciones',
                    'sociedad': {
                        'id': sociedad.id,
                        'razon_social': sociedad.razon_social
                    }
                })
            
            return Response({
                'status': 'success',
                'message': 'Sociedad modificada exitosamente',
                'campos_modificados': campos_modificados,
                'sociedad': {
                    'id': sociedad.id,
                    'razon_social': sociedad.razon_social,
                    'rut_sociedad': sociedad.rut_sociedad,
                    'rut_formateado': sociedad.rut_formateado,
                    'estado': sociedad.estado,
                    'activo': sociedad.activo,
                    'nombre_admin': usuario_admin.nombre,
                    'correo_admin': usuario_admin.correo,
                    'estado_admin': usuario_admin.estado
                }
            })
        
        except Exception as e:
            print(f"Error al modificar sociedad: {str(e)}")
            import traceback
            traceback.print_exc()
            return Response({
                'status': 'error',
                'message': f'Error interno del servidor: {str(e)}'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

        
class RegistroPorFechaAdminView(APIView):
    def post(self, request):
        try:
            data = json.loads(request.body)
            fecha_str = data.get('fecha')
            fecha = datetime.strptime(fecha_str, '%d/%m/%Y')

            registros = Registro.objects.filter(hora_inicio__date=fecha.date())

            registros_por_holding = {}
            for registro in registros:
                if registro.usuario_registrador.cliente:
                    holding = registro.usuario_registrador.cliente.nombre_holding
                else:
                    try:
                        holding = Sociedad.objects.get(id=registro.usuario_registrador.cliente).nombre_holding
                    except Sociedad.DoesNotExist:
                        holding = "Holding del Jefe No Encontrado"

                if holding not in registros_por_holding:
                    registros_por_holding[holding] = {
                        'registros': [],
                        'tarifa_dia': 0
                    }
                
                registro_data = {
                    'patente': registro.patente,
                    'hora_inicio': registro.hora_inicio,
                    'hora_termino': registro.hora_termino,
                    'tarifa': registro.tarifa,
                    'id': registro.id,
                    'usuario_registrador': registro.usuario_registrador.id
                }
                registros_por_holding[holding]['registros'].append(registro_data)
                registros_por_holding[holding]['tarifa_dia'] += registro.tarifa if registro.tarifa else 0

            return Response({
                'status': 'success', 
                'registros_por_holding': registros_por_holding
            })

        except Exception as e:
            return Response({'status': 'error', 'message': str(e)})
        
#------------------------------------------------------------------------------

#---------------------------ADMINISTRACION-------------------------------------

class UsuariosApiView(APIView):
    """
    Vista unificada para gestionar usuarios de una sociedad.
    GET: Listar todos los usuarios de una sociedad
    POST: Crear nuevo usuario
    PUT: Actualizar usuario específico (nombre, correo, estado)
    DELETE: Eliminar usuario (opcional)
    """
    authentication_classes = [OAuth2Authentication]
    permission_classes = [IsAuthenticated, TokenHasAnyScope]

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.required_scopes = []

    def dispatch(self, request, *args, **kwargs):
        if request.method in ['POST', 'DELETE', 'PUT']:
            self.required_scopes = ['superadmin_access','admin', 'write']
        elif request.method == 'GET':
            self.required_scopes = ['superadmin_access','admin', 'write']
        return super().dispatch(request, *args, **kwargs)

    def get(self, request, id_sociedad, rut=None):
        """
        GET: Obtener usuarios de una sociedad
        - Si se proporciona RUT, devuelve un usuario específico
        - Si no, devuelve todos los usuarios de la sociedad (excepto admins)
        """
        try:
            # Verificar que la sociedad existe
            if not Sociedad.objects.filter(id=id_sociedad).exists():
                return Response({
                    'status': 'error',
                    'message': 'Sociedad no encontrada'
                }, status=404)

            # Si se busca un usuario específico por RUT
            if rut:
                try:
                    usuario = Usuario.objects.get(
                        rut=rut,
                        sociedad_id=id_sociedad,
                        is_admin=False
                    )
                    return Response({
                        'rut': usuario.rut,
                        'nombre': usuario.nombre,
                        'correo': usuario.correo,
                        'estado': usuario.estado,
                    })
                except Usuario.DoesNotExist:
                    return Response({
                        'status': 'error',
                        'message': 'Usuario no encontrado'
                    }, status=404)

            # Listar todos los usuarios de la sociedad (excepto admins)
            usuarios = Usuario.objects.filter(
                sociedad_id=id_sociedad,
                is_admin=False
            ).order_by('-fecha_creacion')

            data_usuarios = [{
                'rut': usuario.rut,
                'nombre': usuario.nombre,
                'correo': usuario.correo,
                'estado': usuario.estado,
                'fecha_creacion': usuario.fecha_creacion.isoformat() if usuario.fecha_creacion else None,
            } for usuario in usuarios]

            return Response({
                'status': 'success',
                'usuarios': data_usuarios,
                'total': len(data_usuarios)
            })

        except Exception as e:
            print(f"Error en GET usuarios: {e}")
            return Response({
                'status': 'error',
                'message': str(e)
            }, status=400)

    def post(self, request, id_sociedad):
        """
        POST: Crear un nuevo usuario para la sociedad
        Body: {
            "rut": "12345678",
            "nombre": "Juan Pérez",
            "correo": "juan@email.com"
        }
        """
        try:
            data = request.data
            print(f"Creando usuario para sociedad {id_sociedad}: {data}")

            # Verificar que la sociedad existe
            try:
                sociedad = Sociedad.objects.get(id=id_sociedad)
            except Sociedad.DoesNotExist:
                return Response({
                    'status': 'error',
                    'message': 'Sociedad no encontrada'
                }, status=404)

            # Validar campos requeridos
            rut = data.get('rut', '').strip()
            nombre = data.get('nombre', '').strip()
            correo = data.get('correo', '').strip().lower()

            if not rut or not nombre or not correo:
                return Response({
                    'status': 'error',
                    'message': 'RUT, nombre y correo son obligatorios'
                }, status=400)

            # Validar formato de correo
            if '@' not in correo or '.' not in correo.split('@')[-1]:
                return Response({
                    'status': 'error',
                    'message': 'Formato de correo inválido'
                }, status=400)

            # Verificar que el RUT no exista
            if Usuario.objects.filter(rut=rut).exists():
                return Response({
                    'status': 'error',
                    'message': f'Ya existe un usuario con el RUT {rut}'
                }, status=400)

            # Verificar que el correo no exista
            if Usuario.objects.filter(correo=correo).exists():
                return Response({
                    'status': 'error',
                    'message': f'Ya existe un usuario con el correo {correo}'
                }, status=400)

            # Crear el usuario
            import secrets
            random_password = secrets.token_urlsafe(12)
            
            usuario = Usuario.objects.create(
                rut=rut,
                nombre=nombre,
                correo=correo,
                sociedad=sociedad,
                is_admin=False,
                is_superadmin=False,
                estado='ON'
            )
            usuario.set_password(random_password)
            usuario.save()

            print(f"Usuario creado: {usuario.nombre} (RUT: {usuario.rut})")

            return Response({
                'status': 'success',
                'message': 'Usuario creado exitosamente',
                'usuario': {
                    'rut': usuario.rut,
                    'nombre': usuario.nombre,
                    'correo': usuario.correo,
                    'estado': usuario.estado,
                    'password_temporal': random_password
                }
            }, status=201)

        except Exception as e:
            print(f"Error al crear usuario: {e}")
            import traceback
            traceback.print_exc()
            return Response({
                'status': 'error',
                'message': str(e)
            }, status=400)

    def put(self, request, id_sociedad, rut):
        """
        PUT: Actualizar un usuario específico
        Body: {
            "nombre": "Nuevo nombre" (opcional),
            "correo": "nuevo@email.com" (opcional),
            "estado": "ON" o "OFF" (opcional)
        }
        """
        try:
            data = request.data
            print(f"Actualizando usuario {rut} de sociedad {id_sociedad}: {data}")

            # Buscar el usuario
            try:
                usuario = Usuario.objects.get(
                    rut=rut,
                    sociedad_id=id_sociedad,
                    is_admin=False
                )
            except Usuario.DoesNotExist:
                return Response({
                    'status': 'error',
                    'message': 'Usuario no encontrado'
                }, status=404)

            campos_modificados = []

            # Actualizar nombre
            if 'nombre' in data and data['nombre'].strip():
                nuevo_nombre = data['nombre'].strip()
                if nuevo_nombre != usuario.nombre:
                    usuario.nombre = nuevo_nombre
                    campos_modificados.append('nombre')

            # Actualizar correo
            if 'correo' in data and data['correo'].strip():
                nuevo_correo = data['correo'].strip().lower()
                
                # Validar formato
                if '@' not in nuevo_correo or '.' not in nuevo_correo.split('@')[-1]:
                    return Response({
                        'status': 'error',
                        'message': 'Formato de correo inválido'
                    }, status=400)
                
                # Verificar que no exista otro usuario con ese correo
                if Usuario.objects.filter(correo=nuevo_correo).exclude(rut=rut).exists():
                    return Response({
                        'status': 'error',
                        'message': 'El correo ya está en uso por otro usuario'
                    }, status=400)
                
                if nuevo_correo != usuario.correo:
                    usuario.correo = nuevo_correo
                    campos_modificados.append('correo')

            # Actualizar estado
            if 'estado' in data:
                nuevo_estado = data['estado'].upper()
                if nuevo_estado not in ['ON', 'OFF']:
                    return Response({
                        'status': 'error',
                        'message': 'Estado debe ser ON u OFF'
                    }, status=400)
                
                if nuevo_estado != usuario.estado:
                    usuario.estado = nuevo_estado
                    campos_modificados.append('estado')

            # Guardar cambios
            if campos_modificados:
                usuario.save()
                mensaje = f"Usuario actualizado: {', '.join(campos_modificados)}"
            else:
                mensaje = "No se realizaron cambios"

            return Response({
                'status': 'success',
                'message': mensaje,
                'usuario': {
                    'rut': usuario.rut,
                    'nombre': usuario.nombre,
                    'correo': usuario.correo,
                    'estado': usuario.estado,
                }
            })

        except Exception as e:
            print(f"Error al actualizar usuario: {e}")
            return Response({
                'status': 'error',
                'message': str(e)
            }, status=400)

    def delete(self, request, id_sociedad, rut):
        """
        DELETE: Eliminar un usuario
        """
        try:
            # Buscar el usuario
            try:
                usuario = Usuario.objects.get(
                    rut=rut,
                    sociedad_id=id_sociedad,
                    is_admin=False
                )
            except Usuario.DoesNotExist:
                return Response({
                    'status': 'error',
                    'message': 'Usuario no encontrado'
                }, status=404)

            # Verificar si el usuario tiene registros asociados
            from .models import Registro
            tiene_registros = Registro.objects.filter(usuario_registrador=usuario).exists()
            
            if tiene_registros:
                # Si tiene registros, mejor desactivar en lugar de eliminar
                usuario.estado = 'OFF'
                usuario.save()
                return Response({
                    'status': 'success',
                    'message': 'Usuario desactivado (tiene registros asociados)'
                })
            else:
                # Si no tiene registros, se puede eliminar
                nombre = usuario.nombre
                usuario.delete()
                return Response({
                    'status': 'success',
                    'message': f'Usuario {nombre} eliminado correctamente'
                })

        except Exception as e:
            print(f"Error al eliminar usuario: {e}")
            return Response({
                'status': 'error',
                'message': str(e)
            }, status=400)
       
class PedirCorreosView(APIView):
    authentication_classes = [OAuth2Authentication]
    permission_classes = [IsAuthenticated, TokenHasAnyScope]

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.required_scopes = []

    def dispatch(self, request, *args, **kwargs):
        if request.method in ['POST', 'DELETE', 'PUT']:
            self.required_scopes = ['admin', 'write']
        elif request.method == 'GET':
            self.required_scopes = ['admin', 'write']
        return super().dispatch(request, *args, **kwargs)

    def post(self, request):
        try:
            sociedad_id = int(request.data.get('sociedad_id'))
            print(f"Buscando cliente con ID: {sociedad_id}")

            try:
                sociedad = Sociedad.objects.get(id=sociedad_id)
                print(f"Cliente encontrado: {sociedad.razon_social}")

                # Buscar todos los usuarios asociados a este cliente, incluyendo al jefe
                usuarios = Usuario.objects.filter(sociedad_id=sociedad_id)
                print(f"Usuarios encontrados: {usuarios.count()}")

                # Recopilar todos los correos únicos
                correos = list(set(usuarios.values_list('correo', flat=True)))

                # Identificar al jefe (si existe) para el logging
                jefe = usuarios.filter(is_admin=True).first()
                if jefe:
                    print(f"Jefe identificado: {jefe.nombre}, correo: {jefe.correo}")
                else:
                    print("No se identificó un jefe para este cliente")

                print(f"Todos los correos únicos: {correos}")

                if correos:
                    return Response({'correos': correos})
                else:
                    return Response({'status': 'error', 'message': 'No se encontraron usuarios asociados a este cliente.'}, status=status.HTTP_404_NOT_FOUND)

            except Sociedad.DoesNotExist:
                print(f"Cliente con ID {cliente_id} no encontrado")
                return Response({'status': 'error', 'message': 'Cliente no encontrado'}, status=status.HTTP_404_NOT_FOUND)

        except KeyError:
            print("Campo cliente_id no proporcionado en la solicitud")
            return Response({'status': 'error', 'message': 'Campo cliente_id no proporcionado'}, status=status.HTTP_400_BAD_REQUEST)
        except ValueError:
            print("cliente_id proporcionado no es un número entero válido")
            return Response({'status': 'error', 'message': 'cliente_id debe ser un número entero'}, status=status.HTTP_400_BAD_REQUEST)
        except Exception as e:
            print(f"Error inesperado: {str(e)}")
            return Response({'status': 'error', 'message': 'Error interno del servidor'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

class ParametrosApiView(APIView):
    """
    Vista unificada para gestionar parámetros de tarifas.
    GET: Obtener parámetros de una sociedad
    PUT: Actualizar parámetros de una sociedad
    """
    authentication_classes = [OAuth2Authentication]
    permission_classes = [IsAuthenticated, TokenHasAnyScope]

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.required_scopes = []

    def dispatch(self, request, *args, **kwargs):
        if request.method in ['POST', 'DELETE', 'PUT']:
            self.required_scopes = ['admin', 'write']
        elif request.method == 'GET':
            self.required_scopes = ['admin', 'write']
        return super().dispatch(request, *args, **kwargs)
    
    def get(self, request, id_sociedad):
        """Obtener parámetros de una sociedad"""
        try:
            if Parametro.objects.filter(sociedad_id=id_sociedad).exists():
                parametro = Parametro.objects.get(sociedad_id=id_sociedad)
                
                datos = {
                    'monto_por_intervalo': parametro.monto_por_intervalo,
                    'intervalo_minutos': parametro.intervalo_minutos,
                    'monto_minimo': parametro.monto_minimo,
                    'intervalo_minimo': parametro.intervalo_minimo,
                }
                
                return Response(datos, status=200)
            else:
                return Response({
                    'error': 'No se encontraron parámetros para la sociedad especificada'
                }, status=404)
                
        except Exception as e:
            print(f"Error en GET parametros: {e}")
            return Response({'error': str(e)}, status=400)
    
    def put(self, request, id_sociedad):
        """Actualizar parámetros de una sociedad"""
        try:
            data = request.data
            print(f"Actualizando parámetros para sociedad {id_sociedad}: {data}")
            
            # Validar que existan los parámetros
            if not Parametro.objects.filter(sociedad_id=id_sociedad).exists():
                return Response({
                    'status': 'error',
                    'message': 'No se encontraron parámetros para la sociedad especificada'
                }, status=404)
            
            # Obtener el objeto
            parametro = Parametro.objects.get(sociedad_id=id_sociedad)
            
            # Actualizar campos
            parametro.monto_por_intervalo = data.get('monto_por_intervalo', parametro.monto_por_intervalo)
            parametro.intervalo_minutos = data.get('intervalo_minutos', parametro.intervalo_minutos)
            parametro.monto_minimo = data.get('monto_minimo', parametro.monto_minimo)
            parametro.intervalo_minimo = data.get('intervalo_minimo', parametro.intervalo_minimo)
            
            parametro.save()
            
            return Response({
                'status': 'success',
                'message': 'Parámetros actualizados exitosamente'
            }, status=200)
            
        except Exception as e:
            print(f"Error en PUT parametros: {e}")
            return Response({
                'status': 'error',
                'message': str(e)
            }, status=400)

class RegistroPorFechaView(APIView):
    authentication_classes = [OAuth2Authentication]
    permission_classes = [IsAuthenticated, TokenHasAnyScope]

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.required_scopes = []

    def dispatch(self, request, *args, **kwargs):
        if request.method in ['POST', 'DELETE', 'PUT']:
            self.required_scopes = ['admin', 'write']
        elif request.method == 'GET':
            self.required_scopes = ['admin', 'write']
        return super().dispatch(request, *args, **kwargs)
    
    def post(self, request):
        try:
            data = request.data
            fecha_str = data.get('fecha')
            fecha = datetime.strptime(fecha_str, '%d/%m/%Y')
            codigo_jefe = data.get('id_boss')
            
            cliente = Sociedad.objects.get(id=codigo_jefe)
            usuarios_del_cliente = Usuario.objects.filter(cliente=cliente)
            
            registros = Registro.objects.filter(
                hora_inicio__date=fecha.date(),
                usuario_registrador__in=usuarios_del_cliente
            )
            
            santiago_tz = pytz.timezone('America/Santiago')
            
            registros_data = [{
                'id': registro.id,
                'patente': registro.patente,
                'hora_inicio': registro.hora_inicio.astimezone(santiago_tz).strftime('%H:%M'),
                'hora_termino': registro.hora_termino.astimezone(santiago_tz).strftime('%H:%M') if registro.hora_termino else None,
                'cancelado': int(registro.tarifa) if registro.tarifa is not None else None,
                'saldo': int(registro.saldo) if registro.saldo is not None else None,
                'usuario_registrador': registro.usuario_registrador.rut
            } for registro in registros]
            
            
            return Response({'status': 'success', 'registros': registros_data})
        except Exception as e:
            return Response({'status': 'error', 'message': str(e)})

class BorrarRegistrosView(APIView):
    def post(self, request):
        try:
            data = request.data
            ids_para_borrar = data.get('ids', [])

            Registro.objects.filter(id__in=ids_para_borrar).delete()

            return Response({'status': 'success', 'message': 'Registros eliminados exitosamente'})

        except Exception as e:
            return Response({'status': 'error', 'message': str(e)})

class EnviarCSVView(APIView):
    authentication_classes = [OAuth2Authentication]
    permission_classes = [IsAuthenticated, TokenHasAnyScope]

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.required_scopes = []

    def dispatch(self, request, *args, **kwargs):
        if request.method in ['POST', 'DELETE', 'PUT']:
            self.required_scopes = ['admin', 'write']
        elif request.method == 'GET':
            self.required_scopes = ['admin', 'write']
        return super().dispatch(request, *args, **kwargs)
    
    def post(self, request):
        data = request.data
        formattedStartDate = data['formattedStartDate']
        formattedEndDate = data['formattedEndDate']
        id_cliente = data['id_cliente']
        lista_emails = data['email']
        
        start_date = datetime.strptime(formattedStartDate, '%Y-%m-%d')
        end_date = datetime.strptime(formattedEndDate, '%Y-%m-%d')
        end_date = end_date + timedelta(days=1, seconds=-1)
        
        usuarios = Usuario.objects.filter(sociedad_id=id_cliente)
        
        registros = Registro.objects.filter(
            Q(hora_inicio__range=(start_date, end_date)) &
            (Q(usuario_registrador__in=usuarios) | Q(cliente_registrado__id=id_cliente))
        ).values_list('patente', 'hora_inicio', 'hora_termino', 'tarifa', 'cancelado', 'saldo', 'usuario_registrador__rut')
        
        if not registros:
            return Response({'status': 'error', 'message': 'No se encontraron registros en las fechas proporcionadas.'})
        
        zona_horaria_santiago = pytz.timezone('America/Santiago')
        registros_formateados = []
        total_saldo = 0
        total_cancelado = 0
        
        for registro in registros:
            inicio_santiago = registro[1].astimezone(zona_horaria_santiago).strftime('%Y-%m-%d %H:%M')
            termino_santiago = registro[2].astimezone(zona_horaria_santiago).strftime('%Y-%m-%d %H:%M') if registro[2] else ''
            saldo = registro[5] if registro[5] is not None else 0
            cancelado = registro[4] if registro[4] is not None else 0
            
            total_saldo += saldo
            total_cancelado += cancelado
            
            registros_formateados.append((
                registro[0],  # Patente
                inicio_santiago,
                termino_santiago,
                registro[3],  # Tarifa
                cancelado,
                saldo,
                registro[6]   # RUT del trabajador
            ))
        
        df = pd.DataFrame(registros_formateados, columns=[
            'Patente', 'Hora Inicio', 'Hora Termino', 'Tarifa', 'Cancelado', 'Saldo', 'RUT Trabajador'
        ])
        
        # Agregar fila de totales
        total_row = pd.DataFrame([{
            'Patente': 'TOTALES',
            'Hora Inicio': '',
            'Hora Termino': '',
            'Tarifa': '',
            'Cancelado': total_cancelado,
            'Saldo': total_saldo,
            'RUT Trabajador': f'Total General: {total_cancelado + total_saldo}'
        }])
        
        df = pd.concat([df, total_row], ignore_index=True)
        
        csv_file = df.to_csv(index=False)
        
        cliente = Sociedad.objects.get(id=id_cliente)
        for email in lista_emails:
            email_message = EmailMessage(
                'Registros Parking CSV',
                f'Hola, aquí están los registros pedidos para el cliente {cliente.nombre_holding}.',
                'contacto@terrasoft.23.com',
                [email],
            )
            email_message.attach('registros.csv', csv_file, 'text/csv')
            email_message.send(fail_silently=False)
        
        return Response({'status': 'success', 'message': 'CSV enviado exitosamente a todos los correos.'})

class EnviarCSVServiciosView(APIView):
    authentication_classes = [OAuth2Authentication]
    permission_classes = [IsAuthenticated, TokenHasAnyScope]

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.required_scopes = []

    def dispatch(self, request, *args, **kwargs):
        if request.method in ['POST', 'DELETE', 'PUT']:
            self.required_scopes = ['admin', 'write']
        elif request.method == 'GET':
            self.required_scopes = ['admin', 'write']
        return super().dispatch(request, *args, **kwargs)
    
    def post(self, request):
        data = request.data
        formattedStartDate = data['formattedStartDate']
        formattedEndDate = data['formattedEndDate']
        id_cliente = data['id_cliente']
        lista_emails = data['email']
        
        start_date = datetime.strptime(formattedStartDate, '%Y-%m-%d')
        end_date = datetime.strptime(formattedEndDate, '%Y-%m-%d')
        end_date = end_date + timedelta(days=1, seconds=-1)
        
        registros = RegistroServicios.objects.filter(
            Q(dia_agendado__range=(start_date, end_date)) &
            Q(cliente_holding_id=id_cliente)
        ).select_related('cliente_holding', 'cliente_servicio', 'servicio', 'tipo_vehiculo')
        
        if not registros:
            return Response({'status': 'error', 'message': 'No se encontraron registros en las fechas proporcionadas.'})
        
        zona_horaria_santiago = pytz.timezone('America/Santiago')
        registros_formateados = []
        total_abonado = 0
        total_valor_final = 0
        
        for registro in registros:
            dia_agendado_santiago = registro.dia_agendado.astimezone(zona_horaria_santiago).strftime('%Y-%m-%d %H:%M')
            abonado = registro.abonado if registro.abonado is not None else 0
            valor_final = registro.valor_final
            
            total_abonado += abonado
            total_valor_final += valor_final
            
            registros_formateados.append({
                'Cliente Holding': registro.cliente_holding.nombre_holding if registro.cliente_holding else '',
                'Cliente Servicio': registro.cliente_servicio.nombre if registro.cliente_servicio else '',
                'Servicio': registro.servicio.nombre_servicio if registro.servicio else '',
                'Tipo de Vehículo': registro.tipo_vehiculo.nombre if registro.tipo_vehiculo else '',
                'Patente': registro.patente,
                'Día Agendado': dia_agendado_santiago,
                'Abonado': abonado,
                'Valor Final': valor_final,
                'Cancelado Completo': 'Sí' if registro.cancelado_completo else 'No',
                'Servicio Finalizado': 'Sí' if registro.servicio_finalizado else 'No',
                'Duración': str(registro.duracion_final) if registro.duracion_final else ''
            })
        
        df = pd.DataFrame(registros_formateados)
        
        # Agregar fila de totales
        total_row = pd.DataFrame([{
            'Cliente Holding': 'TOTALES',
            'Cliente Servicio': '',
            'Servicio': '',
            'Tipo de Vehículo': '',
            'Patente': '',
            'Día Agendado': '',
            'Abonado': total_abonado,
            'Valor Final': total_valor_final,
            'Cancelado Completo': '',
            'Servicio Finalizado': '',
            'Duración': f'Total Abonado: {total_abonado}, Total Valor Final: {total_valor_final}'
        }])
        
        df = pd.concat([df, total_row], ignore_index=True)
        
        csv_file = df.to_csv(index=False)
        
        cliente = Sociedad.objects.get(id=id_cliente)
        for email in lista_emails:
            email_message = EmailMessage(
                'Registros de Servicios CSV',
                f'Hola, aquí están los registros de servicios pedidos para el cliente {cliente.nombre_holding}.',
                'contacto@terrasoft.23.com',
                [email],
            )
            email_message.attach('registros_servicios.csv', csv_file, 'text/csv')
            email_message.send(fail_silently=False)
        
        return Response({'status': 'success', 'message': 'CSV de servicios enviado exitosamente a todos los correos.'})
    
    
#-----------------------------------------------------------------------------

#-----------------------ESTACIONAMIENTO---------------------------------------

class ObtenerRegistrosDelDiaView(APIView):

    authentication_classes = [OAuth2Authentication]
    permission_classes = [IsAuthenticated, TokenHasAnyScope]

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.required_scopes = []

    def dispatch(self, request, *args, **kwargs):
        if request.method in ['POST', 'DELETE', 'PUT']:
            self.required_scopes = ['admin', 'write']
        elif request.method == 'GET':
            self.required_scopes = ['admin', 'write']
        return super().dispatch(request, *args, **kwargs)

    def post(self, request):
        codigo_sociedad = request.data.get('codigo_sociedad')
        print('cliente id', codigo_sociedad)
        
        zona_horaria_santiago = pytz.timezone('America/Santiago')
        ahora_santiago = datetime.now(zona_horaria_santiago)
        corte = time(3, 0, 0)

        if ahora_santiago.time() < corte:
            inicio = ahora_santiago - timedelta(days=1)
        else:
            inicio = ahora_santiago

        inicio = inicio.replace(hour=3, minute=0, second=0, microsecond=0)
        sociedad = Sociedad.objects.get(id=codigo_sociedad)
        usuarios_del_cliente = Usuario.objects.filter(sociedad_id=sociedad.id)
        parametro = Parametro.objects.get(sociedad_id=sociedad.id)
        
        registros = Registro.objects.filter(
            hora_inicio__range=(inicio, inicio + timedelta(days=1)),
            hora_termino__isnull=True,
            usuario_registrador__in=usuarios_del_cliente
        )
        
        parametros = {
            'intervalo_parametro': parametro.intervalo_minutos,
            'valor_parametro': parametro.monto_por_intervalo,
            'monto_minimo': parametro.monto_minimo,
            'intervalo_minimo': parametro.intervalo_minimo,
        }
        
        datos = []
        for registro in registros:
            # Buscar saldo pendiente de registros anteriores de esta patente
            registro_con_saldo = Registro.objects.filter(
                patente=registro.patente, 
                saldo__gt=0
            ).exclude(id=registro.id).first()
            
            saldo_pendiente = 0
            if registro_con_saldo and registro_con_saldo.saldo is not None:
                saldo_pendiente = int(registro_con_saldo.saldo)
            
            datos.append({
                'patente': registro.patente,
                'hora_inicio': registro.hora_inicio.astimezone(zona_horaria_santiago).isoformat(),
                'id': registro.id,
                'cliente_registrado': registro.cliente_registrado,
                'tipo': registro.cliente_registrado.tipo if registro is not None and registro.cliente_registrado is not None else None,
                'saldo_pendiente': saldo_pendiente  # ✅ AGREGADO
            })

        return Response({'datos': datos, 'parametros': parametros})

class RegistroInicialView(APIView):
    authentication_classes = [OAuth2Authentication]
    permission_classes = [IsAuthenticated, TokenHasAnyScope]

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.required_scopes = []

    def dispatch(self, request, *args, **kwargs):
        if request.method in ['POST', 'DELETE', 'PUT']:
            self.required_scopes = ['admin', 'write']
        elif request.method == 'GET':
            self.required_scopes = ['admin', 'write']
        return super().dispatch(request, *args, **kwargs)
    
    def post(self, request):
        data = request.data
        patente = data.get('patente')
        rut_registrado = data.get('usuario_registrador')
        usuario = Usuario.objects.get(rut=rut_registrado)
        
        registro_con_saldo = Registro.objects.filter(patente=patente, saldo__gt=0).first()
        
        if ClientesRegistrados.objects.filter(patente_cliente=patente).exists():
            cliente = ClientesRegistrados.objects.get(patente_cliente=patente)
            if cliente.registrar == False:
                return Response({
                    'error': f'El cliente no se registra, pertenece al convenio de los que pagan de forma {cliente.tipo}'
                }, status=status.HTTP_400_BAD_REQUEST)
        
        registro_activo = Registro.objects.filter(patente=patente, hora_termino__isnull=True).exists()
        if registro_activo:
            return Response({
                'error': 'La patente sigue activa'
            }, status=status.HTTP_400_BAD_REQUEST)
            
        if registro_con_saldo is not None and registro_con_saldo.saldo is not None:
            saldo_pendiente = int(registro_con_saldo.saldo)
        else:   
            saldo_pendiente = 0
            
        try:
            # 🔧 CORRECCIÓN: Agregar sociedad del usuario
            registro = Registro.objects.create(
                patente=patente, 
                usuario_registrador_id=usuario.id,
                sociedad_id=usuario.sociedad_id,  # ✅ AGREGAR ESTA LÍNEA
                hora_termino=None
            )
            return Response({
                'mensaje': 'Entrada registrada', 
                'id': registro.id,
                'tiene_saldo_pendiente': registro_con_saldo is not None,
                'saldo_pendiente': saldo_pendiente
            })
        except Exception as e:
            print(e)
            return Response({
                'error': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

class RegistroFinalView(APIView):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.required_scopes = []

    def dispatch(self, request, *args, **kwargs):
        if request.method in ['POST', 'DELETE', 'PUT']:
            self.required_scopes = ['admin', 'write']
        elif request.method == 'GET':
            self.required_scopes = ['admin', 'write']
        return super().dispatch(request, *args, **kwargs)

    def post(self, request):
        data = request.data
        print(data)
        patente = data.get('patente')
        usuario_registrador = data.get('usuario_registrador')
        monto_pagado = int(data.get('monto_pagado', 0))
        usuario = Usuario.objects.get(rut=usuario_registrador)

        parametro = Parametro.objects.get(sociedad_id=usuario.sociedad.id) # type: ignore
        
        fecha_termino = timezone.now().astimezone(pytz.timezone('America/Santiago'))
        cliente_registrado = None
        es_cliente_registrado = False

        if ClientesRegistrados.objects.filter(patente_cliente=patente).exists():
            cliente_registrado = ClientesRegistrados.objects.get(patente_cliente=patente)
            es_cliente_registrado = True
        
        try:
            registro = Registro.objects.get(patente=patente, hora_termino__isnull=True)
            hora_inicio_santiago = registro.hora_inicio.astimezone(pytz.timezone('America/Santiago'))

            tiempo = trunc(((fecha_termino - hora_inicio_santiago).total_seconds()) / 60)
            
            if es_cliente_registrado:
                tarifa = 0
            elif parametro.intervalo_minimo is not None and tiempo < parametro.intervalo_minimo:
                tarifa = int(parametro.monto_minimo) if parametro.monto_minimo is not None else 0
            else:
                tiempo_redondeado = ceil(tiempo / parametro.intervalo_minutos) * parametro.intervalo_minutos
                tarifa = (tiempo_redondeado / parametro.intervalo_minutos) * parametro.monto_por_intervalo

            # Get the previous pending balance
            registro_anterior = Registro.objects.filter(patente=patente, saldo__gt=0).exclude(id=registro.id).order_by('-hora_termino').first()
            saldo_anterior = registro_anterior.saldo if registro_anterior and registro_anterior.saldo is not None else 0

            total_a_pagar = tarifa + saldo_anterior
            
            if monto_pagado >= total_a_pagar:
                cancelado_actual = tarifa
                cancelado_anterior = saldo_anterior
                saldo = 0
                excedente = monto_pagado - total_a_pagar
            else:
                if monto_pagado > saldo_anterior:
                    cancelado_anterior = saldo_anterior
                    cancelado_actual = monto_pagado - saldo_anterior
                else:
                    cancelado_anterior = monto_pagado
                    cancelado_actual = 0
                saldo = total_a_pagar - monto_pagado
                excedente = 0

            registro.hora_termino = fecha_termino
            registro.usuario_registrador = usuario
            registro.tarifa = tarifa
            registro.cancelado = cancelado_actual
            registro.saldo = max(0, tarifa - cancelado_actual)
            registro.cliente_registrado = cliente_registrado
            registro.save()

            # Update the previous record if it exists
            if registro_anterior and registro_anterior.saldo is not None:
                registro_anterior.cancelado = min(registro_anterior.tarifa, registro_anterior.cancelado + cancelado_anterior) # type: ignore
                registro_anterior.saldo = max(0, registro_anterior.saldo - cancelado_anterior)
                registro_anterior.save()

            return Response({
                'mensaje': 'Salida registrada exitosamente',
                'tarifa': tarifa,
                'saldo_anterior': saldo_anterior,
                'total_pagado': monto_pagado,
                'cancelado_actual': cancelado_actual,
                'cancelado_anterior': cancelado_anterior,
                'saldo': saldo,
                'excedente': excedente,
                'es_cliente_registrado': es_cliente_registrado
            })
        except Registro.DoesNotExist:
            return Response({'error': 'Registro no encontrado'}, status=404)

class PedirHistorialView(APIView):
    authentication_classes = [OAuth2Authentication]
    permission_classes = [IsAuthenticated, TokenHasAnyScope]

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.required_scopes = []

    def dispatch(self, request, *args, **kwargs):
        if request.method in ['POST', 'DELETE', 'PUT']:
            self.required_scopes = ['admin', 'write']
        elif request.method == 'GET':
            self.required_scopes = ['admin', 'write']
        return super().dispatch(request, *args, **kwargs)
    def get(self, request):
        id_cliente = request.GET.get('id_cliente')
        usuario_registrador = request.GET.get('usuario_registrador')

        if not id_cliente and not usuario_registrador:
            return Response({'error': 'Se requiere proporcionar el ID del cliente o el rut del trabajador'}, status=400)

        fecha_actual = timezone.localtime(timezone.now())
        registros_todos = Registro.objects.filter(hora_inicio__date=fecha_actual.date(), hora_termino__isnull=False)
        
        if id_cliente:
            cliente = Sociedad.objects.get(id=id_cliente)
            registros = registros_todos.filter(
                Q(usuario_registrador__cliente=id_cliente) 
                #Q(usuario_registrador=cliente.rut_cliente)
            ).select_related('usuario_registrador').annotate(nombre_trabajador=F('usuario_registrador__nombre'))
        elif usuario_registrador:
            registros = registros_todos.filter(usuario_registrador=usuario_registrador).select_related('usuario_registrador').annotate(nombre_trabajador=F('usuario_registrador__nombre'))
        
        data = list(registros.values('patente', 'hora_inicio', 'hora_termino', 'tarifa', 'usuario_registrador', 'nombre_trabajador'))

        return Response({'data' : data})

class ClientesRegistradosView(APIView):
    authentication_classes = [OAuth2Authentication]
    permission_classes = [IsAuthenticated, TokenHasAnyScope]

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.required_scopes = []

    def dispatch(self, request, *args, **kwargs):
        if request.method in ['POST', 'DELETE', 'PUT']:
            self.required_scopes = ['admin', 'write']
        elif request.method == 'GET':
            self.required_scopes = ['admin', 'write']
        return super().dispatch(request, *args, **kwargs)

    def get(self, request):
        clientes = ClientesRegistrados.objects.all()
        serializer = ClientesRegistradosSerializer(clientes, many=True)
        return Response({'data':serializer.data})

    def post(self, request):
        serializer = ClientesRegistradosSerializer(data=request.data)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    def put(self, request, pk):
        try:
            cliente = ClientesRegistrados.objects.get(pk=pk)
        except ClientesRegistrados.DoesNotExist:
            return Response(status=status.HTTP_404_NOT_FOUND)

        serializer = ClientesRegistradosSerializer(cliente, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    def delete(self, request, pk):
        try:
            cliente = ClientesRegistrados.objects.get(pk=pk)
        except ClientesRegistrados.DoesNotExist:
            return Response(status=status.HTTP_404_NOT_FOUND)

        cliente.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)

class ServiciosView(APIView):
    authentication_classes = [OAuth2Authentication]
    permission_classes = [IsAuthenticated, TokenHasAnyScope]

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.required_scopes = []

    def dispatch(self, request, *args, **kwargs):
        if request.method in ['POST', 'DELETE', 'PUT']:
            self.required_scopes = ['admin', 'write']
        elif request.method == 'GET':
            self.required_scopes = ['admin', 'write']
        return super().dispatch(request, *args, **kwargs)

    def get(self, request):
        cliente_id = request.query_params.get('cliente_id')
        if cliente_id:
            servicios = Servicios.objects.filter(cliente_id=cliente_id)
        else:
            servicios = Servicios.objects.all()
        serializer = ServiciosSerializer(servicios, many=True)
        return Response({'data': serializer.data}, content_type='application/json; charset=utf-8')


    def post(self, request):
        serializer = ServiciosSerializer(data=request.data)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    def put(self, request, pk):
        try:
            servicio = Servicios.objects.get(pk=pk)
        except Servicios.DoesNotExist:
            return Response(status=status.HTTP_404_NOT_FOUND)

        serializer = ServiciosSerializer(servicio, data=request.data)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    def delete(self, request, pk):
        try:
            servicio = Servicios.objects.get(pk=pk)
        except Servicios.DoesNotExist:
            return Response(status=status.HTTP_404_NOT_FOUND)

        servicio.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)
    
class RegistroServiciosView(APIView):
    authentication_classes = [OAuth2Authentication]
    permission_classes = [IsAuthenticated, TokenHasAnyScope]

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.required_scopes = []

    def dispatch(self, request, *args, **kwargs):
        if request.method in ['POST', 'DELETE', 'PUT']:
            self.required_scopes = ['admin', 'write']
        elif request.method == 'GET':
            self.required_scopes = ['admin', 'write']
        return super().dispatch(request, *args, **kwargs)

    def get(self, request):
        servicios = RegistroServicios.objects.all()
        serializer = RegistroServiciosSerializer(servicios, many=True)
        print(serializer.data)
        return Response({'data':serializer.data},content_type='application/json; charset=utf-8')

    def post(self, request):
        data = request.data
        print(data)
        serializer = RegistroServiciosSerializer(data=data)
        if serializer.is_valid():
            serializer.save()
            return Response({'data':serializer.data}, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    def put(self, request, pk):
        try:
            servicio = RegistroServicios.objects.get(pk=pk)
        except RegistroServicios.DoesNotExist:
            return Response(status=status.HTTP_404_NOT_FOUND)

        # Obtenemos los datos actuales del servicio
        datos_actualizados = request.data.copy()

        # Comprobamos si se está finalizando el servicio
        if datos_actualizados.get('servicio_finalizado', False):
            # Si se está finalizando, actualizamos abonado y cancelado_completo
            datos_actualizados['abonado'] = 0
            datos_actualizados['cancelado_completo'] = True

        serializer = RegistroServiciosSerializer(servicio, data=datos_actualizados, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    def delete(self, request, pk):
        try:
            servicio = RegistroServicios.objects.get(pk=pk)
        except RegistroServicios.DoesNotExist:
            return Response(status=status.HTTP_404_NOT_FOUND)

        servicio.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)
    
class ClientesServiciosView(APIView):
    authentication_classes = [OAuth2Authentication]
    permission_classes = [IsAuthenticated, TokenHasAnyScope]

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.required_scopes = []

    def dispatch(self, request, *args, **kwargs):
        if request.method in ['POST', 'DELETE', 'PUT']:
            self.required_scopes = ['admin', 'write']
        elif request.method == 'GET':
            self.required_scopes = ['admin', 'write']
        return super().dispatch(request, *args, **kwargs)

    def get(self, request):
        cliente_id = request.query_params.get('cliente_id')
        if cliente_id:
            clientes = ClientesServicios.objects.filter(cliente_id=cliente_id)
        else:
            clientes = ClientesServicios.objects.all()
        serializer = ClientesServiciosSerializer(clientes, many=True)
        return Response({'data': serializer.data})

    def post(self, request):
        serializer = ClientesServiciosSerializer(data=request.data)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    def put(self, request, pk):
        try:
            cliente = ClientesServicios.objects.get(pk=pk)
        except ClientesServicios.DoesNotExist:
            return Response(status=status.HTTP_404_NOT_FOUND)

        serializer = ClientesServiciosSerializer(cliente, data=request.data)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    def delete(self, request, pk):
        try:
            cliente = ClientesServicios.objects.get(pk=pk)
        except ClientesServicios.DoesNotExist:
            return Response(status=status.HTTP_404_NOT_FOUND)

        cliente.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)
    
class TipoVehiculoView(APIView):
    authentication_classes = [OAuth2Authentication]
    permission_classes = [IsAuthenticated, TokenHasAnyScope]

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.required_scopes = []

    def dispatch(self, request, *args, **kwargs):
        if request.method == 'GET':
            self.required_scopes = ['admin', 'write']
        return super().dispatch(request, *args, **kwargs)

    def get(self, request, pk=None):
        if pk:
            try:
                tipo_vehiculo = TipoVehiculo.objects.get(pk=pk)
                serializer = TipoVehiculoSerializer(tipo_vehiculo)
                return Response({'data': serializer.data})
            except TipoVehiculo.DoesNotExist:
                return Response({'error': 'Tipo de vehículo no encontrado'}, status=status.HTTP_404_NOT_FOUND,content_type='application/json; charset=utf-8')
        else:
            tipos_vehiculos = TipoVehiculo.objects.all()
            serializer = TipoVehiculoSerializer(tipos_vehiculos, many=True)
            return Response({'data': serializer.data},content_type='application/json; charset=utf-8')