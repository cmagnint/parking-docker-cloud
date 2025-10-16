"""
models/parametro.py
Modelo Parametro - Configuración de tarifas por cliente
"""
from django.db import models
from .sociedad import Sociedad


class Parametro(models.Model):
    """
    Configuración de tarifas por cliente/empresa.
    Cada cliente tiene su propia configuración de precios.
    """
    id = models.AutoField(primary_key=True)

    sociedad = models.OneToOneField(
        Sociedad,
        on_delete=models.CASCADE,
        blank=True,
        null=True,
    )
    
    # Tarifa principal
    monto_por_intervalo = models.IntegerField(
        verbose_name='Monto por Intervalo',
        help_text='Monto a cobrar por cada intervalo'
    )
    intervalo_minutos = models.IntegerField(
        verbose_name='Intervalo en Minutos',
        help_text='Duración del intervalo de cobro'
    )
    
    # Tarifa mínima (opcional)
    monto_minimo = models.IntegerField(
        blank=True,
        null=True,
        verbose_name='Monto Mínimo',
        help_text='Monto mínimo a cobrar independiente del tiempo'
    )
    intervalo_minimo = models.IntegerField(
        blank=True,
        null=True,
        verbose_name='Intervalo Mínimo',
        help_text='Tiempo mínimo antes de aplicar tarifa normal'
    )
    
    class Meta:
        db_table = 'parametro'
        verbose_name = 'Parámetro de Tarifa'
        verbose_name_plural = 'Parámetros de Tarifas'

    def __str__(self):
        if self.sociedad:
            return f"Parámetros de {self.sociedad.razon_social}"
        return "Parámetros sin sociedad asignada"
    
    def calcular_tarifa(self, minutos):
        """
        Calcula la tarifa basándose en los minutos transcurridos
        
        Args:
            minutos (int): Minutos a calcular
            
        Returns:
            float: Tarifa calculada
        """
        from math import ceil
        
        # Si hay tarifa mínima y el tiempo es menor al intervalo mínimo
        if self.intervalo_minimo and minutos < self.intervalo_minimo:
            return self.monto_minimo if self.monto_minimo else 0
        
        # Calcular tarifa normal
        intervalos = ceil(minutos / self.intervalo_minutos)
        return intervalos * self.monto_por_intervalo
