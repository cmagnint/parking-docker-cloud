"""
models/__init__.py
Importa y expone todos los modelos para mantener compatibilidad con el código existente
"""

# Funciones y utilidades base
from .base import (
    hora_santiago,
    UserManager
)

# Modelos principales
from .sociedad import Sociedad
from .usuario import Usuario
from .parametro import Parametro

# Modelos de estacionamiento
from .estacionamiento import (
    ClientesRegistrados,
    Registro
)

# Modelos de servicios
from .servicios import (
    TipoVehiculo,
    Servicios,
    ClientesServicios,
    RegistroServicios
)

# Exportar todo para mantener compatibilidad con imports existentes
__all__ = [
    # Utilidades
    'hora_santiago',
    'UserManager',
    
    # Modelos principales
    'Sociedad',
    'Usuario',
    'Parametro',
    
    # Estacionamiento
    'ClientesRegistrados',
    'Registro',
    
    # Servicios
    'TipoVehiculo',
    'Servicios',
    'ClientesServicios',
    'RegistroServicios',
]