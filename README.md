# CUAC — Lab Instrument Identifier

Aplicación móvil Flutter que identifica instrumentos de laboratorio mediante
un modelo TensorFlow Lite ejecutado completamente en el dispositivo.

## Paletas en Apariencia

Ajustes → Apariencia permite elegir **CUAC original**, **Bruma invernal** u
**Océano profundo**, combinadas con Sistema, Claro u Oscuro. La selección se
guarda localmente. Colores y responsabilidades: [documentación](docs/APARIENCIA.md).

## Modelo verificado 2.0.0

El modelo fue reentrenado con 133 imágenes y preprocesamiento bilineal compartido
entre Python y Dart. Resultado interno: 26/27 aciertos top 1 y 27/27 top 3.
No demuestra mayor precisión que el modelo anterior ni fiabilidad en fotografías
externas. La exportación usa pesos float16 y entrada/salida float32.

Consulta [el informe reproducible](docs/ENTRENAMIENTO_VERIFICADO.md) para ver
métricas, límites, errores conocidos y comandos de entrenamiento/verificación.

## Estado actual y cambios recientes

La versión actual incluye una revisión completa del flujo de cámara y una
actualización visual orientada a dispositivos móviles reales:

- La cámara usa una única inicialización compartida y deja que el plugin
  `camera` gestione la solicitud del permiso nativo.
- El ciclo de vida de Android libera la cámara al enviar la aplicación a
  segundo plano y espera esa liberación antes de intentar abrirla de nuevo.
- Si la resolución alta no está disponible, se intenta automáticamente una
  resolución media compatible con más dispositivos.
- El botón `+` del historial vuelve a la instancia de cámara que abrió esa
  pantalla. Esto evita que la vista quede cargando por reemplazar la pila de
  navegación.
- El historial conserva visibles sus cuatro filtros (`Todos`, `Favoritos`,
  `Hoy` y `Esta semana`) mientras carga, cuando no hay resultados y si ocurre
  un error. Su interfaz adapta fondos, tarjetas, texto y controles al tema activo.
- El splash usa un fondo negro y muestra únicamente el logotipo rodeado por
  un indicador de progreso. Los textos solo aparecen si ocurre un error real.
- Ajustes tiene una interfaz de tarjetas adaptable al tema, sin degradados ni
  opciones ficticias. Expone información del modelo, permisos, privacidad,
  datos técnicos, términos, licencias y datos de la aplicación.
- El selector `Apariencia` permite usar el tema del sistema, claro u oscuro.
  La elección se guarda localmente en el dispositivo y no requiere backend.
  Cámara y Splash permanecen negros por diseño para priorizar la vista previa
  y mantener un arranque visualmente consistente.
- Los consejos de precisión usan iconos Material y texto directo, sin emojis
  ni efectos de brillo decorativos.
- La suite automatizada contiene 28 pruebas para preprocesamiento, splash,
  navegación, filtros vacíos, fallos de SQLite, persistencia de apariencia,
  estabilidad del enrutador y superficies claras u oscuras.

## Alcance

- Android es la plataforma principal de validación.
- iOS está preparado a nivel de código y permisos, pero requiere compilarse y
  probarse desde macOS.
- La aplicación es offline-first: no necesita backend para capturar, predecir
  ni guardar el historial.
- El entrenamiento del modelo está separado de los recursos empaquetados en
  la aplicación.

## Estructura

```text
lib/
├── config/       Configuración y tema
├── models/       Entidades de predicción e historial
├── providers/    Estado y coordinación de casos de uso
├── screens/      Pantallas Flutter
└── services/     Cámara, TFLite, imágenes y SQLite

assets/
├── imagenes/     Branding usado por Flutter
└── models/       Solo el modelo TFLite y sus etiquetas

ml/
├── data/         Dataset organizado por clase
├── artifacts/    Modelos, métricas y archivos exportados
├── dataset.py    Preparación, validación y auditoría de imágenes
├── train_model.py
├── run_pipeline.py
└── requirements.txt
```

No existe un servicio backend. Si en el futuro se necesitan cuentas,
sincronización o administración remota, debe añadirse como un proyecto
independiente y no mezclarse con `lib/` ni con `ml/`.

## Cómo funciona la aplicación

```text
Arranque nativo negro
        ↓
Splash: carga del modelo TensorFlow Lite
        ↓
Cámara: permiso, vista previa y captura
        ↓
Preprocesamiento RGB 224×224
        ↓
Inferencia local y resultados ordenados por confianza
        ↓
Guardado opcional en SQLite e historial local
```

Responsabilidades principales:

| Componente | Responsabilidad |
| --- | --- |
| `lib/screens/` | Interfaz, navegación y estados visibles para el usuario. |
| `lib/providers/providers.dart` | Coordinación entre pantallas, servicios y estados asíncronos. |
| `lib/services/camera_service.dart` | Permisos, selección, apertura, captura y liberación de cámara. |
| `lib/services/tflite_service.dart` | Carga del modelo y ejecución de inferencias locales. |
| `lib/services/model_image_preprocessor.dart` | Conversión de imágenes al tensor RGB esperado por el modelo. |
| `lib/services/database_service.dart` | Persistencia SQLite del historial y sus estadísticas. |
| `lib/services/image_processing_service.dart` | Validación, preparación y almacenamiento de capturas. |

