# Entrenamiento y verificación del modelo CUAC 2.0.0

## Resultado y límites

Se entrenó MobileNetV2, se seleccionaron pesos por pérdida de validación y se
publicó el modelo TFLite con sus etiquetas en `assets/models`. La app conserva
inferencia local, Flutter, SQLite y las diez clases existentes.

| Comprobación | Resultado medido |
|---|---|
| Imágenes | 133; 79 entrenamiento, 27 validación, 27 prueba |
| Selección | Ajuste fino; pérdida de validación de 0,231510 a 0,168637 |
| Keras, test interno | 26/27 correctas (96,30 %) |
| TFLite, test interno | 26/27 correctas (96,30 %) |
| TFLite con tensores del código Dart | 26/27 top 1; 27/27 top 3 |
| Acuerdo Keras/TFLite en validación | 27/27; diferencia máxima de puntuación 0,005736 |
| Acuerdo de clase usando preprocesamiento Python/Dart | 27/27 |
| Diferencia media absoluta de tensores Python/Dart | 0,001267 en escala [0,1] |
| Diferencia máxima de puntuación Python/Dart | 0,041480 |
| Modelo anterior, mismas imágenes con el preprocesamiento nuevo | 26/27 |

No se demuestra un aumento de precisión respecto al modelo anterior. Su
entrenamiento original pudo haber visto estas imágenes: esa comparación es
solo descriptiva. Tampoco se midió precisión sobre fotografías externas.
Una sola equivocación cambia la tasa de este conjunto en 3,70 puntos.

El muestreo bilineal comparte ecuaciones y bordes en Python/Dart. Los
**decodificadores** JPEG/WebP no producen siempre los mismos píxeles: la mayor
diferencia puntual observada fue 0,229451, aunque la media fue 0,001267.
Por eso se midieron también salidas y clases, sin afirmar igualdad bit a bit.
Todas las 27 imágenes de prueba pudieron procesarse con Dart; el script excluye
AVIF porque `image` no lo decodifica. La cámara móvil produce JPEG. Este ensayo
invoca directamente el preprocesador; no aplica el filtro de calidad de 224
píxeles de la pantalla, que puede rechazar algunas imágenes pequeñas del dataset.

## Error concreto pendiente

`ml/data/instruments/embudos/images (3).jpg` contiene embudos y fue clasificada
como matraces con puntuación 0,8218 usando Python. Se conservó su etiqueta y no
se ajustaron los pesos con esa imagen de prueba. Una puntuación alta no garantiza
acierto; el modelo no está calibrado ni tiene una clase «desconocido».
El umbral 0,5 sigue siendo un aviso provisional. Objetos ajenos al laboratorio,
fotografías con varios instrumentos y capturas de mala calidad requieren revisión.

## Correcciones realizadas

- **Datos:** el entorno anterior no abría tres AVIF. Pillow 12.3.0 permitió
  usar las 133 imágenes sin omitirlas. El cargador ahora falla ante archivos
  ilegibles, hashes cambiados o falta de clases en un conjunto.
- **Entrada:** RGB8, orientación EXIF, bilineal por centros de píxel, 224×224,
  rango [0,1], sin recorte ni relleno. La normalización a [-1,1] está dentro
  del modelo, antes de MobileNetV2. Se corrigió también el caso PNG de 16 bits.
- **Selección:** semillas fijadas, parada temprana y checkpoints por `val_loss`.
  El ajuste fino solo reemplaza la cabeza si mejora esa misma medida. Test no
  se utiliza para seleccionar pesos.
- **Conversión:** la cuantización entera predeterminada alteró puntuaciones
  hasta 0,100606 y fue rechazada. Se reexportaron los mismos pesos como float16:
  bajó la diferencia máxima a 0,005736 en validación. Entrada y salida siguen
  siendo float32, compatibles con el servicio Dart.
