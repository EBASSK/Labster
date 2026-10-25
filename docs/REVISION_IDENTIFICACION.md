# Revisión de identificación y documentación de CUAC

> Registro de la primera revisión. La autorización posterior permitió
> reentrenar y reemplazar el modelo: el estado vigente está en
> [Entrenamiento verificado](ENTRENAMIENTO_VERIFICADO.md).

## Alcance y evidencia

Revisión del código local, los recursos y los artefactos disponibles. No se
reentrenó ni sustituyó el modelo y no se afirma una mejora de precisión.
Los comentarios útiles existentes se conservaron; no se comentaron líneas
triviales ni se editó `scan_history.g.dart`, que es generado.

Flujo real: `CameraScreen._captureAndPredict` → `PredictionNotifier.predict`
→ validación y lectura de imagen → `TFLiteService.predict` →
`ModelImagePreprocessor.preprocess` → intérprete → ordenación de puntuaciones
→ estado éxito/error → `ResultsScreen`. Guardar es una acción separada:
copia de fotografía → inserción SQLite → invalidación de consultas Riverpod.
La pantalla de cámara revisada captura fotografías; no se encontró un selector
de galería en ese flujo.

## Diagnóstico: hechos y límites

- El tensor construido en Dart es RGB, lote uno, 224 × 224, canales en orden
  rojo/verde/azul y división por 255. Se aplica orientación EXIF y se deforma
  directamente al cuadrado, sin recorte ni relleno.
- El script actual de entrenamiento también divide por 255 y añade dentro de
  la red `Rescaling(2, -1)` antes de MobileNetV2. No demuestra que el binario
  empaquetado se entrenara con ese script: `ml/DATASET_REPORT.md` indica que
  el modelo no fue reemplazado en aquella auditoría. No se cambió el rango.
- El entrenamiento usa LANCZOS y Dart interpolación cúbica. Hay diferencia de
  píxeles potencial, sin evidencia comparativa que mida su efecto. Hace falta
  contrastar tensores y predicciones con el entrenamiento original.
- `assets/models/labels.txt` coincide en orden con
  `ml/artifacts/class_mapping.json`: diez clases, de buretas a vasos.
  Esa concordancia no certifica por sí sola la procedencia del binario.
- Error comprobado: `vasos_precipitado` se convertía en `Vasos precipitado`,
  pero la categoría esperaba `Vasos de precipitado`. La clase podía aparecer
  como «Otros». El alias corregido no cambia su índice ni su puntuación.
- La validación anterior solo comprobaba la última dimensión de salida;
  aceptaba contratos incompatibles con el búfer `[1, clases]` usado en `run`.
  Ahora exige una entrada y una salida, formas exactas y tipo float32 en ambas.
  No se añadió soporte de entrada/salida cuantizada.
- La ausencia de etiquetas permitía inferir con una lista supuesta. Ahora la
  inicialización falla y permite reintentar desde Splash. El respaldo queda
  únicamente como información después del fallo; el servicio no queda listo.
- Se rechazan NaN e infinitos antes de normalizar, ordenar o mostrar resultados.
  La heurística softmax existente se conserva; ni softmax ni una suma cercana
  a uno demuestran calibración o probabilidad de acierto.
- Se conserva el umbral 0,5 como aviso provisional, sin atribuirle fiabilidad
  validada. No bloquea el guardado. Los consejos aparecen por debajo de 0,7;
  son una regla visual distinta, ya documentada en el código.

## Cambios por archivo

| Archivo | Responsabilidad | Documentación y motivo | Cambio funcional |
|---|---|---|---|
| `lib/services/tflite_service.dart` | Carga, inferencia y etiquetas | Contrato exacto, rechazo de cuantización, orden de clases, alias y límites de softmax | Validación de tensores, etiquetas obligatorias sin vacíos/duplicados, lista pública no modificable, alias de vasos y rechazo de salidas no finitas |
| `lib/services/model_image_preprocessor.dart` | Imagen a tensor RGB | Distingue el script disponible del entrenamiento original y explica la diferencia de interpolación | Ninguno |
| `lib/services/image_processing_service.dart` | Lectura, validación y archivos | Explica que el mínimo 224 × 224 es una política de calidad, no una necesidad del decodificador | Ninguno |
| `lib/config/app_config.dart` | Constantes compartidas | Declara provisional el umbral y aclara que no filtra ni bloquea el guardado | Ninguno |
| `lib/models/prediction.dart` | Resultado para UI y JSON | Puntuación sin calibración comprobada; los cortes cualitativos no son universales | Ninguno |
| `lib/providers/providers.dart` | Coordinación y estados | Separa lectura/compresión de conversión a tensor; evita atribuir responsabilidades al servicio equivocado | Ninguno |
| `lib/services/database_service.dart` | Historial SQLite | Explica ruta frente a bytes, propagación de errores, compensación y límites de tolerancia al JSON dañado | Ninguno |
| `lib/screens/results_screen.dart` | Resultados, carga, error y guardado | Explica el aviso provisional y que guardar no verifica la identificación | «Instrumento sugerido», «Identificación no concluyente» y «Puntuación» |
| `docs/REVISION_IDENTIFICACION.md` | Guía para revisión y presentación | Evidencia, ejemplos, verificación y pendientes | Ninguno |

Splash, cámara, historial, detalle y ajustes ya documentan clases, métodos,
recuperación de errores y estados. Se revisaron sus comentarios principales
sin añadir texto repetitivo. SQLite conserva esquema e interfaces existentes.
Los archivos completos actualizados están integrados en sus rutas originales.

## Ejemplos antes y después