El código central contiene documentación en español sobre responsabilidades,
contratos, estados y decisiones no evidentes. Se evita comentar instrucciones
triviales cuando el propio nombre del método ya expresa claramente su función.

## Ejecutar la aplicación

Requisitos:

- Flutter compatible con Dart 3.7 o posterior.
- Android SDK y un dispositivo o emulador con cámara.
- Al menos 3 GB libres para una compilación que incluya varias arquitecturas.

```powershell
flutter pub get
flutter analyze
flutter test
flutter run
```

Si el equipo tiene poco espacio y el destino es un teléfono Android moderno,
se puede compilar únicamente ARM64:

```powershell
flutter build apk --debug --target-platform android-arm64
```

## Identidad y firma Android

El identificador definitivo configurado en las plataformas es
`com.ebassk.cuac`.

La firma release usa estos archivos privados, excluidos de Git:

- `android/app/cuac-upload-keystore.jks`
- `android/key.properties`

El certificado público está en `android/upload_certificate.pem`. Para generar
una clave nueva en otro proyecto:

```powershell
powershell -ExecutionPolicy Bypass `
  -File scripts\generate_android_upload_key.ps1 `
  -KeytoolPath "$env:JAVA_HOME\bin\keytool.exe"
```

La clave actual ya firma correctamente el APK mediante los esquemas v1 y v2.
Se deben respaldar juntos el keystore y `key.properties` fuera del equipo. Si
se pierde la clave de subida, no debe reemplazarse silenciosamente por otra.

```powershell
flutter build apk --release --target-platform android-arm64
```

El flujo esperado es:

```text
Splash → Cámara → Predicción → Confirmar/guardar → Historial → Detalle
                   ↑                         ↓
                   └────── Nuevo escaneo ───┘
```

La imagen solo se copia al almacenamiento permanente cuando el usuario pulsa
`Guardar`. Al eliminar un registro también se elimina su archivo asociado.

## Pipeline de machine learning

El entorno de entrenamiento verificado usa Python 3.13.5 en Windows (CPU).
Las versiones utilizadas están fijadas en `ml/requirements.txt`.

```powershell
& "$env:LOCALAPPDATA/Programs/Python/Python313/python.exe" -m venv .venv-ml
.venv-ml\Scripts\python -m pip install -r ml\requirements.txt
.venv-ml\Scripts\python ml\dataset.py validate
.venv-ml\Scripts\python ml\dataset.py audit
.venv-ml\Scripts\python ml\run_pipeline.py
```

`run_pipeline.py` valida el dataset, ejecuta el entrenamiento y publica
únicamente estos archivos en la aplicación:

- `assets/models/instrument_model.tflite`
- `assets/models/labels.txt`

La auditoría genera `dataset_audit.json` y un `split_manifest.json`
reproducible. El entrenamiento conserva imágenes duplicadas en un único
split y genera métricas por clase, matriz de confusión y una comprobación de
paridad entre Keras y el TFLite exportado. El estado actual del dataset está
resumido en `ml/DATASET_REPORT.md`.

Para publicar artefactos ya entrenados:

```powershell
.venv-ml\Scripts\python ml\run_pipeline.py --copy-only
```

El contrato de entrada del modelo es RGB `224x224`, `float32`, con valores
entre `0` y `1`. El pipeline nuevo incluye dentro del modelo la normalización
específica requerida por MobileNetV2.

## Validación antes de una entrega

```powershell
dart format --output=none --set-exit-if-changed lib test
dart analyze lib test
flutter test
flutter build apk --release --target-platform android-arm64
```

Antes de distribuir una versión release también se debe:

1. Respaldar la clave de subida fuera del equipo.
2. Validar cámara, inferencia, historial y eliminación en un dispositivo real.
3. Evaluar el modelo con fotografías externas que no estén en el dataset.

La validación automatizada no sustituye la prueba en hardware. En un teléfono
real se debe verificar especialmente este recorrido:

```text
Cámara → Historial → botón + → vista previa activa
```

También se debe comprobar manualmente el historial y la apariencia:

1. Abrir el historial sin registros y confirmar que siguen disponibles los
   filtros de periodo y de tipo.
2. Seleccionar `Hoy` y `Esta semana` sin resultados, alternando entre `Todos`
   y `Favoritos`, y verificar que los filtros no desaparecen.
3. Desde Ajustes, cambiar `Apariencia` entre `Sistema`, `Claro` y `Oscuro` y
   confirmar que Historial, Resultados, Detalle y Ajustes se adaptan.
4. Cerrar y volver a abrir la aplicación para comprobar que la elección se
   conserva. En `Sistema`, cambiar el tema del dispositivo y verificar que la
   aplicación lo sigue.
5. Confirmar que Cámara y Splash continúan negros en las tres opciones, ya que
   esas dos pantallas mantienen esa apariencia intencionalmente.

## Clases actuales

1. Buretas
2. Crisoles
3. Embudos
4. Gradillas
5. Matraces
6. Microscopio
7. Pinzas
8. Pipetas
9. Probeta
10. Vasos de precipitado
