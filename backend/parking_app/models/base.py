"""
models/base.py
Funciones auxiliares y managers base para todos los modelos
"""
from django.contrib.auth.models import BaseUserManager
from django.utils import timezone
from django.utils.translation import gettext_lazy as _
import pytz


def hora_santiago():
    """
    Retorna la hora actual en zona horaria de Santiago de Chile
    """
    return timezone.now().astimezone(pytz.timezone('America/Santiago'))


class UserManager(BaseUserManager):
    """
    Manager customizado para el modelo Usuario
    """
    def create_user(self, rut, nombre, correo, password=None, **extra_fields):
        """
        Crea y guarda un Usuario con el RUT, nombre, correo y contraseña dados.
        """
        if not rut:
            raise ValueError(_('El RUT debe ser establecido'))
        if not correo:
            raise ValueError(_('El correo debe ser establecido'))

        user = self.model(
            rut=rut,
            nombre=nombre,
            correo=self.normalize_email(correo),
            **extra_fields
        )
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_superuser(self, rut, nombre, correo, password, **extra_fields):
        """
        Crea y guarda un Superusuario con permisos totales.
        """
        extra_fields.setdefault('is_superuser', True)
        extra_fields.setdefault('is_staff', True)
        extra_fields.setdefault('is_superadmin', True)

        if extra_fields.get('is_superuser') is not True:
            raise ValueError(_('Superuser debe tener is_superuser=True.'))
        if extra_fields.get('is_staff') is not True:
            raise ValueError(_('Superuser debe tener is_staff=True.'))

        return self.create_user(rut, nombre, correo, password=password, **extra_fields)

    def get_by_natural_key(self, rut):
        """
        Permite autenticación usando RUT en lugar de username
        """
        return self.get(rut=rut)
