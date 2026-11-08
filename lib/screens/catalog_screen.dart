import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/educational_instrument.dart';
import '../providers/catalog_provider.dart';

/// Catálogo común para consultar fichas y ampliar el resultado de un escaneo.
class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({super.key});
  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  String _query = '';

  /// Permite buscar «centrifuga» o «ph» sin exigir tildes ni mayúsculas.
  String _normalize(String text) {
    var value = text.toLowerCase();
    const accents = {
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'ü': 'u'
    };
    accents.forEach((from, to) => value = value.replaceAll(from, to));
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Catálogo educativo')),
      body: catalog.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            CatalogError(onRetry: () => ref.invalidate(catalogProvider)),
        data: (items) => Column(children: [
          Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                const Text(
                    'Fichas sin internet de los instrumentos originales y los nuevos. La cámara reconoce actualmente las diez clases originales; el entrenamiento de las nuevas está pendiente.'),
                const SizedBox(height: 12),
                TextField(
                    decoration: const InputDecoration(
                        labelText: 'Buscar instrumento',
                        prefixIcon: Icon(Icons.search)),
                    onChanged: (value) =>
                        setState(() => _query = _normalize(value.trim()))),
              ])),
          Expanded(child: _buildList(items)),
        ]),
      ),
    );
  }

  Widget _buildList(List<EducationalInstrument> items) {
    final filtered = items
        .where((item) =>
            _normalize('${item.name} ${item.englishName} ${item.category}')
                .contains(_query))
        .toList();
    if (filtered.isEmpty) {
      return Center(
          child: Text(items.isEmpty
              ? 'El catálogo está vacío.'
              : 'No se encontraron instrumentos.'));
    }
    return ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final item = filtered[index];
          return Card(
              child: ListTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: Text(item.name),
            subtitle: Text(item.category),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                context.push('/catalog/${Uri.encodeComponent(item.id)}'),
          ));
        });
  }
}

/// Error recuperable sin mostrar detalles internos de SQLite al estudiante.
class CatalogError extends StatelessWidget {
  final VoidCallback onRetry;
  const CatalogError({super.key, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
      child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('No se pudo cargar el catálogo local.'),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Reintentar'))
          ])));
}