- **Publicación:** comprueba las métricas, hashes de modelo/etiquetas,
  identificador del preprocesamiento y paridad antes de copiar los recursos.
  Un entrenamiento fallido ya no puede publicar silenciosamente archivos viejos.
- **Trazabilidad:** checkpoint seleccionado, manifiesto de división, métricas
  por clase, resultados por imagen, matriz de confusión y contrato empaquetado.
  La versión informativa del modelo en Ajustes es 2.0.0.

## Archivos y responsabilidades

| Archivo | Responsabilidad y cambio |
|---|---|
| `ml/preprocessing.py` | Contrato de entrada Python con ecuaciones documentadas |
| `lib/services/model_image_preprocessor.dart` | Mismo muestreo en Flutter y conversión explícita a RGB8 |
| `ml/train_model.py` | Carga estricta, entrenamiento, selección, evaluación, exportación y reexportación sin entrenar |
| `ml/run_pipeline.py` | Validación y publicación condicionada a evidencias del binario exacto |
| `ml/requirements.txt` | Versiones del entorno que realmente ejecutó el entrenamiento |
| `ml/test_pipeline.py` | Regresiones de RGB/interpolación y bloqueo de publicaciones incompletas |
| `test/model_image_preprocessor_test.dart` | Regresiones Dart: canales, coordenadas, formato de 16 bits y bytes inválidos |
| `scripts/export_preprocessed_images.dart` | Genera tensores con la implementación Dart real para validación cruzada |
| `ml/verify_runtime.py` | Comprueba hashes y compara Python/Dart usando el modelo publicado |
| `lib/config/app_config.dart` | Identifica la revisión 2.0.0 del modelo |
| `pubspec.yaml` | Incluye el contrato de modelo como recurso Flutter |
| `assets/models/` | Modelo, etiquetas y `model_contract.json` sincronizados |
| `ml/artifacts/` | Checkpoints, selección, división, métricas y verificación reproducibles |
| `README.md`, `ml/DATASET_REPORT.md`, documentación | Actualizan instrucciones y distinguen la auditoría anterior del estado actual |

Los comentarios explican decisiones y contratos. No se modificó el esquema de
SQLite ni la estructura de navegación. Los archivos completos están integrados
localmente; no es necesario copiar fragmentos desde este documento.

## Evidencias

- `ml/artifacts/evaluation_metrics.json`: evaluación por clase, matriz numérica,
  puntuaciones por imagen, paridad y comparación descriptiva con el modelo previo.
- `ml/artifacts/runtime_verification.json`: salidas sobre tensores de Dart.
- `ml/artifacts/confusion_matrix.png`: matriz del modelo Keras en test interno.
- `ml/artifacts/selected_model.keras`: pesos elegidos; no se publica en la app.
- `ml/artifacts/training_selection.json`: selección y hashes para reexportar.
- `ml/artifacts/previous_runtime/`: copia conservada del modelo y etiquetas previos.
- `build/training_run.log` y `build/export_run.log`: registros de esta ejecución.

SHA-256 del modelo publicado:
`c33c19b4ec1e09a8f30b19bf24cee3c80892273da06f56b5419b7c46bc4ea094`.

El entrenamiento se completó antes de fallar la primera conversión. La segunda
exportación reutilizó `selected_model.keras`; no se volvieron a entrenar ni a
seleccionar pesos mirando test. Se recuperaron las pérdidas evaluando los
checkpoints guardados sobre validación, y las curvas de la cabeza desde las 24
épocas del registro de consola (cuatro decimales). El ajuste fino ejecutó diez
épocas y restauró los pesos de la sexta. Una nueva ejecución guarda la selección
y las curvas antes de convertir. Los checkpoints son archivos grandes excluidos de Git por la regla
existente; conservarlos aparte junto con métricas y hashes.

## Reproducir

