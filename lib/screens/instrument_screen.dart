import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/educational_instrument.dart';
import '../providers/catalog_provider.dart';
import 'catalog_screen.dart';
import '../widgets/instrument_video.dart';
import '../widgets/instrument_photo.dart';

/// Recupera la ficha por ID estable: funciona también sin datos extra de navegación.
class InstrumentScreen extends ConsumerWidget {
  final String instrumentId;
  const InstrumentScreen({super.key, required this.instrumentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: const Text('Ficha técnica del instrumento')),
        body: ref.watch(catalogProvider).when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) =>
                  CatalogError(onRetry: () => ref.invalidate(catalogProvider)),
              data: (items) {
                final matches = items.where((item) => item.id == instrumentId);
                if (matches.isEmpty) {
                  return const Center(
                      child: Text('Instrumento no encontrado.'));
                }
                return _content(context, matches.single);
              },
            ),
      );

  Widget _content(BuildContext context, EducationalInstrument item) {
    final theme = Theme.of(context);
    Widget section(String title, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          SelectableText(text),
        ]));
    String bullets(List<String> values) =>
        values.map((text) => '• $text').join('\n\n');
    return ListView(padding: const EdgeInsets.all(20), children: [
      Text(item.name, style: theme.textTheme.headlineSmall),
      Text('${item.englishName} · ${item.category}'),
      const SizedBox(height: 16),
      InstrumentPhoto(instrument: item),
      const SizedBox(height: 16),
      section('¿Qué es?', item.description),
      section('¿Cómo funciona?', item.principle),
      section('Partes principales', bullets(item.parts)),
      section(
          '¿Cómo se utiliza?',
          item.steps
              .asMap()
              .entries
              .map((entry) => '${entry.key + 1}. ${entry.value}')
              .join('\n\n')),
      section('Aplicaciones', bullets(item.applications)),
      section('Seguridad y precauciones', bullets(item.safety)),
      InstrumentVideo(instrument: item),
      section('Fuente de consulta',
          '${item.sourceName}\n${item.sourceUrl}\n\nGuía introductoria: sigue el manual del equipo y el protocolo de tu laboratorio. La ficha describe una familia de instrumentos; no determina capacidad, precisión ni modelo comercial a partir de una fotografía.'),
    ]);
  }
}
