import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/instrument_catalog_link.dart';

/// Abre la ficha de la sugerencia del modelo sin convertirla en una confirmación.
/// Se reutiliza en el resultado inmediato y en los escaneos del historial.
class ScanInstrumentLink extends StatelessWidget {
  final String label;
  const ScanInstrumentLink({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final id = InstrumentCatalogLink.idForLabel(label);
    if (id == null) {
      return const Text('Ficha no disponible para esta identificación.');
    }
    return OutlinedButton.icon(
      icon: const Icon(Icons.menu_book_outlined),
      label: Text('Ficha técnica: $label'),
      onPressed: () => context.push('/catalog/${Uri.encodeComponent(id)}'),
    );
  }
}
