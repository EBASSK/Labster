import 'dart:io';
import 'package:flutter/material.dart';
import '../widgets/scan_instrument_link.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../models/scan_history.dart';
import '../providers/providers.dart';
import '../config/theme.dart';

/// Muestra toda la información de un escaneo guardado en el historial.
///
/// Puede recibir el registro ya cargado o recuperarlo por identificador, y
/// permite actualizar favorito/notas o eliminarlo de la base de datos local.
class DetailScreen extends ConsumerStatefulWidget {
  /// Identificador usado para consultar o modificar el registro persistido.
  final String scanId;

  /// Registro opcional pasado desde historial para evitar una consulta extra.
  final ScanHistory? scan;

  const DetailScreen({
    super.key,
    required this.scanId,
    this.scan,
  });

  @override
  ConsumerState<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends ConsumerState<DetailScreen> {
  // Copia local necesaria para reflejar inmediatamente las ediciones.
  ScanHistory? _scan;
  bool _isFavorite = false;
  String? _loadError;

  /// Controla el campo editable de notas y se libera junto con la pantalla.
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _scan = widget.scan;
    _isFavorite = _scan?.isFavorite ?? false;
    _notesController = TextEditingController(text: _scan?.userNotes ?? '');

    // Si la navegación no entregó el objeto, se recupera desde la base de
    // datos después del primer cuadro para no modificar estado durante build.
    if (_scan == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadScan();
      });
    }
  }

  /// Busca el escaneo por ID y sincroniza el estado editable de la pantalla.
  Future<void> _loadScan() async {
    try {
      final db = ref.read(databaseServiceProvider);
      final scan = await db.getScanById(widget.scanId);
      if (scan != null && mounted) {
        setState(() {
          _scan = scan;
          _isFavorite = scan.isFavorite;
          _notesController.text = scan.userNotes ?? '';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadError = 'No se pudo cargar el escaneo.');
      }
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Mientras no exista registro, la misma zona muestra carga o error.
    if (_scan == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalles')),
        body: Center(
          child: _loadError == null
              ? const CircularProgressIndicator()
              : Text(_loadError!, textAlign: TextAlign.center),
        ),
      );
    }

    final scan = _scan!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalles del escaneo'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _isFavorite ? AppTheme.errorColor : null,
            ),
            onPressed: () => _toggleFavorite(scan),
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const Text('Eliminar'),
                onTap: () => _deleteScan(scan),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.paddingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Copia procesada que se guardó en el almacenamiento de la app.
            _buildImageSection(scan),

            const SizedBox(height: AppTheme.paddingLG),

            // Resultado principal y porcentaje de confianza.
            _buildPredictionSection(scan),
            ScanInstrumentLink(label: scan.predictedInstrument),

            const SizedBox(height: AppTheme.paddingLG),

            // Momento exacto en que se creó el registro.
            _buildTimestampSection(scan),

            const SizedBox(height: AppTheme.paddingLG),

            // Alternativas del modelo, si fueron guardadas con el escaneo.
            if (scan.top3Predictions.isNotEmpty) ...[
              Text(
                'Otras predicciones',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              _buildAlternativePredictions(scan),
              const SizedBox(height: AppTheme.paddingLG),
            ],

            // Notas editables asociadas al registro local.
            Text(
              'Notas',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Agrega notas sobre este escaneo...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                ),
              ),
            ),

            const SizedBox(height: AppTheme.paddingLG),

            // Persistencia explícita para evitar guardar mientras se escribe.
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _saveNotes(scan),
                icon: const Icon(Icons.save),
                label: const Text('Guardar notas'),
              ),
            ),

            const SizedBox(height: AppTheme.paddingMD),

            // Datos avanzados plegados para no recargar la vista principal.
            _buildTechnicalInfo(scan),
          ],
        ),
      ),
    );
  }

  /// Muestra la copia procesada si todavía existe en su ruta persistente.
  Widget _buildImageSection(ScanHistory scan) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      key: const Key('detailImageSurface'),
      width: double.infinity,
      height: 300,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        color: colorScheme.surfaceContainerHighest,
        image: _imageFileExists(scan.imagePath)
            ? DecorationImage(
                image: FileImage(File(scan.imagePath)),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: !_imageFileExists(scan.imagePath)
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.image_not_supported,
                    size: 48,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Imagen no disponible',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            )
          : null,
    );
  }

  /// Resume la clase detectada y representa visualmente su confianza.
  Widget _buildPredictionSection(ScanHistory scan) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.paddingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Instrumento detectado',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        scan.predictedInstrument,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        key: const Key('detailCategoryBadge'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Categoría',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _getConfidenceColor(scan.confidence)
                        .withValues(alpha: 0.08),
                    border: Border.all(
                      color: _getConfidenceColor(scan.confidence),
                      width: 3,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${scan.confidencePercentage}%',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: _getConfidenceColor(scan.confidence),
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        Text(
                          'Confianza',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Formatea la fecha persistida con día, mes, año y hora local.
  Widget _buildTimestampSection(ScanHistory scan) {
    final formatter = DateFormat('dd/MM/yyyy HH:mm:ss');
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.paddingMD),
        child: Row(
          children: [
            Icon(
              Icons.schedule,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fecha y hora',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatter.format(scan.timestamp),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Lista las predicciones secundarias, excluyendo la primera ya destacada.
  Widget _buildAlternativePredictions(ScanHistory scan) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: scan.top3Predictions.skip(1).map((prediction) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            key: ValueKey('detailAlternative-${prediction.name}'),
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
                  backgroundColor: _getConfidenceColor(prediction.confidence)
                      .withValues(alpha: 0.2),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Agrupa metadatos de diagnóstico que normalmente no necesita el usuario.
  Widget _buildTechnicalInfo(ScanHistory scan) {
    final colorScheme = Theme.of(context).colorScheme;

    return ExpansionTile(
      key: const Key('detailTechnicalInfo'),
      title: const Text('Información técnica'),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(AppTheme.paddingMD),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTechItem('ID del escaneo', scan.id),
              _buildTechItem('Ruta de imagen', scan.imagePath),
              _buildTechItem(
                'Confianza (decimal)',
                scan.confidence.toStringAsFixed(4),
              ),
              _buildTechItem(
                  'Total de predicciones', '${scan.top3Predictions.length}'),
            ],
          ),
        ),
      ],
    );
  }

  /// Fila seleccionable para copiar identificadores, rutas y valores técnicos.
  Widget _buildTechItem(String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Container(
            key: ValueKey('detailTechnicalValue-$label'),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
            child: SelectableText(
              value,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  /// Actualiza el favorito persistido y luego sincroniza la copia visible.
  Future<void> _toggleFavorite(ScanHistory scan) async {
    final updated = await ref
        .read(historyNotifierProvider.notifier)
        .toggleFavorite(scan.id);

    if (!mounted) return;

    if (!updated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo actualizar el favorito.'),
        ),
      );
      return;
    }

    setState(() {
      _isFavorite = !_isFavorite;
      _scan = scan.copyWith(isFavorite: _isFavorite);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isFavorite ? 'Agregado a favoritos' : 'Removido de favoritos',
        ),
      ),
    );
  }

  /// Solicita confirmación antes de borrar y vuelve al historial al terminar.
  Future<void> _deleteScan(ScanHistory scan) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar escaneo'),
        content:
            const Text('¿Estás seguro de que deseas eliminar este escaneo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar',
                style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      // Se conserva el messenger antes de retirar la ruta para poder mostrar la
      // confirmación en el Scaffold que queda visible.
      final messenger = ScaffoldMessenger.of(context);
      final deleted =
          await ref.read(historyNotifierProvider.notifier).deleteScan(scan.id);
      if (!mounted) return;

      if (!deleted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('No se pudo eliminar el escaneo.')),
        );
        return;
      }

      context.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Escaneo eliminado')),
      );
    }
  }

  /// Crea una copia con las notas actuales y la actualiza en SQLite.
  Future<void> _saveNotes(ScanHistory scan) async {
    final updated = scan.copyWith(userNotes: _notesController.text);
    await ref.read(databaseServiceProvider).updateScan(updated);

    if (mounted) {
      setState(() => _scan = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notas guardadas')),
      );
    }
  }

  /// Verifica de forma segura si la imagen sigue disponible en almacenamiento.
  bool _imageFileExists(String path) {
    try {
      return File(path).existsSync();
    } catch (e) {
      return false;
    }
  }

  /// Asigna un color semántico según la confianza normalizada del modelo.
  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return AppTheme.successColor;
    if (confidence >= 0.6) return AppTheme.warningColor;
    return AppTheme.errorColor;
  }
}
