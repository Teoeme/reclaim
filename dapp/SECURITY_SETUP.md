# 🔒 Configuración de Seguridad - Reclaim App

Este documento explica cómo configurar el proyecto de forma segura sin exponer claves API o información sensible.

## 📋 Archivos Requeridos (No incluidos en Git)

Los siguientes archivos contienen información sensible y **NO** están incluidos en el repositorio. Debes crearlos localmente:

### 1. Firebase Configuration

#### `lib/backend/firebase/firebase_config.dart`
```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

Future initFirebase() async {
  if (kIsWeb) {
    await Firebase.initializeApp(
        options: FirebaseOptions(
            apiKey: "TU_WEB_API_KEY_AQUI",
            authDomain: "tu-project-id.firebaseapp.com",
            projectId: "tu-project-id",
            storageBucket: "tu-project-id.firebasestorage.app",
            messagingSenderId: "TU_SENDER_ID",
            appId: "TU_WEB_APP_ID"));
  } else {
    await Firebase.initializeApp();
  }
}
```

### 2. Environment Variables

#### `assets/environment_values/environment.json`
```json
{
  "TokenStamping": "tu_token_stamping_real_aqui"
}
```

### 3. Android Configuration

#### `android/app/google-services.json`
- Descarga este archivo desde Firebase Console
- Ve a Project Settings > General > Your apps > Android app
- Haz clic en "Download google-services.json"

### 4. iOS Configuration

#### `ios/Runner/GoogleService-Info.plist`
- Descarga este archivo desde Firebase Console
- Ve a Project Settings > General > Your apps > iOS app
- Haz clic en "Download GoogleService-Info.plist"

## 🚀 Configuración Inicial

### Paso 1: Clonar el repositorio
```bash
git clone <repository-url>
cd reclaim
```

### Paso 2: Copiar archivos de ejemplo
```bash
# Firebase config
cp lib/backend/firebase/firebase_config.dart.example lib/backend/firebase/firebase_config.dart

# Environment variables
cp assets/environment_values/environment.json.example assets/environment_values/environment.json

# Android (después de descargar desde Firebase)
# Coloca google-services.json en android/app/

# iOS (después de descargar desde Firebase)
# Coloca GoogleService-Info.plist en ios/Runner/
```

### Paso 3: Configurar valores reales
1. Edita `lib/backend/firebase/firebase_config.dart` con tus claves reales
2. Edita `assets/environment_values/environment.json` con tu token real
3. Coloca los archivos de Firebase en las ubicaciones correctas

### Paso 4: Instalar dependencias
```bash
flutter pub get
```

### Paso 5: Ejecutar la aplicación
```bash
flutter run
```

## 🔐 Obtener las Claves de Firebase

### Firebase Console
1. Ve a [Firebase Console](https://console.firebase.google.com/)
2. Selecciona tu proyecto o crea uno nuevo
3. Ve a Project Settings (⚙️)
4. En la pestaña "General":
   - Para Web: Copia la configuración de Firebase SDK
   - Para Android: Descarga `google-services.json`
   - Para iOS: Descarga `GoogleService-Info.plist`

### Configuración de Autenticación
1. En Firebase Console, ve a Authentication
2. Habilita los métodos de autenticación que necesites:
   - Google Sign-In
   - Apple Sign-In
   - Email/Password

## 🚨 Seguridad Importante

### ❌ NUNCA hagas esto:
- Subir archivos con claves reales a Git
- Compartir claves API en mensajes o documentos
- Usar claves de producción en desarrollo

### ✅ SIEMPRE haz esto:
- Usar archivos `.example` para documentar la estructura
- Regenerar claves si se exponen accidentalmente
- Usar diferentes proyectos Firebase para dev/staging/prod
- Revisar el `.gitignore` antes de hacer commits

## 🔄 CI/CD y Deployment

Para configurar CI/CD, usa variables de entorno o secretos:

### GitHub Actions
```yaml
env:
  FIREBASE_WEB_API_KEY: ${{ secrets.FIREBASE_WEB_API_KEY }}
  FIREBASE_PROJECT_ID: ${{ secrets.FIREBASE_PROJECT_ID }}
  TOKEN_STAMPING: ${{ secrets.TOKEN_STAMPING }}
```

### Variables de entorno locales
Crea un archivo `.env` (también ignorado por Git):
```
FIREBASE_WEB_API_KEY=tu_clave_aqui
FIREBASE_PROJECT_ID=tu_proyecto_aqui
TOKEN_STAMPING=tu_token_aqui
```

## 📞 Soporte

Si tienes problemas con la configuración:
1. Verifica que todos los archivos estén en las ubicaciones correctas
2. Confirma que las claves API sean válidas
3. Revisa que el proyecto Firebase esté configurado correctamente

## 🔄 Regenerar Claves (Si se exponen)

Si accidentalmente expones claves:
1. Ve a Firebase Console
2. Project Settings > Service accounts
3. Genera nuevas claves
4. Actualiza todos los archivos de configuración
5. Revoca las claves antiguas 