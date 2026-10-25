import 'package:flutter/material.dart';

/// Paletas independientes del modo claro/oscuro. Los identificadores se guardan
/// como texto para que añadir opciones no cambie las preferencias existentes.
enum AppPalette {
  original('original', 'Labster original', [
    Color(0xFF111827),
    Color(0xFF2563EB),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFF3F4F6),
  ]),
  winter('winter', 'Bruma invernal', [
    Color(0xFF313C45),
    Color(0xFF4F6271),
    Color(0xFF778CA4),
    Color(0xFFB3BFCB),
    Color(0xFFD5DBE2),
  ]),
  ocean('ocean', 'Océano profundo', [
    Color(0xFF01162B),
    Color(0xFF00385A),
    Color(0xFF6A90B4),
    Color(0xFF94A2BF),
    Color(0xFFD2DBEB),
  ]);

  const AppPalette(this.id, this.label, this.colors);
  final String id;
  final String label;

  /// Cinco tonos de las referencias, ordenados del más oscuro al más claro.
  final List<Color> colors;

  /// Una preferencia desconocida conserva la apariencia original de Labster.
  static AppPalette fromStorage(Object? value) => values.firstWhere(
        (palette) => palette.id == value,
        orElse: () => original,
      );
}
