import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lab_instrument_identifier/main.dart';
import 'package:lab_instrument_identifier/models/prediction.dart';
import 'package:lab_instrument_identifier/models/scan_history.dart';
import 'package:lab_instrument_identifier/providers/providers.dart';
import 'package:lab_instrument_identifier/screens/detail_screen.dart';
import 'package:lab_instrument_identifier/screens/history_screen.dart';
import 'package:lab_instrument_identifier/screens/settings_screen.dart';

void main() {
  testWidgets('muestra el splash mientras se inicializa el modelo',
      (tester) async {
    final initialization = Completer<void>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          initializationProvider.overrideWith(
            (ref) => initialization.future,
          ),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pump();

    expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).title, 'Labster');
    expect(find.byKey(const Key('splashLogo')), findsOneWidget);
    expect(find.byKey(const Key('splashProgress')), findsOneWidget);
    expect(find.text('Labster'), findsNothing);
    expect(find.text('Preparando reconocimiento local'), findsNothing);
  });

  testWidgets('permite reintentar cuando el modelo no carga', (tester) async {
    var attempts = 0;
    final retryInitialization = Completer<void>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          initializationProvider.overrideWith(
            (ref) {
              attempts++;
              if (attempts == 1) {
                return Future<void>.error(
                  StateError('modelo no disponible'),
                );
              }
              return retryInitialization.future;
            },
          ),
        ],
        child: const MyApp(),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(
      find.text('No se pudo cargar el modelo de reconocimiento.'),
      findsOneWidget,
    );
    expect(find.text('Reintentar'), findsOneWidget);

    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    await tester.pump();

    expect(attempts, 2);
    expect(find.byKey(const Key('splashProgress')), findsOneWidget);
    expect(
      find.text('No se pudo cargar el modelo de reconocimiento.'),
      findsNothing,
    );
  });

  testWidgets('el botón de nuevo escaneo regresa a la cámara existente',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/camera-test',
      routes: [
        GoRoute(
          path: '/camera-test',
          builder: (context, state) => Scaffold(
            body: const Center(child: Text('Cámara de prueba')),
            floatingActionButton: FloatingActionButton(
              onPressed: () => context.push('/history-test'),
              child: const Icon(Icons.history),
            ),
          ),
        ),
        GoRoute(
          path: '/history-test',
          builder: (context, state) => const HistoryScreen(loadOnStart: false),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.tap(find.byIcon(Icons.history));
    await tester.pumpAndSettle();
    expect(find.text('Historial'), findsOneWidget);

    await tester.tap(find.byTooltip('Nuevo escaneo'));
    await tester.pumpAndSettle();

    expect(find.text('Cámara de prueba'), findsOneWidget);
    expect(find.text('Historial'), findsNothing);
  });

  testWidgets(
      'ajustes adapta sus tarjetas al tema y muestra opciones de Labster',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: SettingsScreen()),
      ),
    );

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    final settingsContext = tester.element(find.byType(SettingsScreen));
    expect(
      scaffold.backgroundColor,
      Theme.of(settingsContext).colorScheme.surface,
    );
    expect(find.text('Apariencia'), findsOneWidget);
    expect(find.text('Reconocimiento'), findsOneWidget);
    expect(find.text('Cámara y permisos'), findsOneWidget);
    expect(find.text('Datos y privacidad'), findsOneWidget);
    expect(find.text('Información técnica'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Términos y licencias'),
      250,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Términos y licencias'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Acerca de Labster'),
      300,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Acerca de Labster'), findsOneWidget);
  });

  testWidgets('historial recarga el filtro activo después de marcar favorito',
      (tester) async {
    late _FakeHistoryNotifier notifier;
    final scan = _buildScan();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          historyNotifierProvider.overrideWith((ref) {
            notifier = _FakeHistoryNotifier(ref, scans: [scan]);
            return notifier;
          }),
        ],
        child: const MaterialApp(
          home: HistoryScreen(loadOnStart: false),
        ),
      ),
    );

    await tester.tap(find.text('Favoritos'));
    await tester.pumpAndSettle();
    expect(notifier.favoriteLoads, 1);

    await tester.tap(find.byTooltip('Agregar a favoritos'));
    await tester.pumpAndSettle();

    expect(notifier.toggledIds, [scan.id]);
    expect(notifier.favoriteLoads, 2);
  });

  testWidgets(
      'historial conserva todos los filtros cuando hoy y semana están vacíos',
      (tester) async {
    late _FakeHistoryNotifier notifier;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          historyNotifierProvider.overrideWith((ref) {
            notifier = _FakeHistoryNotifier(ref, scans: const []);
            return notifier;
          }),
        ],
        child: const MaterialApp(
          home: HistoryScreen(loadOnStart: false),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('historyFilterToday')));
    await tester.pumpAndSettle();

    expect(notifier.todayLoads, 1);
    expect(find.text('No hay escaneos de hoy'), findsOneWidget);
    expect(find.byKey(const Key('historyFilterAll')), findsOneWidget);
    expect(find.byKey(const Key('historyFilterFavorites')), findsOneWidget);
    expect(find.byKey(const Key('historyFilterToday')), findsOneWidget);
    expect(find.byKey(const Key('historyFilterWeek')), findsOneWidget);

    await tester.tap(find.byKey(const Key('historyFilterWeek')));
    await tester.pumpAndSettle();

    expect(notifier.weekLoads, 1);
    expect(find.text('No hay escaneos esta semana'), findsOneWidget);
    expect(find.byKey(const Key('historyFilterAll')), findsOneWidget);
    expect(find.byKey(const Key('historyFilterFavorites')), findsOneWidget);
  });

  testWidgets('detalle conserva el favorito cuando la actualización falla',
      (tester) async {
    late _FakeHistoryNotifier notifier;
    final scan = _buildScan();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          historyNotifierProvider.overrideWith((ref) {
            notifier = _FakeHistoryNotifier(
              ref,
              scans: [scan],
              toggleResult: false,
            );
            return notifier;
          }),
        ],
        child: MaterialApp(
          home: DetailScreen(scanId: scan.id, scan: scan),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pumpAndSettle();

    expect(notifier.toggledIds, [scan.id]);
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsNothing);
    expect(
      find.text('No se pudo actualizar el favorito.'),
      findsOneWidget,
    );
  });
}

