import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/tflite_service.dart';
import '../services/camera_service.dart';
import '../services/database_service.dart';
import '../services/image_processing_service.dart';
import '../models/scan_history.dart';
import '../models/prediction.dart';

// -----------------------------------------------------------------------------
// Dependencias de infraestructura
// -----------------------------------------------------------------------------
// Cada Provider crea una instancia perezosa y Riverpod la conserva dentro de su
// ProviderContainer. Los servicios encapsulan APIs técnicas; sus cambios de UI se
// representan por separado mediante estados y notifiers.

/// Expone el servicio que carga y ejecuta el modelo TensorFlow Lite local.
final tfliteServiceProvider = Provider<TFLiteService>((ref) {
  return TFLiteService();
});

/// Expone una única abstracción para inicializar y controlar la cámara nativa.
final cameraServiceProvider = Provider<CameraService>((ref) {
  return CameraService();
});

/// Centraliza las consultas y operaciones CRUD sobre la base SQLite local.
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});

/// Carga, valida, transforma y persiste las fotografías de los escaneos.
final imageProcessingServiceProvider = Provider<ImageProcessingService>((ref) {
  return ImageProcessingService();
});

// -----------------------------------------------------------------------------
// Inicialización asíncrona
// -----------------------------------------------------------------------------

/// Prepara el modelo antes de permitir el acceso al flujo de captura.
///
/// FutureProvider expone de manera uniforme los estados de carga, dato y error a
/// la pantalla de inicio, y evita que esa pantalla administre el Future a mano.
final initializationProvider = FutureProvider<void>((ref) async {
  final tflite = ref.watch(tfliteServiceProvider);
  await tflite.initialize();
});

// -----------------------------------------------------------------------------
// Datos derivados y consultas asíncronas
// -----------------------------------------------------------------------------

/// Obtiene el registro más reciente o `null` cuando todavía no existe historial.
final lastScanProvider = FutureProvider<ScanHistory?>((ref) async {
  final db = ref.watch(databaseServiceProvider);
  final scans = await db.getAllScans();
  return scans.isNotEmpty ? scans.first : null;
});

/// Consulta el historial completo respetando el orden definido por la base.
final allScansProvider = FutureProvider<List<ScanHistory>>((ref) async {
  final db = ref.watch(databaseServiceProvider);
  return await db.getAllScans();
});

/// Consulta únicamente los registros marcados como favoritos.
final favoritesProvider = FutureProvider<List<ScanHistory>>((ref) async {
  final db = ref.watch(databaseServiceProvider);
  return await db.getFavoritesScans();
});

/// Calcula las estadísticas agregadas a partir del historial persistido.
final statisticsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final db = ref.watch(databaseServiceProvider);
  return await db.getStatistics();
});

/// Expone el número total de identificaciones guardadas.
final scanCountProvider = FutureProvider<int>((ref) async {
  final db = ref.watch(databaseServiceProvider);
  return await db.getScanCount();
});

// -----------------------------------------------------------------------------
// Coordinadores de casos de uso
// -----------------------------------------------------------------------------

/// Coordina el análisis de una fotografía y la persistencia de su resultado.
///
/// Mantener este flujo fuera de los widgets permite que validación, inferencia y
/// manejo de errores sigan el mismo orden independientemente de la pantalla.
class PredictionNotifier extends StateNotifier<PredictionState> {
  /// Referencia al contenedor para resolver servicios e invalidar consultas.
  final Ref ref;

  PredictionNotifier(this.ref) : super(const PredictionState.idle());