Antes, en `Prediction.confidence`:

```dart
/// Probabilidad normalizada entre 0.0 y 1.0 devuelta por el modelo.
```

Después:

```dart
/// Puntuación normalizada entre 0.0 y 1.0; no es una probabilidad de acierto
/// calibrada. Se conserva el nombre `confidence` por compatibilidad con SQLite.
```

Antes, en el coordinador, el comentario atribuía la adaptación al lector:

```dart
// El servicio adapta formato, tamaño y canales a la entrada del modelo.
final imageBytes = await imageProc.loadAndProcessImage(imagePath);
```

Después, la llamada se conserva y el comentario sitúa cada responsabilidad:

```dart
// Aquí se leen bytes y, si pesan demasiado, se comprimen. La conversión
// a tensor RGB normalizado ocurre después, dentro de TFLiteService.
final imageBytes = await imageProc.loadAndProcessImage(imagePath);
```

Antes la validación de salida aceptaba cualquier rango con última dimensión
igual al número de clases. Después se compara la forma completa:

```dart
if (!_sameShape(outputTensor.shape, [1, _labels.length])) {
  throw StateError(
    'El modelo produce ${outputTensor.shape} pero existen '
    '${_labels.length} etiquetas',
  );
}
```

## Datos y evaluación pendiente

El informe histórico registra 133 imágenes válidas, 11–16 por clase, 44 con
algún lado menor de 224 y nueve pares similares entre clases. No son métricas
nuevas de esta revisión. La auditoría almacenada desglosa: buretas 12,
crisoles 11, embudos 15, gradillas 12, matraces 15, microscopio 12, pinzas 14,
pipetas 16, probeta 14 y vasos 12. La similitud automática no demuestra que
las etiquetas estén mal; requiere inspección visual.

Hay checkpoint H5 y registro histórico de entrenamiento, pero no se encontraron
`evaluation_metrics.json` ni `confusion_matrix.png` en `ml/artifacts`.
El 95,45 % histórico no es una evaluación nueva ni prueba de precisión móvil.
Para confirmar la causa del reconocimiento se necesita la versión exacta del
entrenamiento/exportación del binario y fotografías externas etiquetadas.

## Cómo verificar

1. Ejecutar `dart analyze lib test` y `flutter test --no-pub`. Las pruebas de
   preprocesamiento existentes verifican forma, canales, rango de una imagen
   roja y rechazo de bytes inválidos. La suite de widgets comprueba parte de
   navegación, carga/error y apariencia; no mide precisión del modelo nativo.
2. En Android, iniciar con los recursos actuales, capturar y guardar. Abrir
   historial y detalle, reiniciar la app y comprobar notas, imagen y top 3.
3. Verificar que la clase 9 se presenta como «Vasos de precipitado» y categoría
   «Contenedores». Los registros históricos ya guardados no se migran.
4. En una copia de pruebas, retirar `labels.txt` o introducir una línea vacía
   intermedia/duplicada: Splash debe mostrar error y permitir reintento tras
   restaurar el recurso. No publicar esos recursos de prueba.
5. Probar modelos de prueba con salida de forma/tipo incompatible: la carga
   debe fallar explícitamente. Probar NaN/infinito mediante un modelo controlado:
   debe producir error, nunca un resultado guardable. Estos casos nativos
   requieren ejecución adicional; no están cubiertos por los widgets actuales.
6. Comparar el tensor Python y Dart para la misma imagen: orientación, canales,
   dimensiones, valores y salida. Documentar la tolerancia de interpolación antes
   de modificarla. Confirmar también el contrato real del binario desplegado.

## Plan de fotografías y futuras mejoras

Preparar un conjunto externo por clase, sin reutilizar fotos del entrenamiento
ni tomas casi idénticas. Incluir fondos claros y oscuros, luz natural/artificial,
rotaciones, distintas distancias, manos, objetos parcialmente tapados y pares
confundibles (pipeta/bureta/probeta). Añadir imágenes sin instrumentos y con
varios: el clasificador cerrado puede asignarles una clase con puntuación alta.

Registrar imagen, clase real, top 1, top 3 y puntuaciones con el mismo binario
antes/después; conservar dispositivo y condiciones. Calcular matriz de confusión,
precisión y exhaustividad por clase, top 1/top 3 y errores de alta puntuación.
Seleccionar el umbral en validación según errores aceptables y cobertura; evaluar
una única vez en el conjunto de prueba reservado. No ajustar con esas fotos.

Si persisten errores: ampliar y equilibrar fotografías reales por clase, revisar
etiquetas y pares similares, separar tomas del mismo objeto entre conjuntos de
forma que no haya fuga, reentrenar y exportar modelo/etiquetas juntos. Conservar
hashes, configuración, métricas y prueba de paridad Keras/TFLite de cada versión.

## Verificación ejecutada en esta revisión

- `dart analyze lib test`: sin incidencias.
- `flutter test --no-pub`: 19 pruebas aprobadas.
- `dart format lib/services/tflite_service.dart`: completado.
- Comparación binaria: los modelos en `assets/models` y `ml/artifacts` son iguales.
- SHA-256 del modelo: `407c37ed3485fa80035cde710442fe1f83465582011e44f59e4c9a2e50a8b089`.
- El recuento de archivos de imagen coincide con las 133 entradas históricas;
  la carpeta de vasos contiene además un PDF, que no es una muestra de imagen.
- No se ejecutó inferencia nativa en Android, evaluación comparativa, calibración
  ni entrenamiento. Las nuevas validaciones del intérprete requieren los casos
  de prueba nativos descritos arriba. No se afirma aumento de precisión.
