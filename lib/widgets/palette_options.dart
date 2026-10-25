import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_palette.dart';
import '../providers/palette_provider.dart';

/// Selector con los cinco colores originales de cada referencia. Mantiene la
/// hoja abierta para ver el resultado y combinar paleta y modo de luminosidad.
class PaletteOptions extends ConsumerStatefulWidget {
  const PaletteOptions({super.key});
  @override
  ConsumerState<PaletteOptions> createState() => _PaletteOptionsState();
}

class _PaletteOptionsState extends ConsumerState<PaletteOptions> {
  bool _saving = false;

  /// Bloquea pulsaciones repetidas mientras el almacenamiento confirma el cambio.
  Future<void> _select(AppPalette palette) async {
    setState(() => _saving = true);
    try {
      await ref.read(paletteProvider.notifier).select(palette);
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No se pudo guardar la paleta. Inténtalo de nuevo.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(paletteProvider);
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
          child: Text('Paleta de colores',
              style: Theme.of(context).textTheme.titleLarge),
        ),
        for (final palette in AppPalette.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: selected == palette
                  ? scheme.primaryContainer
                  : scheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                    color: selected == palette
                        ? scheme.primary
                        : scheme.outlineVariant),
              ),
              child: RadioListTile<AppPalette>(
                key: ValueKey('palette-${palette.id}'),
                value: palette,
                groupValue: selected,
                onChanged: _saving ? null : (value) => _select(value!),
                activeColor: scheme.primary,
                title: Text(palette.label),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  child: ExcludeSemantics(
                    // El nombre y el radio comunican la selección sin depender
                    // únicamente del color; las muestras son una ayuda visual.
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: Row(children: [
                        for (final color in palette.colors)
                          Expanded(
                              child: ColoredBox(
                                  color: color,
                                  child: const SizedBox(height: 18))),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (_saving) const LinearProgressIndicator(),
      ],
    );
  }
}