  /// Valida y procesa una fotografía antes de ejecutar el modelo local.
  ///
  /// Cada salida anticipada deja un estado de error descriptivo para que la
  /// interfaz nunca permanezca indefinidamente en carga.
  Future<void> predict(String imagePath) async {
    state = const PredictionState.loading();
    try {
      final imageProc = ref.read(imageProcessingServiceProvider);
      final tflite = ref.read(tfliteServiceProvider);

      // Se rechaza una entrada dañada o incompatible antes de gastar recursos
      // en el redimensionamiento y la inferencia.
      final validation = await imageProc.validateImage(imagePath);
      if (!validation.isValid) {
        state = PredictionState.error(validation.message);
        return;
      }

      // Aquí se leen bytes y, si pesan demasiado, se comprimen. La conversión
      // a tensor RGB normalizado ocurre después, dentro de TFLiteService.
      final imageBytes = await imageProc.loadAndProcessImage(imagePath);
      if (imageBytes == null) {
        state = const PredictionState.error('No se pudo procesar la imagen');
        return;
      }

      if (!tflite.isInitialized) {
        // La inicialización diferida protege este flujo si se abrió sin pasar por
        // el splash o si el servicio tuvo que reconstruirse.
        await tflite.initialize();
      }

      // La inferencia sucede completamente en el dispositivo.
      final results = await tflite.predict(imageBytes);

      if (results.isEmpty) {
        state = const PredictionState.error('No se obtuvieron predicciones');
        return;
      }

      // Se traduce la salida técnica del intérprete al modelo usado por la UI y
      // se añade una categoría comprensible para cada etiqueta conocida.
      final predictions = results
          .map((r) => Prediction(
                name: r.label,
                confidence: r.confidence,
                category: _getCategoryForLabel(r.label),
              ))
          .toList();

      state = PredictionState.success(predictions);
    } catch (e) {
      state = PredictionState.error('Error en predicción: $e');
    }
  }

  /// Guarda la predicción activa y una copia permanente de su fotografía.
  ///
  /// Requiere un estado exitoso; así se evita crear registros incompletos. Si la
  /// escritura en SQLite falla, intenta eliminar la copia de imagen para reducir
  /// la posibilidad de dejar archivos huérfanos en el almacenamiento local.
  Future<ScanHistory> saveCurrentScan(
    String imagePath, {
    String? notes,
  }) async {
    final currentState = state;
    if (currentState is! _PredictionSuccess ||
        currentState.predictions.isEmpty) {
      throw StateError('No existe una predicción para guardar');
    }

    final predictions = currentState.predictions;
    final topPrediction = predictions.first;
    final db = ref.read(databaseServiceProvider);
    final imageProc = ref.read(imageProcessingServiceProvider);
    final now = DateTime.now();
    final id = now.microsecondsSinceEpoch.toString();
    final normalizedNotes = notes?.trim();
    // Se procesa de nuevo la ruta original para persistir una versión optimizada
    // e independiente del archivo temporal producido por la cámara.
    final imageBytes = await imageProc.loadAndProcessImage(imagePath);

    if (imageBytes == null) {
      throw StateError('No se pudo preparar la imagen para guardarla');
    }

    final savedPath = await imageProc.saveImage(imageBytes, 'scan_$id.jpg');
    if (savedPath == null) {
      throw StateError('No se pudo guardar una copia permanente de la imagen');
    }

    final scanHistory = ScanHistory(
      id: id,
      timestamp: now,
      imagePath: savedPath,
      predictedInstrument: topPrediction.name,
      confidence: topPrediction.confidence,
      top3Predictions: predictions.take(3).toList(growable: false),
      userNotes: normalizedNotes == null || normalizedNotes.isEmpty
          ? null
          : normalizedNotes,
      location: null,
      isFavorite: false,
    );

    try {
      await db.insertScan(scanHistory);
    } catch (_) {
      // Se intenta revertir la copia si falla SQLite para reducir la posibilidad
      // de dejar una imagen sin un registro que permita consultarla o eliminarla.
      await imageProc.deleteImage(savedPath);
      rethrow;
    }

    // Las consultas memorizadas deben recalcularse después de insertar el nuevo
    // registro para que historial, contador y estadísticas se actualicen.
    ref.invalidate(allScansProvider);
    ref.invalidate(lastScanProvider);
    ref.invalidate(scanCountProvider);
    ref.invalidate(statisticsProvider);
    return scanHistory;
  }

  /// Asocia las etiquetas del modelo con categorías funcionales para la UI.
  ///
  /// La comparación ignora mayúsculas, minúsculas y espacios sobrantes porque
  /// la etiqueta puede proceder del archivo de recursos o de la lista de respaldo.
  /// Las etiquetas nuevas conservan el valor seguro «Otros» hasta ser mapeadas.
  String _getCategoryForLabel(String label) {
    const categories = {
      'microscopio': 'Óptica',
      'probeta': 'Medición',
      'matraces': 'Contenedores',
      'pipetas': 'Medición',
      'vasos de precipitado': 'Contenedores',
      'buretas': 'Dosificación',
      'embudos': 'Transferencia',
      'pinzas': 'Sujeción',
      'gradillas': 'Organización',
      'crisoles': 'Calentamiento',
    };
    final normalizedLabel =
        label.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    return categories[normalizedLabel] ?? 'Otros';
  }
}

