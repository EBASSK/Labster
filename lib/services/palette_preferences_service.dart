import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../config/app_palette.dart';

/// Contrato sustituible en pruebas para conservar la paleta entre sesiones.
abstract interface class PalettePreferencesStore {
  Future<AppPalette> loadPalette();
  Future<void> savePalette(AppPalette palette);
}

/// Guarda solo la paleta en soporte privado. Un archivo independiente evita
/// sobrescribir el modo claro/oscuro almacenado por ThemePreferencesService.
class PalettePreferencesService implements PalettePreferencesStore {
  PalettePreferencesService({Future<Directory> Function()? directory})
      : _directory = directory ?? getApplicationSupportDirectory;
  final Future<Directory> Function() _directory;

  // Conserva el nombre usado antes de Labster para recuperar la paleta existente.
  Future<File> _file() async =>
      File(path.join((await _directory()).path, 'cuac_palette.txt'));

  /// Un archivo ausente o dañado no debe impedir el arranque de la aplicación.
  @override
  Future<AppPalette> loadPalette() async {
    try {
      return AppPalette.fromStorage(
          (await (await _file()).readAsString()).trim());
    } on Object {
      return AppPalette.original;
    }
  }

  /// Propaga errores de escritura: la interfaz debe avisar y revertir el cambio.
  @override
  Future<void> savePalette(AppPalette palette) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(palette.id, flush: true);
  }
}
