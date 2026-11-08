import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lab_instrument_identifier/config/app_palette.dart';
import 'package:lab_instrument_identifier/config/theme.dart';
import 'package:lab_instrument_identifier/main.dart';
import 'package:lab_instrument_identifier/providers/catalog_provider.dart';
import 'package:lab_instrument_identifier/providers/providers.dart';
import 'package:lab_instrument_identifier/screens/catalog_screen.dart';
import 'package:lab_instrument_identifier/screens/instrument_screen.dart';
import 'package:lab_instrument_identifier/services/catalog_service.dart';

void main() {
  final source = File('assets/catalog/instruments.json').readAsStringSync();
  final items = CatalogService.decode(source);

  test('veinte fichas únicas incluyen todas las etiquetas actuales', () {
    expect(items.length, 20);
    final labels = File('assets/models/labels.txt').readAsLinesSync();
    expect(items.map((item) => item.id).toSet().length, 20);
    expect(items.map((item) => item.id), containsAll(labels));
    for (final item in items) {
      expect(item.steps.length, greaterThanOrEqualTo(3));
      expect(item.safety, isNotEmpty);
      expect(CatalogService.decode(jsonEncode([item.toJson()])).single.toJson(),
          item.toJson());
    }
  });

  test('rechaza duplicados y fichas sin principio de funcionamiento', () {
    expect(
        () => CatalogService.decode(
            jsonEncode([items.first.toJson(), items.first.toJson()])),
        throwsFormatException);
    final incomplete = items.first.toJson()..remove('principle');
    expect(() => CatalogService.decode(jsonEncode([incomplete])),
        throwsFormatException);
  });

  testWidgets('la ruta real busca sin tildes, abre ficha y vuelve al catálogo',
      (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      initializationProvider.overrideWith((ref) => Completer<void>().future),
      catalogProvider.overrideWith((ref) async => items),
    ], child: const MyApp()));
    await tester.pump();
    final context = tester.element(find.byType(Scaffold).first);
    GoRouter.of(context).go('/catalog');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'centrifuga');
    await tester.pumpAndSettle();
    expect(find.text('Centrífuga de laboratorio'), findsOneWidget);
    expect(find.text('Autoclave'), findsNothing);
    await tester.tap(find.text('Centrífuga de laboratorio'));
    await tester.pumpAndSettle();
    expect(find.byType(InstrumentScreen), findsOneWidget);
    expect(find.text('¿Cómo funciona?'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(CatalogScreen), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'inexistente');
    await tester.pumpAndSettle();
    expect(find.text('No se encontraron instrumentos.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('error de carga permite reintentar', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(ProviderScope(overrides: [
      catalogProvider.overrideWith((ref) async {
        if (++attempts == 1) throw StateError('SQLite no disponible');
        return items;
      }),
    ], child: const MaterialApp(home: CatalogScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(attempts, 2);
  });

  for (final palette in AppPalette.values) {
    for (final brightness in Brightness.values) {
      testWidgets(
          'ficha ${palette.id} $brightness en pantalla pequeña y texto grande',
          (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(ProviderScope(
            overrides: [
              catalogProvider.overrideWith((ref) async => items),
            ],
            child: MaterialApp(
                theme: AppTheme.forPalette(palette, brightness),
                builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: const TextScaler.linear(1.5)),
                    child: child!),
                home: const InstrumentScreen(instrumentId: 'autoclave'))));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('Fuente de consulta'), 400,
            scrollable: find.byType(Scrollable).first);
        expect(find.text('Fuente de consulta'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('ID desconocido muestra mensaje sin bloquear la pantalla',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
        overrides: [
          catalogProvider.overrideWith((ref) async => items),
        ],
        child: const MaterialApp(
            home: InstrumentScreen(instrumentId: 'missing'))));
    await tester.pumpAndSettle();
    expect(find.text('Instrumento no encontrado.'), findsOneWidget);
  });
}
