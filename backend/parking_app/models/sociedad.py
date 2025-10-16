"""
models/sociedad.py
Modelo Sociedad - Representa empresas/sociedades que contratan el servicio
"""
from django.db import models
from django.core.validators import RegexValidator
from django.utils import timezone
from .base import hora_santiago


class Sociedad(models.Model):
    """
    Representa una empresa/sociedad que contrata el servicio de parking.
    Este es el tenant principal del sistema multi-empresa.
    """
    id = models.AutoField(
        primary_key=True
        )
    TIPO_CHOICES = [
        ('SOCIEDAD', 'Sociedad'),
        ('PERSONA', 'Persona Natural'),
        ]
    ESTADO_CHOICES = [
        ('ACTIVO', 'Activo'),
        ('INACTIVO', 'Inactivo'),
        ('PRUEBA', 'Período de prueba'),
        ]
    # ============================================================================
    # TIPO DE SOCIEDAD
    # ============================================================================
    tipo_cliente = models.CharField(
        max_length=20,
        choices=TIPO_CHOICES,
        default='SOCIEDAD',
        )
    # ============================================================================
    # INFORMACIÓN EMPRESARIAL BÁSICA
    # ============================================================================
    
    rut_sociedad = models.CharField(
        max_length=9,
        unique=True,
        validators=[
            RegexValidator(
                regex=r'^\d{7,9}$',
                message='RUT debe contener solo números (7 a 9 dígitos)'
                )
            ],
        )

    razon_social = models.CharField(
        max_length=255,
        )
    
    giro = models.CharField(
        max_length=255,
        null=True,
        blank=True,
        )
    
    
    # ============================================================================
    # REPRESENTANTE LEGAL
    # ============================================================================

    rut_representante = models.CharField(
        max_length=9,
        unique=True,
        blank=True,
        null=True,
        validators=[
            RegexValidator(
                regex=r'^\d{7,9}$',
                message='RUT debe contener solo números (7 a 9 dígitos)'
                )
            ],
        )

    nombre_representante = models.CharField(
        max_length=255,
        null=True,
        blank=True,
        )

    correo = correo = models.EmailField(
        unique=True,
        blank=True,
        null=True,
    )

    telefono = models.CharField(
        max_length=20,
        blank=True,
        null=True,
        )
    

    # ============================================================================
    # DIRECCIÓN Y UBICACIÓN
    # ============================================================================
    direccion = models.CharField(
        max_length=255
    )
    comuna = models.CharField(
        max_length=100
    )
    ciudad = models.CharField(
        max_length=100
    )
    region = models.CharField(
        max_length=100
    )
    
    # ============================================================================
    # ESTADO Y CONTROL DE CUENTA
    # ============================================================================
    estado = models.CharField(
        max_length=20,
        choices=ESTADO_CHOICES,
        default='PRUEBA',
    )
    fecha_registro = models.DateTimeField(
        default=hora_santiago,
    )
    activo = models.BooleanField(
        default=True,
    )

    nota = models.TextField(
        null=True,
        blank=True,
        )
    #============================================================================

    class Meta:
        db_table = 'sociedad'
        ordering = ['-fecha_registro']
        indexes = [
            models.Index(fields=['rut_sociedad']),
            models.Index(fields=['estado', 'activo']),
        ]

    def __str__(self):
        return f"{self.razon_social} (RUT: {self.rut_sociedad})"
    
    # ============================================================================
    # PROPERTIES
    # ============================================================================
    
    @property
    def rut_formateado(self):
        """
        Retorna el RUT formateado con puntos y guión para presentación
        Ejemplo: 123456789 -> 12.345.678-9
        """
        if not self.rut_sociedad or len(self.rut_sociedad) < 2:
            return self.rut_sociedad
        
        # Separar dígito verificador
        rut_sin_dv = self.rut_sociedad[:-1]
        dv = self.rut_sociedad[-1]
        
        # Formatear con puntos
        rut_formateado = '{:,}'.format(int(rut_sin_dv)).replace(',', '.')
        
        return f"{rut_formateado}-{dv}"
    
    # ============================================================================
    # MÉTODOS
    # ============================================================================
    
    def esta_activo(self):
        """
        Verifica si la empresa puede usar el servicio
        
        Returns:
            bool: True si puede usar el servicio, False en caso contrario
        """
        if not self.activo:
            return False
        if self.estado == 'INACTIVO':
            return False
        if self.fecha_vencimiento and self.fecha_vencimiento < timezone.now().date():
            return False
        return True
    
    def desactivar(self):
        """
        Desactiva manualmente la cuenta de la sociedad
        """
        self.estado = 'INACTIVO'
        self.activo = False
        self.save()
    
    def reactivar(self):
        """
        Reactiva la cuenta del cliente
        """
        self.estado = 'ACTIVO'
        self.activo = True
        self.save()
    
    def cambiar_a_activo(self):
        """
        Cambia el estado de PRUEBA a ACTIVO
        (Cuando termina el período de prueba y comienza a pagar)
        """
        if self.estado == 'PRUEBA':
            self.estado = 'ACTIVO'
            self.save()
    
    @staticmethod
    def validar_rut(rut):
        """
        Valida un RUT chileno usando el algoritmo del dígito verificador
        
        Args:
            rut (str): RUT sin formato, solo números (ej: "123456789")
            
        Returns:
            bool: True si el RUT es válido, False en caso contrario
        """
        if not rut or len(rut) < 2:
            return False
        
        try:
            # Separar dígito verificador
            rut_sin_dv = rut[:-1]
            dv = rut[-1].upper()
            
            # Calcular dígito verificador
            suma = 0
            multiplo = 2
            
            for digito in reversed(rut_sin_dv):
                suma += int(digito) * multiplo
                multiplo += 1
                if multiplo == 8:
                    multiplo = 2
            
            resto = suma % 11
            dv_calculado = 11 - resto
            
            if dv_calculado == 11:
                dv_esperado = '0'
            elif dv_calculado == 10:
                dv_esperado = 'K'
            else:
                dv_esperado = str(dv_calculado)
            
            return dv == dv_esperado
            
        except (ValueError, IndexError):
            return False