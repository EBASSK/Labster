import 'package:flutter/material.dart';
import '../models/educational_instrument.dart';

/// Muestra un recurso local y permite consultar sus créditos sin conexión.
class InstrumentPhoto extends StatelessWidget {
  final EducationalInstrument instrument;
  const InstrumentPhoto({super.key, required this.instrument});

  @override
  Widget build(BuildContext context) {
    final photo = instrument.photo;
    const missing = Padding(
        padding: EdgeInsets.all(16),
        child: Column(children: [
          Icon(Icons.image_outlined),
          Text('Fotografía no disponible'),
        ]));
    return Card(
        clipBehavior: Clip.antiAlias,
        child: photo == null
            ? missing
            : Column(children: [
                // Contain conserva el equipo completo; un fallo de lectura no bloquea la ficha.
                Image.asset(photo.asset,
                    height: 220,
                    width: double.infinity,
                    fit: BoxFit.contain,
                    semanticLabel: 'Fotografía de ${instrument.name}',
                    errorBuilder: (context, error, stack) => missing),
                ExpansionTile(
                    title: const Text('Créditos de la fotografía'),
                    children: [
                      Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: SelectableText(
                              '${photo.title}\n${photo.author}\n${photo.license}\n${photo.sourceUrl}\n${photo.licenseUrl}\n\nImagen ilustrativa de un modelo de equipo. Miniatura proporcionada por Wikimedia Commons; sin ediciones adicionales.')),
                    ]),
              ]));
  }
}
