import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Contrato mínimo para leer y guardar la apariencia elegida por el usuario.
///
/// La abstracción permite sustituir el almacenamiento real por una memoria
/// temporal durante las pruebas, sin depender del sistema de archivos.
abstract interface class ThemePreferencesStore {
  /// Recupera el modo guardado o [ThemeMode.system] si todavía no existe.
  Future<ThemeMode> loadThemeMode();

  /// Persiste el modo que debe aplicarse en los próximos inicios de la app.
  Future<void> saveThemeMode(ThemeMode mode);
}

/// Guarda la preferencia de tema en un archivo privado de la aplicación.
///
/// Se reutiliza `path_provider`, que ya forma parte del proyecto, para evitar
/// añadir una dependencia solo por un valor pequeño de configuración. El
/// archivo no contiene información sensible ni sale del dispositivo.
class ThemePreferencesService implements ThemePreferencesStore {
  // El nombre histórico permite conservar el tema al actualizar a Labster.
  static const String _fileName = 'cuac_preferences.json';
  static const String _themeKey = 'themeMode';

  ThemeMode? _cachedThemeMode;

  /// Resuelve el archivo dentro del directorio de soporte privado de la app.
  Future<File> _preferencesFile() async {
    final directory = await getApplicationSupportDirectory();
    return File(path.join(directory.path, _fileName));
  }

  @override
  Future<ThemeMode> loadThemeMode() async {
    final cached = _cachedThemeMode;
    if (cached != null) return cached;

    try {
      final file = await _preferencesFile();
      if (!await file.exists()) {
        return _cache(ThemeMode.system);
      }

      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        return _cache(ThemeMode.system);
      }

      return _cache(themeModeFromStorage(decoded[_themeKey] as String?));
    } on Object {
      // Un archivo ausente, incompleto o dañado no debe impedir el arranque.
      // En cualquier fallo se conserva el comportamiento nativo del dispositivo.
      return _cache(ThemeMode.system);
    }
  }

  @override
  Future<void> saveThemeMode(ThemeMode mode) async {
    final file = await _preferencesFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode({_themeKey: themeModeToStorage(mode)}),
      flush: true,
    );
    _cachedThemeMode = mode;
  }

  /// Conserva en memoria el último valor leído para evitar accesos repetidos.
  ThemeMode _cache(ThemeMode mode) {
    _cachedThemeMode = mode;
    return mode;
  }
}

/// Convierte el enum de Flutter a un valor corto y estable para persistencia.
String themeModeToStorage(ThemeMode mode) {
  return switch (mode) {
    ThemeMode.system => 'system',
    ThemeMode.light => 'light',
    ThemeMode.dark => 'dark',
  };
}

/// Reconstruye la preferencia y usa el sistema ante valores antiguos o dañados.
ThemeMode themeModeFromStorage(String? value) {
  return switch (value) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}
