import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/educational_instrument.dart';
import '../services/catalog_service.dart';
import 'providers.dart';

/// El catálogo se carga de forma independiente del modelo y del permiso de cámara.
final catalogProvider = FutureProvider<List<EducationalInstrument>>((ref) {
  return CatalogService(ref.watch(databaseServiceProvider)).load();
});
