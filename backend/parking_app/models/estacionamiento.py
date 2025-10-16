"""
models/estacionamiento.py
Modelos relacionados con el registro de vehículos en estacionamiento
"""
from django.db import models
from .base import hora_santiago
from .usuario import Usuario
from .sociedad import Sociedad

class ClientesRegistrados(models.Model):
    """
    Clientes frecuentes con tarifas especiales (diarias, semanales, mensuales)
    """
    TIPO_TARIFA_CHOICES = [
        ('DIARIA', 'Diaria'),
        ('SEMANAL', 'Semanal'),
        ('MENSUAL', 'Mensual')
    ]
    
    id = models.AutoField(primary_key=True)
    sociedad = models.ForeignKey(
        Sociedad,
        on_delete=models.DO_NOTHING,
    )
    rut_cliente = models.CharField(max_length=12, unique=True)
    nombre_cliente = models.TextField()
    patente_cliente = models.CharField(max_length=10, unique=True)
    tipo = models.CharField(
        max_length=10,
        choices=TIPO_TARIFA_CHOICES,
    )
    valor = models.IntegerField()
    modo_pago = models.CharField(max_length=20)
    registrar = models.BooleanField()

    class Meta:
        db_table = 'clientes_registrados'
        indexes = [
            models.Index(fields=['patente_cliente']),
            models.Index(fields=['rut_cliente']),
        ]

    def __str__(self):
        return f"{self.nombre_cliente} - {self.patente_cliente}"

class Registro(models.Model):
    """
    Registro de entrada/salida de vehículos en el estacionamiento
    Core del sistema de cobro
    """
    id = models.AutoField(primary_key=True)
    patente = models.CharField(
        max_length=125,
        verbose_name='Patente',
        db_index=True
    )
    # Tiempos
    hora_inicio = models.DateTimeField(
        default=hora_santiago,
    )
    hora_termino = models.DateTimeField(
        null=True,
        blank=True,
    )
    # Financiero
    tarifa = models.FloatField(
        null=True,
        blank=True,
    )
    cancelado = models.FloatField(
        null=True,
        blank=True,
    )
    saldo = models.FloatField(
        null=True,
        blank=True,
    )
    # Relaciones
    sociedad = models.ForeignKey(
        Sociedad,
        on_delete=models.DO_NOTHING,
    )
    usuario_registrador = models.ForeignKey(
        Usuario,
        on_delete=models.DO_NOTHING,
    )
    cliente_registrado = models.ForeignKey(
        ClientesRegistrados,
        on_delete=models.SET_NULL,
        blank=True,
        null=True,
    )
    
    class Meta:
        db_table = 'registro'
        ordering = ['-hora_inicio']
        indexes = [
            models.Index(fields=['patente', 'hora_termino']),
            models.Index(fields=['hora_inicio']),
            models.Index(fields=['usuario_registrador']),
        ]

    def __str__(self):
        return f"{self.patente} - {self.hora_inicio.strftime('%d/%m/%Y %H:%M')}"
    
    @property
    def esta_activo(self):
        """Verifica si el registro está activo (sin hora de término)"""
        return self.hora_termino is None
    
    @property
    def duracion_minutos(self):
        """Calcula la duración en minutos del registro"""
        if not self.hora_termino:
            return None
        delta = self.hora_termino - self.hora_inicio
        return int(delta.total_seconds() / 60)
    
    @property
    def tiene_saldo_pendiente(self):
        """Verifica si tiene saldo pendiente"""
        return self.saldo is not None and self.saldo > 0
    
    def cerrar_registro(self, monto_pagado=0):
        """
        Cierra el registro y calcula la tarifa
        
        Args:
            monto_pagado (float): Monto pagado por el cliente
            
        Returns:
            dict: Información del cierre (tarifa, saldo, etc.)
        """
        from django.utils import timezone
        
        self.hora_termino = hora_santiago()
        
        # Aquí iría la lógica de cálculo de tarifa
        # (debería usar el Parametro del cliente del usuario_registrador)
        
        self.save()
        
        return {
            'tarifa': self.tarifa,
            'cancelado': self.cancelado,
            'saldo': self.saldo,
            'duracion_minutos': self.duracion_minutos
        }
