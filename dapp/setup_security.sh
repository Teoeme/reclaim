#!/bin/bash

# 🔒 Script de Configuración de Seguridad - Reclaim App
# Este script ayuda a configurar los archivos de configuración de forma segura

echo "🔒 Configurando archivos de seguridad para Reclaim App..."
echo ""

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para mostrar mensajes
show_message() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

show_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

show_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

show_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Verificar si estamos en el directorio correcto
if [ ! -f "pubspec.yaml" ]; then
    show_error "Este script debe ejecutarse desde la raíz del proyecto Flutter"
    exit 1
fi

show_message "Verificando estructura del proyecto..."

# Crear directorios si no existen
mkdir -p lib/backend/firebase
mkdir -p assets/environment_values
mkdir -p android/app
mkdir -p ios/Runner

# Copiar archivos de ejemplo si no existen los reales
echo ""
show_message "Configurando archivos de ejemplo..."

# Firebase config
if [ ! -f "lib/backend/firebase/firebase_config.dart" ]; then
    if [ -f "lib/backend/firebase/firebase_config.dart.example" ]; then
        cp lib/backend/firebase/firebase_config.dart.example lib/backend/firebase/firebase_config.dart
        show_success "Creado: lib/backend/firebase/firebase_config.dart"
        show_warning "⚠️  EDITA este archivo con tus claves reales de Firebase"
    else
        show_error "No se encontró el archivo de ejemplo firebase_config.dart.example"
    fi
else
    show_warning "Ya existe: lib/backend/firebase/firebase_config.dart"
fi

# Environment variables
if [ ! -f "assets/environment_values/environment.json" ]; then
    if [ -f "assets/environment_values/environment.json.example" ]; then
        cp assets/environment_values/environment.json.example assets/environment_values/environment.json
        show_success "Creado: assets/environment_values/environment.json"
        show_warning "⚠️  EDITA este archivo con tu token real"
    else
        show_error "No se encontró el archivo de ejemplo environment.json.example"
    fi
else
    show_warning "Ya existe: assets/environment_values/environment.json"
fi

# Verificar archivos de Firebase
echo ""
show_message "Verificando archivos de Firebase..."

if [ ! -f "android/app/google-services.json" ]; then
    show_warning "Falta: android/app/google-services.json"
    echo "   📥 Descárgalo desde Firebase Console > Project Settings > Android app"
else
    show_success "Encontrado: android/app/google-services.json"
fi

if [ ! -f "ios/Runner/GoogleService-Info.plist" ]; then
    show_warning "Falta: ios/Runner/GoogleService-Info.plist"
    echo "   📥 Descárgalo desde Firebase Console > Project Settings > iOS app"
else
    show_success "Encontrado: ios/Runner/GoogleService-Info.plist"
fi

# Verificar .gitignore
echo ""
show_message "Verificando .gitignore..."

if grep -q "lib/backend/firebase/firebase_config.dart" .gitignore; then
    show_success ".gitignore está configurado correctamente"
else
    show_warning ".gitignore puede necesitar actualización"
fi

# Mostrar resumen
echo ""
echo "📋 RESUMEN DE CONFIGURACIÓN:"
echo "================================"

echo ""
echo "✅ Archivos de ejemplo creados:"
echo "   - lib/backend/firebase/firebase_config.dart.example"
echo "   - assets/environment_values/environment.json.example"
echo "   - android/app/google-services.json.example"
echo "   - ios/Runner/GoogleService-Info.plist.example"

echo ""
echo "🔧 PRÓXIMOS PASOS:"
echo "1. Edita lib/backend/firebase/firebase_config.dart con tus claves reales"
echo "2. Edita assets/environment_values/environment.json con tu token real"
echo "3. Descarga google-services.json desde Firebase Console"
echo "4. Descarga GoogleService-Info.plist desde Firebase Console"
echo "5. Ejecuta: flutter pub get"
echo "6. Ejecuta: flutter run"

echo ""
echo "📚 Para más información, lee: SECURITY_SETUP.md"

echo ""
show_success "¡Configuración de seguridad completada!"
echo ""
show_warning "IMPORTANTE: Nunca subas archivos con claves reales a Git" 