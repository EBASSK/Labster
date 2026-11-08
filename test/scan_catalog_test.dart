import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lab_instrument_identifier/models/prediction.dart';
import 'package:lab_instrument_identifier/models/scan_history.dart';
import 'package:lab_instrument_identifier/providers/providers.dart';
import 'package:lab_instrument_identifier/providers/catalog_provider.dart';
import 'package:lab_instrument_identifier/services/catalog_service.dart';
import 'package:lab_instrument_identifier/services/instrument_catalog_link.dart';
import 'package:lab_instrument_identifier/screens/results_screen.dart';
import 'package:lab_instrument_identifier/screens/detail_screen.dart';
import 'package:lab_instrument_identifier/screens/instrument_screen.dart';

class _Result extends PredictionNotifier {
  _Result(super.ref) {
    state = const PredictionState.success([
      Prediction(name: 'Embudos', confidence: 0.91, category: 'Transferencia')
    ]);
  }
}

void main() {
  final items = CatalogService.decode(
      File('assets/catalog/instruments.json').readAsStringSync());
  test(
      'todas las etiquetas reales y los nombres de las veinte fichas resuelven',
      () {
    for (final label in File('assets/models/labels.txt').readAsLinesSync()) {
      expect(items.map((item) => item.id),
          contains(InstrumentCatalogLink.idForLabel(label)));
    }
    for (final item in items) {
      expect(InstrumentCatalogLink.idForLabel(item.id), item.id);
      expect(InstrumentCatalogLink.idForLabel(item.name), item.id);
    }
    expect(InstrumentCatalogLink.idForLabel(' Vasos de precipitado '),
        'vasos_precipitado');
    expect(InstrumentCatalogLink.idForLabel('instrumento desconocido'), isNull);
  });
  for (final history in [false, true]) {
    testWidgets(
        'abre ficha del embudo desde ${history ? 'historial' : 'escaneo'} y vuelve',
        (tester) async {
      final scan = ScanHistory(
          id: 'test',
          timestamp: DateTime(2026, 11, 8),
          imagePath: 'missing.jpg',
          predictedInstrument: 'Embudos',
          confidence: 0.91,
          top3Predictions: const []);
      final router = GoRouter(routes: [
        GoRoute(
            path: '/',
            builder: (_, __) => history
                ? DetailScreen(scanId: scan.id, scan: scan)
                : const ResultsScreen(imagePath: 'missing.jpg')),
        GoRoute(
            path: '/catalog/:id',
            builder: (_, state) =>
                InstrumentScreen(instrumentId: state.pathParameters['id']!)),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(ProviderScope(overrides: [
        predictionNotifierProvider.overrideWith((ref) => _Result(ref)),
        catalogProvider.overrideWith((ref) async => items),
      ], child: MaterialApp.router(routerConfig: router)));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Ficha técnica: Embudos'));
      await tester.tap(find.text('Ficha técnica: Embudos'));
      await tester.pumpAndSettle();
      expect(find.text('Embudo'), findsOneWidget);
      expect(find.byType(InstrumentScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
          find.byType(history ? DetailScreen : ResultsScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
