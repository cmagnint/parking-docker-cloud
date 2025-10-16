#!/bin/bash

# Script básico de despliegue para Parking App
set -e

# Colores para output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Función principal de despliegue
deploy() {
    print_info "🚀 Iniciando despliegue de Parking App..."
    
    # Verificar que requirements.txt existe en backend/
    if [ ! -f "requirements.txt" ]; then
        print_error "❌ requirements.txt no encontrado en la raíz del proyecto"
        exit 1
    fi
    
    # Verificar que haproxy.cfg existe
    if [ ! -f "haproxy/haproxy.cfg" ]; then
        print_error "❌ haproxy/haproxy.cfg no encontrado"
        exit 1
    fi
    
    print_info "🔨 Construyendo y levantando contenedores..."
    docker compose up -d --build
    
    print_info "⏳ Esperando que los servicios estén listos..."
    sleep 15
    
    print_info "📊 Estado de los contenedores:"
    docker compose ps
    
    print_info "✅ ¡Despliegue completado!"
    echo ""
    print_info "🌐 Aplicación disponible en:"
    echo "   - Aplicación principal: http://localhost:8181"
    echo "   - Admin Django: http://localhost:8181/parking_app_admin/"
    echo "   - HAProxy Stats: http://localhost:8404/stats (admin/admin123)"
    echo "   - Puerto alternativo: http://localhost:80"
}

# Función para ver logs
logs() {
    if [ -n "$1" ]; then
        print_info "📋 Mostrando logs de $1..."
        docker compose logs -f "$1"
    else
        print_info "📋 Mostrando logs de todos los servicios..."
        docker compose logs -f
    fi
}

# Función para detener
stop() {
    print_info "🛑 Deteniendo servicios..."
    docker compose down
    print_info "✅ Servicios detenidos"
}

# Función para reiniciar
restart() {
    print_info "🔄 Reiniciando servicios..."
    docker compose restart
    print_info "✅ Servicios reiniciados"
}

# Función para ver estado
status() {
    print_info "📊 Estado actual de los servicios:"
    docker compose ps
    echo ""
    print_info "💾 Uso de recursos:"
    docker stats --no-stream parking_backend parking_db parking_haproxy 2>/dev/null || true
}

# Menu de ayuda
help() {
    echo "📖 Uso: ./deploy.sh [comando]"
    echo ""
    echo "Comandos disponibles:"
    echo "  deploy    - Construir y levantar todos los servicios"
    echo "  stop      - Detener todos los servicios"
    echo "  restart   - Reiniciar todos los servicios"
    echo "  logs      - Ver logs de todos los servicios"
    echo "  logs <servicio> - Ver logs de un servicio específico"
    echo "  status    - Ver estado y uso de recursos"
    echo "  help      - Mostrar esta ayuda"
    echo ""
    echo "Ejemplos:"
    echo "  ./deploy.sh deploy"
    echo "  ./deploy.sh logs backend"
    echo "  ./deploy.sh logs db"
    echo "  ./deploy.sh status"
}

# Verificar Docker
if ! command -v docker &> /dev/null; then
    print_error "❌ Docker no está instalado"
    exit 1
fi

# Main - parsear argumentos
case "${1:-deploy}" in
    deploy)
        deploy
        ;;
    stop)
        stop
        ;;
    restart)
        restart
        ;;
    logs)
        logs "$2"
        ;;
    status)
        status
        ;;
    help|--help|-h)
        help
        ;;
    *)
        print_error "❌ Comando desconocido: $1"
        echo ""
        help
        exit 1
        ;;
esac