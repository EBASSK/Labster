# Labster: primera entrega — auditoría y marca

Fecha: 24 de octubre de 2026. Trabajo por etapas solicitado por el usuario.

## Punto de partida comprobado

- GitHub `main`: `afec4cac5e40db12e8d32448c79d33de92430ec3`.
  Los archivos versionados de la copia local coincidían con esa revisión antes
  de esta entrega (ignorando diferencias CRLF/LF). No se reemplazó el proyecto
  local con la copia remota. La copia Git de publicación está en
  `.tools/publish-Labster`; la raíz local no tiene un repositorio Git válido.
- Flutter 3.29.2 y Dart 3.7.2, verificados con `flutter --version`.
- Riverpod administra servicios y estado; GoRouter conecta arranque, cámara,
  resultados, historial, detalle de escaneo y ajustes en `lib/main.dart`.
- SQLite: `lab_instruments.db`, versión 1. `scan_history` guarda fotografías
  por ruta, predicciones, notas y favoritos. `instruments` existe como tabla
  prevista para catálogo, pero no hay servicio de consulta ni pantalla de
  catálogo educativo implementados. No se inspeccionó la base de un teléfono.
- La captura usa `camera`. No se encontró selector de galería ni dependencia
  `image_picker` en el código actual.
- El entrenamiento implementa MobileNetV2. El contrato del modelo empaquetado
  declara entrada float32 `[1,224,224,3]`, RGB bilineal normalizado a `[0,1]`,
  y salida float32 `[1,10]`. El código de entrenamiento incluye dentro del
  modelo la transformación a `[-1,1]` requerida por MobileNetV2.
- Etiquetas actuales: buretas, crisoles, embudos, gradillas, matraces,
  microscopio, pinzas, pipetas, probeta y vasos_precipitado.
- El informe de datos existente registra 133 imágenes de esas diez clases.
  No se entrenó ni se volvió a evaluar el modelo en esta entrega.
- El SHA-256 del modelo permanece en
  `c33c19b4ec1e09a8f30b19bf24cee3c80892273da06f56b5419b7c46bc4ea094`.
- Las paletas original, invernal y oceánica tienen identificadores estables
  independientes del modo claro/oscuro. Hay cinco archivos de pruebas Dart.

## Cambios implementados

| Archivos | Responsabilidad y cambio |
| --- | --- |
| `lib/config/app_config.dart`, `lib/main.dart`, `lib/config/theme.dart` | Nombre central y comentarios de la aplicación actualizados a Labster. |
| `lib/config/app_palette.dart` | Etiqueta visible «Labster original»; identificadores y colores intactos. |
| `lib/screens/settings_screen.dart`, `camera_screen.dart`, `splash_screen.dart` | Acerca de, mensaje de permiso y etiquetas de accesibilidad actualizados. |
| `assets/imagenes/labster_logo.png`, `pubspec.yaml` | Recurso renombrado y referencias actualizadas; mismos bytes, sin rediseño. El dibujo inspeccionado no contiene texto CUAC. |
| `android/app/src/main/AndroidManifest.xml`, `ios/Runner/Info.plist` | Nombre visible Labster y explicación de acceso a cámara en iOS. |
| `web/index.html`, `web/manifest.json` | Título y metadatos de marca actualizados; no certifica soporte web de los plugins nativos. |
| `lib/services/*preferences_service.dart` | Comentarios explican por qué los nombres físicos de preferencias se conservan. |
| `test/widget_test.dart` | Expectativas de Ajustes actualizadas y comprobación del título Labster. |
| `README.md`, `docs/APARIENCIA.md` | Presentación y ayuda con la marca actual. |

No hay cambios de esquema SQLite, migraciones, etiquetas del modelo, pesos,
paletas ni identificadores de instalación. La conservación de esos contratos
evita cambiar el lugar donde la app busca los datos; falta verificar una
actualización sobre una instalación real con historial y favoritos.

## Referencias históricas conservadas

- `com.ebassk.cuac`: namespace, paquete Kotlin y bundle IDs de Android/iOS/macOS.
  Cambiarlos alteraría la identidad de la instalación.
- `cuac_preferences.json` y `cuac_palette.txt`, incluidas las pruebas de lectura:
  compatibilidad con las preferencias ya guardadas.
- Rutas de firma y ejemplos de configuración: no se renombran claves existentes.
- Informes `ENTRENAMIENTO_VERIFICADO.md` y `REVISION_IDENTIFICACION.md`:
  documentan trabajo anterior bajo CUAC. La ruta del APK histórico se conserva.
- El prefijo de directorio temporal de una prueba no es una marca visible.

## Siguientes entregas

1. Completar la revisión de marca de escritorio e iconos de cada plataforma.
   Los nombres de binarios/paquetes internos se deben evaluar por separado.
2. Diseñar el modelo educativo y la migración de `instruments`, sin tocar
   `scan_history`. Implementar catálogo y fichas locales con rutas propias.
3. Incorporar exactamente diez instrumentos nuevos, fuentes e imágenes con
   procedencia comprobada. La distinción entre microscopio genérico y
   estereoscópico debe quedar explícita para evitar duplicados.
4. Buscar y verificar videos concretos; decidir apertura externa tras revisar
   compatibilidad y dependencia necesaria. Las fichas funcionarán sin conexión.
5. Evaluar datos de las nuevas clases antes de ampliar la IA. Agregar fichas no
   equivale a ampliar las diez salidas del modelo actual.

Esta entrega no añade instrumentos, imágenes educativas ni videos y no cambia
la precisión del reconocimiento. Esos puntos siguen pendientes, no simulados.

## Validación de esta entrega

- `flutter analyze --no-pub`: sin incidencias.
- `flutter test --no-pub`: 28 pruebas aprobadas, incluida la comprobación del
  título Labster y los escenarios existentes de paletas, historial y favoritos.
- Comprobación estática de XML/Plist/JSON: nombre Labster correcto en Android,
  iOS y web. Comparación byte a byte con la revisión anterior: modelo, etiquetas,
  contrato, servicio SQLite e identificadores Android/iOS conservados; el logo
  renombrado es idéntico al original.
- `flutter build apk --debug --no-pub --target-platform android-arm64`:
  compilación iniciada, resultado pendiente.

No fue necesario ejecutar `flutter pub get`: no se añadieron dependencias.
No se ha probado la instalación en un teléfono ni compilado iOS/macOS desde
este entorno Windows. Las pruebas de historial usan sustitutos de servicios;
no demuestran una actualización real de una base SQLite instalada.
