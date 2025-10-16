"""
models/servicios.py
Modelos relacionados con servicios adicionales (lavado, encerado, etc.)
"""
from django.db import models
from .sociedad import Sociedad

class TipoVehiculo(models.Model):
    """
    Tipos de vehículos (Auto, Moto, Camioneta, etc.)
    """
    id = models.AutoField(primary_key=True)
    codigo = models.CharField(
        max_length=30,
        unique=True,
    )
    nombre = models.CharField(
        max_length=100,
    )

    class Meta:
        db_table = 'tipos_vehiculos'

    def __str__(self):
        return self.nombre


class Servicios(models.Model):
    """
    Catálogo de servicios adicionales ofrecidos (lavado, encerado, etc.)
    """
    id = models.AutoField(primary_key=True)
    sociedad = models.ForeignKey(
        Sociedad,
        on_delete=models.SET_NULL,
        blank=True,
        null=True,
    )
    nombre_servicio = models.TextField()
    valor_servicio = models.IntegerField()
    duracion_servicio = models.DurationField()

    class Meta:
        db_table = 'servicios'

    def __str__(self):
        return self.nombre_servicio

class ClientesServicios(models.Model):
    """
    Clientes que contratan servicios adicionales
    """
    id = models.AutoField(primary_key=True)
    nombre = models.CharField(max_length=100, verbose_name='Nombre')
    rut = models.CharField(max_length=30, verbose_name='RUT')
    celular = models.CharField(max_length=30, verbose_name='Celular')
    correo = models.CharField(max_length=30, verbose_name='Correo')
    sociedad = models.ForeignKey(
        Sociedad,
        on_delete=models.DO_NOTHING,
        blank=True,
        null=True,
    )
    
    class Meta:
        db_table = 'clientes_servicios'

    def __str__(self):
        return self.nombre


class RegistroServicios(models.Model):
    """
    Registro de servicios agendados y realizados
    """
    id = models.AutoField(primary_key=True)
    
    # Relaciones
    cliente_sociedad = models.ForeignKey(
        Sociedad,
        on_delete=models.DO_NOTHING,
        null=True,
        blank=True,
    )
    cliente_servicio = models.ForeignKey(
        ClientesServicios,
        on_delete=models.DO_NOTHING,
        null=True,
        blank=True,
    )
    servicio = models.ForeignKey(
        Servicios,
        on_delete=models.DO_NOTHING,
        null=True,
        blank=True,
    )
    tipo_vehiculo = models.ForeignKey(
        TipoVehiculo,
        on_delete=models.SET_NULL,
        null=True,
    )
    
    # Información del servicio
    patente = models.CharField(max_length=10)
    dia_agendado = models.DateTimeField()
    servicio_finalizado = models.BooleanField(
        default=False,
        )
    
    # Pagos
    abonado = models.IntegerField(
        null=True,
        blank=True,
        )
    cancelado_completo = models.BooleanField(
        null=True,
        blank=True,
        )
    
    # Valores personalizados (sobrescriben los del servicio)
    valor_servicio_personalizado = models.IntegerField(
        null=True,
        blank=True,
    )
    duracion_servicio_personalizada = models.DurationField(
        null=True,
        blank=True,
    )

    class Meta:
        db_table = 'registro_servicios'
        ordering = ['-dia_agendado']

    def __str__(self):
        servicio_nombre = self.servicio.nombre_servicio if self.servicio else 'Sin servicio'
        return f"Servicio {servicio_nombre} - {self.patente}"
    
    @property
    def valor_final(self):
        """
        Retorna el valor final del servicio
        Prioriza el valor personalizado sobre el valor del catálogo
        """
        if self.valor_servicio_personalizado is not None:
            return self.valor_servicio_personalizado
        elif self.servicio is not None:
            return self.servicio.valor_servicio
        else:
            return 0
    
    @property
    def duracion_final(self):
        """
        Retorna la duración final del servicio
        Prioriza la duración personalizada sobre la duración del catálogo
        """
        if self.duracion_servicio_personalizada is not None:
            return self.duracion_servicio_personalizada
        elif self.servicio is not None:
            return self.servicio.duracion_servicio
        else:
            return None
    
    @property
    def saldo_pendiente(self):
        """Calcula el saldo pendiente del servicio"""
        if self.cancelado_completo:
            return 0
        abono = self.abonado or 0
        return max(0, self.valor_final - abono)