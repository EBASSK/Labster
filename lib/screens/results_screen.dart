import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/providers.dart';
import '../models/prediction.dart';
import '../config/theme.dart';
import '../config/app_config.dart';

/// Presenta el estado y los resultados de la clasificación de una captura.
///
/// También permite añadir notas y guardar hasta tres predicciones en historial.
class ResultsScreen extends ConsumerStatefulWidget {
  /// Ruta local de la fotografía que originó la predicción actual.
  final String imagePath;

  const ResultsScreen({
    super.key,
    required this.imagePath,
  });

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen> {
  /// Conserva las notas escritas mientras la pantalla permanece abierta.
  late TextEditingController _notesController;

  /// Bloquea envíos duplicados mientras se persiste el escaneo.
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // El controlador pertenece a esta pantalla y se libera en `dispose`.
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Escucha con Riverpod el estado del análisis iniciado desde la cámara.
    // Cualquier transición del notifier reconstruye únicamente esta pantalla.
    final predictionState = ref.watch(predictionNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resultado'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(), // Regresa a la cámara anterior.
        ),
      ),
      // Selecciona la interfaz correspondiente al estado asíncrono del análisis.
      body: predictionState.when(
        idle: () => _buildEmptyState(context), // No hay análisis iniciado.
        loading: () => _buildLoadingState(), // La inferencia está en curso.
        success: (predictions) =>
            _buildSuccessState(context, predictions), // Análisis completado.
        error: (error) => _buildErrorState(context, error), // Análisis fallido.
      ),
    );
  }

  /// Estado vacío mostrado si se llega sin una predicción activa.
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_not_supported,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'Sin imagen',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Captura una imagen para ver el resultado',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.pop(), // Vuelve a la cámara.
            icon: const Icon(Icons.camera_alt),
            label: const Text('Capturar'),
          ),
        ],
      ),
    );
  }

  /// Estado de progreso mientras el modelo local procesa la imagen.
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(), // Indicador de trabajo en curso.
          const SizedBox(height: 16),
          Text(
            'Analizando imagen...',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Por favor espera',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  /// Recomendaciones para mejorar una captura con baja confianza.
  Widget _buildTipsCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.paddingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.tune_outlined,
                  color: colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Mejora la captura',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'El resultado tiene baja confianza. Intenta lo siguiente:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 14),
            _buildTipItem(
              Icons.center_focus_strong_outlined,
              'Centra un solo instrumento dentro del marco.',
            ),
            _buildTipItem(
              Icons.light_mode_outlined,
              'Usa luz uniforme y evita sombras fuertes.',
            ),
            _buildTipItem(
              Icons.filter_center_focus_outlined,
              'Mantén el instrumento enfocado y el fondo despejado.',
            ),
            _buildTipItem(
              Icons.straighten_outlined,
              'Conserva una distancia aproximada de 20 a 30 cm.',
            ),
            _buildTipItem(
              Icons.rotate_90_degrees_ccw_outlined,
              'Cambia ligeramente el ángulo si el resultado no mejora.',
            ),
          ],
        ),
      ),
    );
  }

  /// Elemento reutilizable que alinea el icono y el texto de cada consejo.
  Widget _buildTipItem(IconData icon, String tip) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 19,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tip,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  /// Construye el informe con la predicción principal y sus alternativas.
  /// El aviso depende del umbral provisional de AppConfig; incluso un valor
  /// alto puede ser incorrecto. Guardar conserva la sugerencia, no la valida.
  Widget _buildSuccessState(
    BuildContext context,
    List<Prediction> predictions,
  ) {
    if (predictions.isEmpty) {
      return _buildErrorState(context, 'No se obtuvieron predicciones');
    }

    final topPrediction = predictions.first;
    final top3 = predictions.take(3).toList();
    // Los roles del esquema se resuelven en cada construcción para que estas
    // superficies cambien junto con el tema claro, oscuro o del dispositivo.
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.paddingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Resumen principal: nombre, categoría y nivel de confianza.
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.paddingLG),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              topPrediction.confidence >=
                                      AppConfig.confidenceThreshold
                                  ? 'Instrumento sugerido'
                                  : 'Identificación no concluyente',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              topPrediction.name,
                              style: Theme.of(context).textTheme.displaySmall,
                            ),
                            const SizedBox(height: 4),
                            Container(
                              key: const Key('resultsCategoryBadge'),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                topPrediction.category,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // El borde circular cambia de color según la confianza.
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _getConfidenceColor(topPrediction.confidence)
                              .withValues(alpha: 0.08),
                          border: Border.all(
                            color:
                                _getConfidenceColor(topPrediction.confidence),
                            width: 3,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          // El medidor tiene un diámetro fijo. FittedBox reduce
                          // el bloque únicamente cuando el escalado de texto del
                          // dispositivo no cabe, evitando recortes u overflow.
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${(topPrediction.confidence * 100).toStringAsFixed(0)}%',
                                  style: Theme.of(context)
                                      .textTheme
                                      .displaySmall
                                      ?.copyWith(
                                        color: _getConfidenceColor(
                                          topPrediction.confidence,
                                        ),
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                Text(
                                  'Puntuación',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppTheme.paddingMD),

          // Este 0.7 es solo el umbral visual para mostrar consejos; es
          // independiente del umbral de confianza configurado para el resultado.
          if (topPrediction.confidence < 0.7) _buildTipsCard(context),

          const SizedBox(height: AppTheme.paddingMD),

          // Alternativas restantes dentro de las tres mejores predicciones.
          Text(
            'Otras opciones',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          ...top3.skip(1).map((prediction) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                key: ValueKey('resultsAlternative-${prediction.name}'),
                padding: const EdgeInsets.all(AppTheme.paddingMD),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  border: Border.all(color: colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            prediction.name,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            prediction.category,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Chip(
                      label: Text(
                        '${(prediction.confidence * 100).toStringAsFixed(0)}%',
                      ),
                      backgroundColor:
                          _getConfidenceColor(prediction.confidence)
                              .withValues(alpha: 0.2),
                    ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: AppTheme.paddingMD),

          // Descripción opcional proporcionada por la información de dominio.
          if (topPrediction.description != null) ...[
            Text(
              'Información',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Container(
              key: const Key('resultsInformationCard'),
              padding: const EdgeInsets.all(AppTheme.paddingMD),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              ),
              child: Text(
                topPrediction.description ??
                    'Instrumento de laboratorio identificado correctamente.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: AppTheme.paddingMD),
          ],

          // Campo local que se persiste únicamente al pulsar Guardar.
          Text(
            'Notas (opcional)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Agrega notas sobre este escaneo...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              ),
            ),
          ),

          const SizedBox(height: AppTheme.paddingLG),

          // Acciones para repetir la captura o guardar el resultado actual.
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Nuevo escaneo'),
                  onPressed: () => context.pop(),
                ),
              ),
              const SizedBox(width: AppTheme.paddingMD),
              Expanded(
                child: ElevatedButton.icon(
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: Text(_isSaving ? 'Guardando...' : 'Guardar'),
                  onPressed: _isSaving ? null : _saveScan,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppTheme.paddingMD),
        ],
      ),
    );
  }

  /// Persiste una copia procesada, hasta tres predicciones y las notas escritas.
  Future<void> _saveScan() async {
    setState(() => _isSaving = true);
    try {
      await ref.read(predictionNotifierProvider.notifier).saveCurrentScan(
            widget.imagePath,
            notes: _notesController.text,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Guardado en el historial')),
      );
      // `go` reemplaza el flujo de captura ya completado por el historial.
      context.go('/history');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  /// Presenta el mensaje de error y ofrece regresar para una nueva captura.
  Widget _buildErrorState(BuildContext context, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Error en la predicción',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              error,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.camera_alt),
            label: const Text('Intentar de nuevo'),
          ),
        ],
      ),
    );
  }

  /// Traduce una confianza normalizada a un color semántico de la interfaz.
  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return AppTheme.successColor;
    if (confidence >= 0.6) return AppTheme.warningColor;
    return AppTheme.errorColor;
  }
}
