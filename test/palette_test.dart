import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lab_instrument_identifier/config/app_palette.dart';
import 'package:lab_instrument_identifier/config/theme.dart';
import 'package:lab_instrument_identifier/main.dart';
import 'package:lab_instrument_identifier/providers/palette_provider.dart';
import 'package:lab_instrument_identifier/providers/providers.dart';
import 'package:lab_instrument_identifier/providers/theme_provider.dart';
import 'package:lab_instrument_identifier/services/palette_preferences_service.dart';

void main() {
  test('recupera la paleta desde un archivo en una nueva sesión', () async {
    final directory = await Directory.systemTemp.createTemp('cuac-palette-');
    addTearDown(() => directory.delete(recursive: true));
    final store = PalettePreferencesService(directory: () async => directory);
    expect(await store.loadPalette(), AppPalette.original);
    await store.savePalette(AppPalette.ocean);
    final reopened =
        PalettePreferencesService(directory: () async => directory);
    expect(await reopened.loadPalette(), AppPalette.ocean);
    await File('${directory.path}/cuac_palette.txt')
        .writeAsString('desconocida');
    expect(await reopened.loadPalette(), AppPalette.original);
  });

  test('revierte la paleta cuando falla el guardado', () async {
    final controller =
        PaletteController(_MemoryPaletteStore(fail: true), AppPalette.winter);
    addTearDown(controller.dispose);
    await expectLater(controller.select(AppPalette.ocean), throwsStateError);
    expect(controller.state, AppPalette.winter);
  });

  for (final palette in [AppPalette.winter, AppPalette.ocean]) {
    for (final brightness in Brightness.values) {
      test('${palette.id} $brightness mantiene contraste de texto y botones',
          () {
        final scheme = AppTheme.forPalette(palette, brightness).colorScheme;
        expect(
            scheme.surface,
            brightness == Brightness.dark
                ? palette.colors[0]
                : palette.colors[4]);
        for (final pair in [
          [scheme.surface, scheme.onSurface],
          [scheme.primary, scheme.onPrimary],
          [scheme.primaryContainer, scheme.onPrimaryContainer],
        ]) {
          final a = pair[0].computeLuminance();
          final b = pair[1].computeLuminance();
          final contrast = ((a > b ? a : b) + 0.05) / ((a < b ? a : b) + 0.05);
          expect(contrast, greaterThanOrEqualTo(4.5));
        }
      });
    }
  }

  testWidgets('Apariencia aplica la paleta sin cambiar modo ni navegación',
      (tester) async {
    final store = _MemoryPaletteStore();
    final pending = Completer<void>();
    final container = ProviderContainer(overrides: [
      paletteStoreProvider.overrideWithValue(store),
      initialThemeModeProvider.overrideWithValue(ThemeMode.dark),
      initializationProvider.overrideWith((ref) => pending.future),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const MyApp()));
    final router = tester
        .widget<MaterialApp>(find.byType(MaterialApp))
        .routerConfig! as GoRouter;
    router.go('/settings');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apariencia'));
    await tester.pumpAndSettle();
    final option = find.byKey(const ValueKey('palette-ocean'));
    await tester.ensureVisible(option);
    await tester.pumpAndSettle();
    await tester.tap(option);
    await tester.pumpAndSettle();
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.darkTheme!.colorScheme.surface, const Color(0xFF01162B));
    expect(app.themeMode, ThemeMode.dark);
    expect(identical(app.routerConfig, router), isTrue);
    expect(store.value, AppPalette.ocean);
    expect(tester.takeException(), isNull);
  });
}

class _MemoryPaletteStore implements PalettePreferencesStore {
  _MemoryPaletteStore({this.fail = false});
  final bool fail;
  AppPalette value = AppPalette.original;
  @override
  Future<AppPalette> loadPalette() async => value;
  @override
  Future<void> savePalette(AppPalette palette) async {
    if (fail) throw StateError('Sin espacio');
    value = palette;
  }
}
