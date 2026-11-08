import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/educational_instrument.dart';
import 'database_service.dart';

/// Instala fichas empaquetadas y las recupera desde la base existente, sin red.
class CatalogService {
  final DatabaseService database;
  CatalogService(this.database);

  /// Valida el lote completo antes de escribir: evita cargas parciales o IDs
  /// repetidos que oculten un instrumento durante una actualización.
  static List<EducationalInstrument> decode(String source) {
    final rows = jsonDecode(source) as List<dynamic>;
    final items = rows
        .map((row) => EducationalInstrument.fromJson(
            Map<String, dynamic>.from(row as Map)))
        .toList();
    if (items.map((item) => item.id).toSet().length != items.length ||
        items.map((item) => item.name.toLowerCase()).toSet().length !=
            items.length) {
      throw const FormatException('Instrumentos duplicados');
    }
    return List.unmodifiable(items);
  }

  Future<List<EducationalInstrument>> load() async {
    final bundled =
        decode(await rootBundle.loadString('assets/catalog/instruments.json'));
    await database.installCatalog(bundled);
    return database.getCatalog();
  }
}