/// Expone [PredictionNotifier] junto con su estado observable.
final predictionNotifierProvider =
    StateNotifierProvider<PredictionNotifier, PredictionState>((ref) {
  return PredictionNotifier(ref);
});

/// Coordina consultas y modificaciones sobre el historial persistente.
class HistoryNotifier extends StateNotifier<HistoryState> {
  /// Acceso al contenedor de Riverpod para invalidar datos derivados.
  final Ref ref;

  /// Servicios resueltos una sola vez durante la construcción del notifier.
  final DatabaseService _database;
  final ImageProcessingService _imageProcessing;

  HistoryNotifier(this.ref)
      : _database = ref.read(databaseServiceProvider),
        _imageProcessing = ref.read(imageProcessingServiceProvider),
        super(const HistoryState.idle());

  /// Carga todos los registros desde SQLite y los publica en el estado.
  Future<void> loadHistory() async {
    state = const HistoryState.loading();
    try {
      final scans = await _database.getAllScans();
      state = HistoryState.success(scans);
    } catch (e) {
      state = HistoryState.error('Error al cargar historial: $e');
    }
  }

  /// Sustituye el contenido visible por los registros marcados como favoritos.
  Future<void> loadFavorites() async {
    state = const HistoryState.loading();
    try {
      final scans = await _database.getFavoritesScans();
      state = HistoryState.success(scans);
    } catch (e) {
      state = HistoryState.error('Error al cargar favoritos: $e');
    }
  }

  /// Consulta los escaneos comprendidos entre el inicio de hoy y el de mañana.
  Future<void> loadTodayScans() async {
    state = const HistoryState.loading();
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(Duration(days: 1));

      final scans = await _database.getScansByDateRange(today, tomorrow);
      state = HistoryState.success(scans);
    } catch (e) {
      state = HistoryState.error('Error al cargar escaneos: $e');
    }
  }

  /// Consulta una ventana móvil de los últimos siete días hasta el momento actual.
  Future<void> loadWeekScans() async {
    state = const HistoryState.loading();
    try {
      final now = DateTime.now();
      final weekAgo = now.subtract(Duration(days: 7));

      final scans = await _database.getScansByDateRange(weekAgo, now);
      state = HistoryState.success(scans);
    } catch (e) {
      state = HistoryState.error('Error al cargar escaneos: $e');
    }
  }

  /// Elimina un registro e intenta borrar también su fotografía almacenada.
  ///
  /// Devuelve `true` únicamente cuando SQLite confirma al menos una fila
  /// eliminada. Las consultas derivadas se invalidan, pero el llamador decide
  /// qué filtro del historial debe volver a cargar.
  Future<bool> deleteScan(String id) async {
    try {
      final scan = await _database.getScanById(id);
      final affectedRows = await _database.deleteScan(id);
      if (affectedRows <= 0) {
        state =
            const HistoryState.error('No se encontró el escaneo a eliminar');
        return false;
      }

      if (scan != null) {
        await _imageProcessing.deleteImage(scan.imagePath);
      }
      _invalidateHistoryProviders();
      return true;
    } catch (e) {
      state = HistoryState.error('Error al eliminar: $e');
      return false;
    }
  }

  /// Invierte la marca de favorito y confirma si SQLite modificó el registro.
  /// El llamador conserva la responsabilidad de recargar el filtro visible.
  Future<bool> toggleFavorite(String id) async {
    try {
      final affectedRows = await _database.toggleFavorite(id);
      if (affectedRows <= 0) {
        state =
            const HistoryState.error('No se encontró el escaneo a actualizar');
        return false;
      }

      _invalidateHistoryProviders();
      return true;
    } catch (e) {
      state = HistoryState.error('Error al actualizar: $e');
      return false;
    }
  }

  /// Vacía el historial e intenta eliminar las fotografías asociadas localmente.
  Future<void> clearHistory() async {
    try {
      final scans = await _database.getAllScans();
      await _database.clearHistory();
      for (final scan in scans) {
        await _imageProcessing.deleteImage(scan.imagePath);
      }
      _invalidateHistoryProviders();
      state = const HistoryState.success([]);
    } catch (e) {
      state = HistoryState.error('Error al limpiar: $e');
    }
  }

  /// Devuelve las estadísticas calculadas por la capa de persistencia.
  Future<Map<String, dynamic>> getStatistics() async {
    return await _database.getStatistics();
  }

  /// Serializa el historial completo como texto JSON para su exportación.
  Future<String> exportAsJSON() async {
    return await _database.exportHistoryAsJson();
  }

  /// Serializa el historial completo como texto CSV para su exportación.
  Future<String> exportAsCSV() async {
    return await _database.exportHistoryAsCSV();
  }

  /// Fuerza a Riverpod a recalcular toda consulta afectada por una modificación.
  void _invalidateHistoryProviders() {
    ref.invalidate(allScansProvider);
    ref.invalidate(favoritesProvider);
    ref.invalidate(lastScanProvider);
    ref.invalidate(scanCountProvider);
    ref.invalidate(statisticsProvider);
  }
}

