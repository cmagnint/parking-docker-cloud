"""
models/usuario.py
Modelo Usuario - Sistema de autenticación y permisos
"""
from django.db import models
from django.contrib.auth.models import AbstractBaseUser, PermissionsMixin
from .base import hora_santiago, UserManager
from .sociedad import Sociedad

class Usuario(AbstractBaseUser, PermissionsMixin):
    """
    Usuario del sistema. Puede ser:
    - Superadmin: Administra todo el sistema y todos las sociedades
    - Admin: Administra su empresa (Sociedad)
    - Usuario normal: Operador de estacionamiento
    """
    id = models.AutoField(
        primary_key=True
    )
    ESTADO_CHOICES = [
        ('ACT', 'Activo'),
        ('INA', 'Inactivo'),
        ('SUS', 'Suspendido'),
    ]
    # ============================================================================
    # IDENTIFICACIÓN
    # ============================================================================
    rut = models.CharField(
        max_length=12,
        unique=True,
    )
    nombre = models.CharField(
        max_length=100
    )
    apellido = models.CharField(
        max_length=100,
        blank=True,
        null=True,
    )
    # ============================================================================
    # CONTACTO
    # ============================================================================
    correo = models.EmailField(
        unique=True
    )
    telefono = models.CharField(
        max_length=20,
        blank=True,
        null=True,
    )
    # ============================================================================
    # RELACIÓN CON EMPRESA
    # ============================================================================
    sociedad = models.ForeignKey(
        Sociedad,
        on_delete=models.CASCADE,
        null=True,
        blank=True,
    )
    # ============================================================================
    # ROLES Y PERMISOS
    # ============================================================================
    is_admin = models.BooleanField(
        default=False,
    )
    is_superadmin = models.BooleanField(
        default=False,
    )
    es_usuario_comun = models.BooleanField(
        default=False,
    )
    # ============================================================================
    # ESTADO Y CONTROL
    # ============================================================================
    estado = models.CharField(
        max_length=3,
        choices=ESTADO_CHOICES,
        default='ACT',
    )
    is_active = models.BooleanField(
        default=True
    )
    is_staff = models.BooleanField(
        default=False
    )
    # ============================================================================
    # RECUPERACIÓN DE CONTRASEÑA
    # ============================================================================
    codigo = models.CharField(
        max_length=50,
        blank=True,
        null=True
    )
    codigo_expiracion = models.DateTimeField(
        blank=True,
        null=True
    )
    # ============================================================================
    # AUDITORÍA
    # ============================================================================
    fecha_creacion = models.DateTimeField(
        default=hora_santiago,
    )
    ultimo_acceso = models.DateTimeField(
        blank=True,
        null=True,
    )
    objects = UserManager()
    USERNAME_FIELD = 'rut'
    EMAIL_FIELD = 'correo'
    REQUIRED_FIELDS = ['nombre','correo']

    class Meta:
        db_table = 'usuario'
        indexes = [
            models.Index(fields=['rut']),
            models.Index(fields=['correo']),
            models.Index(fields=['sociedad', 'estado']),
        ]

    def __str__(self):
        nombre_completo = f"{self.nombre} {self.apellido or ''}".strip()
        return f"{nombre_completo} ({self.rut})"
    
    # ============================================================================
    # PROPERTIES
    # ============================================================================
    
    @property
    def nombre_completo(self):
        """Retorna el nombre completo del usuario"""
        return f"{self.nombre} {self.apellido or ''}".strip()
    
    # ============================================================================
    # MÉTODOS DE NEGOCIO
    # ============================================================================
    
    def puede_acceder(self):
        """
        Verifica si el usuario puede acceder al sistema
        
        Returns:
            bool: True si puede acceder, False en caso contrario
        """
        # Superadmin siempre puede acceder
        if self.is_superadmin:
            return True
        
        # Verificar estado del usuario
        if not self.is_active or self.estado != 'ACT':
            return False
        
        # Verificar estado de la empresa
        if self.sociedad and not self.sociedad.esta_activo():
            return False
        
        return True
    
    def get_rol(self):
        """
        Retorna el rol principal del usuario
        
        Returns:
            str: 'superadmin', 'admin' o 'usuario'
        """
        if self.is_superadmin:
            return 'superadmin'
        elif self.is_admin:
            return 'admin'
        else:
            return 'usuario'
    
    def actualizar_ultimo_acceso(self):
        """Actualiza la fecha del último acceso"""
        self.ultimo_acceso = hora_santiago()
        self.save(update_fields=['ultimo_acceso'])
    
    def tiene_permiso_sobre_sociedad(self, sociedad_id):
        """
        Verifica si el usuario tiene permisos sobre una sociedad específica
        
        Args:
            sociedad_id (int): ID de la sociedad a verificar
            
        Returns:
            bool: True si tiene permisos
        """
        if self.is_superadmin:
            return True
        if self.sociedad and self.sociedad.id == sociedad_id:
            return True
        return False

    # ============================================================================
    # MÉTODOS REQUERIDOS POR DJANGO
    # ============================================================================
    
    def has_perm(self, perm, obj=None):
        return True

    def has_module_perms(self, app_label):
        return True
