import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_palette.dart';
import '../services/palette_preferences_service.dart';

final paletteStoreProvider = Provider<PalettePreferencesStore>(
  (ref) => PalettePreferencesService(),
);

/// Se reemplaza en main con el valor leído antes del primer frame.
final initialPaletteProvider =
    Provider<AppPalette>((ref) => AppPalette.original);

/// Publica el cambio inmediatamente y revierte si no puede persistirse.
/// Serializa solicitudes para que una escritura lenta no sobrescriba otra nueva.
class PaletteController extends StateNotifier<AppPalette> {
  PaletteController(this._store, AppPalette initial) : super(initial);
  final PalettePreferencesStore _store;
  Future<void> _pending = Future<void>.value();

  Future<void> select(AppPalette palette) {
    final operation = _pending.then((_) async {
      if (!mounted || state == palette) return;
      final previous = state;
      state = palette;
      try {
        await _store.savePalette(palette);
      } on Object {
        if (mounted) state = previous;
        rethrow;
      }
    });
    // La cola continúa después de un fallo, pero el llamador recibe el error.
    _pending = operation.catchError((Object _) {});
    return operation;
  }
}

final paletteProvider = StateNotifierProvider<PaletteController, AppPalette>(
  (ref) => PaletteController(
    ref.watch(paletteStoreProvider),
    ref.watch(initialPaletteProvider),
  ),
);