/// Expone [HistoryNotifier] junto con su estado observable.
final historyNotifierProvider =
    StateNotifierProvider<HistoryNotifier, HistoryState>((ref) {
  return HistoryNotifier(ref);
});

// -----------------------------------------------------------------------------
// Estados sellados de los flujos principales
// -----------------------------------------------------------------------------
// Las jerarquías selladas hacen explícitos todos los estados posibles. Sus
// extensiones `when` permiten que la UI resuelva inactivo, carga, éxito y error.

/// Estado de una operación de reconocimiento.
sealed class PredictionState {
  const PredictionState();

  const factory PredictionState.idle() = _PredictionIdle;
  const factory PredictionState.loading() = _PredictionLoading;
  const factory PredictionState.success(List<Prediction> predictions) =
      _PredictionSuccess;
  const factory PredictionState.error(String message) = _PredictionError;
}

/// Estado inicial, antes de recibir una fotografía para analizar.
class _PredictionIdle extends PredictionState {
  const _PredictionIdle();
}

/// Indica que la imagen se está preparando o analizando.
class _PredictionLoading extends PredictionState {
  const _PredictionLoading();
}

/// Contiene las predicciones ordenadas devueltas por el modelo.
class _PredictionSuccess extends PredictionState {
  final List<Prediction> predictions;
  const _PredictionSuccess(this.predictions);
}

/// Conserva el mensaje que la interfaz debe presentar ante un fallo.
class _PredictionError extends PredictionState {
  final String message;
  const _PredictionError(this.message);
}

/// Estado de una consulta del historial local.
sealed class HistoryState {
  const HistoryState();

  const factory HistoryState.idle() = _HistoryIdle;
  const factory HistoryState.loading() = _HistoryLoading;
  const factory HistoryState.success(List<ScanHistory> scans) = _HistorySuccess;
  const factory HistoryState.error(String message) = _HistoryError;
}

/// Estado inicial, antes de ejecutar una consulta.
class _HistoryIdle extends HistoryState {
  const _HistoryIdle();
}

/// Indica que SQLite está resolviendo la consulta solicitada.
class _HistoryLoading extends HistoryState {
  const _HistoryLoading();
}

/// Contiene la lista resultante, que también puede estar vacía.
class _HistorySuccess extends HistoryState {
  final List<ScanHistory> scans;
  const _HistorySuccess(this.scans);
}

/// Conserva el mensaje generado cuando la consulta o modificación falla.
class _HistoryError extends HistoryState {
  final String message;
  const _HistoryError(this.message);
}

/// Permite consumir [PredictionState] como un patrón exhaustivo desde la UI.
extension PredictionStateX on PredictionState {
  /// Ejecuta la función correspondiente al subtipo concreto del estado.
  T when<T>({
    required T Function() idle,
    required T Function() loading,
    required T Function(List<Prediction> predictions) success,
    required T Function(String message) error,
  }) {
    if (this is _PredictionIdle) return idle();
    if (this is _PredictionLoading) return loading();
    if (this is _PredictionSuccess) {
      return success((this as _PredictionSuccess).predictions);
    }
    if (this is _PredictionError) {
      return error((this as _PredictionError).message);
    }
    throw StateError('Unhandled PredictionState: $this');
  }
}

/// Permite consumir [HistoryState] como un patrón exhaustivo desde la UI.
extension HistoryStateX on HistoryState {
  /// Ejecuta la función correspondiente al subtipo concreto del estado.
  T when<T>({
    required T Function() idle,
    required T Function() loading,
    required T Function(List<ScanHistory> scans) success,
    required T Function(String message) error,
  }) {
    if (this is _HistoryIdle) return idle();
    if (this is _HistoryLoading) return loading();
    if (this is _HistorySuccess) {
      return success((this as _HistorySuccess).scans);
    }
    if (this is _HistoryError) {
      return error((this as _HistoryError).message);
    }
    throw StateError('Unhandled HistoryState: $this');
  }
}