Entorno ejecutado: Python 3.13.5, TensorFlow 2.21.0, Keras 3.14.0, NumPy 2.3.1,
Pillow 12.3.0, scikit-learn 1.8.0, CPU Windows. El entorno local reutilizó las
bibliotecas globales e instaló Pillow dentro de `.venv-ml`. Para un equipo nuevo,
crear un entorno limpio e instalar `ml/requirements.txt`. En este equipo,
`python` sin ruta apunta a MSYS2; usar el ejecutable CPython indicado abajo.
En otro equipo, sustituir esa ruta por su instalación de CPython 3.13.

```powershell
& "$env:LOCALAPPDATA/Programs/Python/Python313/python.exe" -m venv .venv-ml
.venv-ml/Scripts/python -m pip install -r ml/requirements.txt
.venv-ml/Scripts/python ml/test_pipeline.py
.venv-ml/Scripts/python ml/run_pipeline.py

dart run scripts/export_preprocessed_images.dart
.venv-ml/Scripts/python ml/verify_runtime.py
dart analyze lib test scripts/export_preprocessed_images.dart
flutter test --no-pub
flutter build apk --release --target-platform android-arm64 --no-pub
```

Para reexportar los mismos pesos tras un fallo de conversión:

```powershell
.venv-ml/Scripts/python ml/train_model.py --export-only
.venv-ml/Scripts/python ml/run_pipeline.py --copy-only
```

El primer comando exige checkpoint, manifiesto y preprocesamiento compatibles.
Guardar los artefactos de cada ejecución antes de volver a entrenar. Las semillas
reducen variación, pero versiones de kernels/hardware pueden variar resultados.

## Validación adicional necesaria

No había dispositivo conectado a ADB. Probar en un teléfono Android ARM64:
inicio/carga, permisos concedidos y denegados, captura, resultados, guardado,
reinicio, historial, notas, favoritos, borrado y vuelta desde segundo plano.
Comprobar que imágenes de objetos ajenos no se interpreten como una garantía.

Ampliar fotografías reales de todas las clases (varios teléfonos, fondos,
orientaciones e iluminación), revisar pares similares y reservar un conjunto
externo. La división evita duplicados **exactos** entre conjuntos; no certifica
la ausencia de tomas muy parecidas ni del mismo objeto. Revisarlas antes de
interpretar estas cifras como una medida de generalización. Elegir umbrales en
validación y evaluar una vez en el conjunto externo reservado.

## Referencias técnicas

- [Transferencia y ajuste fino, TensorFlow](https://www.tensorflow.org/tutorials/images/transfer_learning): base preentrenada, normalización y BatchNormalization en modo inferencia.
- [Cuantización float16, TensorFlow](https://blog.tensorflow.org/2019/08/tensorflow-model-optimization-toolkit_5.html): reducción de almacenamiento de pesos manteniendo interfaces de punto flotante.

## Comprobaciones de código completadas

- 21 pruebas Flutter aprobadas, incluidas las dos regresiones nuevas de imagen.
- 3 pruebas Python aprobadas.
- Análisis de `lib`, `test` y el exportador Dart sin incidencias.
- Verificación cruzada Python/Dart completada con 27 imágenes.
- ADB no encontró teléfonos ni emuladores conectados.

## APK generado y comprobado

Compilación release ARM64 completada. Instalador:
`dist/CUAC-modelo-2.0.0-arm64.apk`.

Se abrió el APK como ZIP y se verificó byte a byte que incluye el modelo,
las etiquetas y el contrato evaluados. El código Flutter se compiló para ARM64; algunas dependencias incluyen
bibliotecas adicionales para otras arquitecturas. El destino validado de
compilación es ARM64.
`apksigner verify --verbose` confirmó firma válida v1 y v2, con un firmante.
Los permisos/cámara requieren prueba en un teléfono; no había ninguno conectado
para comprobar instalación y uso real.

SHA-256 del APK: `0f1bb157c051b8442041b107093e9c26c97ad640674c134f462683d8010fc6ee`.