ScanHistory _buildScan() {
  return ScanHistory(
    id: 'scan-prueba',
    timestamp: DateTime(2026, 8, 7, 12),
    imagePath: 'imagen-inexistente.jpg',
    predictedInstrument: 'Microscopio',
    confidence: 0.9,
    top3Predictions: const [
      Prediction(
        name: 'Microscopio',
        confidence: 0.9,
        category: 'Óptica',
      ),
    ],
  );
}

class _FakeHistoryNotifier extends HistoryNotifier {
  _FakeHistoryNotifier(
    super.ref, {
    required List<ScanHistory> scans,
    this.toggleResult = true,
  }) : _scans = scans {
    state = HistoryState.success(_scans);
  }

  final List<ScanHistory> _scans;
  final bool toggleResult;
  final List<String> toggledIds = [];
  int favoriteLoads = 0;
  int todayLoads = 0;
  int weekLoads = 0;

  @override
  Future<void> loadHistory() async {
    state = HistoryState.success(_scans);
  }

  @override
  Future<void> loadFavorites() async {
    favoriteLoads++;
    state = HistoryState.success(_scans);
  }

  @override
  Future<void> loadTodayScans() async {
    todayLoads++;
    state = const HistoryState.success([]);
  }

  @override
  Future<void> loadWeekScans() async {
    weekLoads++;
    state = const HistoryState.success([]);
  }

  @override
  Future<bool> toggleFavorite(String id) async {
    toggledIds.add(id);
    return toggleResult;
  }
}
