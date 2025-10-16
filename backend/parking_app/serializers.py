from rest_framework import serializers
from .models import (
    Usuario,
    Sociedad,
    ClientesRegistrados,
    Servicios,
    RegistroServicios,
    TipoVehiculo,
    ClientesServicios,
)

class LoginSerializer(serializers.Serializer):
    rut = serializers.CharField()
    password = serializers.CharField(style={'input_type':'password'})

#------------------SERIALIZER PARA ADMINISTRACION--------------------------

class UsuarioSerializer(serializers.ModelSerializer):
    cliente = serializers.IntegerField(write_only=True)
    
    class Meta:
        model = Usuario
        fields = ['id', 'rut', 'nombre', 'correo', 'estado', 'is_admin', 'is_superadmin', 'cliente']
        extra_kwargs = {
            'password': {'write_only': True},
            'is_admin': {'read_only': True},
            'is_superadmin': {'read_only': True},
        }

    def create(self, validated_data):
        cliente = validated_data.pop('cliente')
        try:
            cliente = Sociedad.objects.get(id=cliente)
        except Sociedad.DoesNotExist:
            raise serializers.ValidationError("Cliente (jefe) no encontrado")

        usuario = Usuario.objects.create(
            cliente=cliente,
            **validated_data
        )
        
        return usuario

    def validate_rut(self, value):
        if Usuario.objects.filter(rut=value).exists():
            raise serializers.ValidationError("Este RUT ya está registrado")
        return value

    def validate_correo(self, value):
        if Usuario.objects.filter(correo=value).exists():
            raise serializers.ValidationError("Este correo ya está registrado")
        return value

class ClientesRegistradosSerializer(serializers.ModelSerializer):
    class Meta:
        model = ClientesRegistrados
        fields = ['id', 'rut_cliente', 'nombre_cliente', 'patente_cliente', 'tipo', 'valor', 'modo_pago', 'registrar']

class ServiciosSerializer(serializers.ModelSerializer):
    nombre_cliente = serializers.SerializerMethodField(read_only=True)
    class Meta:
        model = Servicios
        fields = ['id', 'nombre_servicio', 'valor_servicio', 'duracion_servicio', 'cliente','nombre_cliente']
    
    def get_nombre_cliente(self, obj):
        if obj.cliente:
            return obj.cliente.nombre_holding
        return None

class RegistroServiciosSerializer(serializers.ModelSerializer):

    nombre_servicio = serializers.SerializerMethodField(read_only=True)
    nombre_vehiculo = serializers.SerializerMethodField(read_only=True)
    nombre_cliente_servicio = serializers.SerializerMethodField(read_only=True)
    valor_servicio_personalizado = serializers.IntegerField(required=False, allow_null=True)
    duracion_servicio_personalizada = serializers.DurationField(required=False, allow_null=True)
    valor_final = serializers.IntegerField(read_only=True)
    duracion_final = serializers.DurationField(read_only=True)

    class Meta:
        model = RegistroServicios
        fields = ['id','cliente_holding','cliente_servicio','nombre_cliente_servicio','servicio','nombre_servicio',
                  'tipo_vehiculo','cancelado_completo','abonado','nombre_vehiculo', 'patente',
                'dia_agendado','servicio_finalizado','valor_servicio_personalizado','duracion_servicio_personalizada',
            'valor_final','duracion_final']

    def get_nombre_servicio(self, obj):
        if obj.servicio:
            return obj.servicio.nombre_servicio
        return None
    
    def get_nombre_vehiculo(self, obj):
        if obj.tipo_vehiculo:
            return obj.tipo_vehiculo.nombre
        return None
    
    def get_nombre_cliente_servicio(self, obj):
        if obj.cliente_servicio:
            return obj.cliente_servicio.nombre
        return None
    
    def get_valor_final(self, obj):
        return obj.valor_final

    def get_duracion_final(self, obj):
        return obj.duracion_final
    

    
class ClientesServiciosSerializer(serializers.ModelSerializer):
    nombre_cliente = serializers.SerializerMethodField(read_only=True)
    class Meta:
        model = ClientesServicios
        fields = ['id', 'nombre', 'rut', 'celular', 'correo','cliente','nombre_cliente']

    def get_nombre_cliente(self, obj):
        if obj.cliente:
            return obj.cliente.nombre_holding
        return None
    
class TipoVehiculoSerializer(serializers.ModelSerializer):
    class Meta:
        model = TipoVehiculo
        fields = ['id', 'codigo', 'nombre']