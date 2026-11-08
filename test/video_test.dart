import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lab_instrument_identifier/models/educational_instrument.dart';
import 'package:lab_instrument_identifier/models/educational_video.dart';
import 'package:lab_instrument_identifier/services/catalog_service.dart';
import 'package:lab_instrument_identifier/services/video_link_service.dart';
import 'package:lab_instrument_identifier/widgets/instrument_video.dart';

void main() {
  final items = CatalogService.decode(
      File('assets/catalog/instruments.json').readAsStringSync());
  final withVideo = items.firstWhere((item) => item.video != null);
  final pending =
      EducationalInstrument.fromJson(withVideo.toJson()..remove('video'));

  test('metadatos de diez videos y compatibilidad con fichas sin video', () {
    expect(items.where((item) => item.video != null).length, 10);
    for (final item in items.where((item) => item.video != null)) {
      expect(VideoLinkService.isAllowed(item.video!.uri), isTrue);
      expect(item.video!.channel, isNotEmpty);
      expect(EducationalInstrument.fromJson(item.toJson()).video!.uri,
          item.video!.uri);
    }
  });
  test('una ficha antigua o un video inválido no impiden la lectura', () {
    final data = withVideo.toJson()..remove('video');
    expect(EducationalInstrument.fromJson(data).video, isNull);
    data['video'] = {'id': 'https://otro-sitio.test'};
    expect(EducationalInstrument.fromJson(data).name, withVideo.name);
    expect(EducationalInstrument.fromJson(data).video, isNull);
    expect(EducationalVideo.tryParse('valor dañado'), isNull);
  });
  test('rechaza esquemas y dominios que no corresponden a YouTube', () async {
    for (final url in [
      'javascript:alert(1)',
      'https://youtube.com.ejemplo.test/watch?v=pxC6F7bK8CU',
      'http://www.youtube.com/watch?v=pxC6F7bK8CU',
      'https://www.youtube.com/watch?v=invalid'
    ]) {
      expect(await VideoLinkService.open(Uri.parse(url)), isFalse);
    }
  });
  testWidgets('fallo de apertura conserva ficha y permite búsqueda alternativa',
      (tester) async {
    final opened = <Uri>[];
    await tester.pumpWidget(ProviderScope(
        overrides: [
          videoLinkOpenerProvider.overrideWithValue((uri) async {
            opened.add(uri);
            return false;
          }),
        ],
        child: MaterialApp(
            home: Scaffold(
                body: SingleChildScrollView(
                    child: InstrumentVideo(instrument: withVideo))))));
    await tester.tap(find.text('Ver en YouTube'));
    await tester.pumpAndSettle();
    expect(opened.single, withVideo.video!.uri);
    expect(find.textContaining('No se pudo abrir YouTube'), findsOneWidget);
    await tester.ensureVisible(find.text('Buscar en YouTube'));
    await tester.tap(find.text('Buscar en YouTube'));
    await tester.pumpAndSettle();
    expect(opened.last.path, '/results');
    expect(
        opened.last.queryParameters['search_query'], contains(withVideo.name));
  });
  testWidgets('evita aperturas repetidas durante carga y termina sin error',
      (tester) async {
    final result = Completer<bool>();
    var calls = 0;
    await tester.pumpWidget(ProviderScope(
        overrides: [
          videoLinkOpenerProvider.overrideWithValue((uri) {
            calls++;
            return result.future;
          }),
        ],
        child: MaterialApp(
            home: Scaffold(body: InstrumentVideo(instrument: withVideo)))));
    await tester.tap(find.text('Ver en YouTube'));
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await tester.tap(find.text('Ver en YouTube'));
    expect(calls, 1);
    result.complete(true);
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.textContaining('No se pudo abrir YouTube'), findsNothing);
  });
  testWidgets('recurso pendiente ofrece búsqueda sin simular video verificado',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
            home: Scaffold(body: InstrumentVideo(instrument: pending)))));
    expect(find.text('Video pendiente de verificación.'), findsOneWidget);
    expect(find.text('Ver en YouTube'), findsNothing);
    expect(find.text('Buscar en YouTube'), findsOneWidget);
  });
}
