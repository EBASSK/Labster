import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lab_instrument_identifier/models/educational_instrument.dart';
import 'package:lab_instrument_identifier/models/educational_photo.dart';
import 'package:lab_instrument_identifier/services/catalog_service.dart';
import 'package:lab_instrument_identifier/widgets/instrument_photo.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final items = CatalogService.decode(
      File('assets/catalog/instruments.json').readAsStringSync());
  test('las diez fotografías se decodifican y conservan créditos al serializar',
      () async {
    for (final item in items.where((item) => item.photo != null)) {
      final photo = item.photo!;
      final codec =
          await ui.instantiateImageCodec(await File(photo.asset).readAsBytes());
      final frame = await codec.getNextFrame();
      expect(frame.image.width, greaterThan(100));
      frame.image.dispose();
      codec.dispose();
      expect(EducationalInstrument.fromJson(item.toJson()).photo!.toJson(),
          photo.toJson());
    }
  });
  test('fichas antiguas y rutas inválidas no cargan archivos externos', () {
    expect(
        EducationalInstrument.fromJson(items.first.toJson()..remove('photo'))
            .photo,
        isNull);
    final data = items.first.photo!.toJson()..['asset'] = '../../private.jpg';
    expect(EducationalPhoto.tryParse(data), isNull);
  });
  testWidgets('imagen ausente conserva ficha y créditos disponibles',
      (tester) async {
    final data = items.first.toJson();
    data['photo'] = items.first.photo!.toJson()
      ..['asset'] = 'assets/catalog/photos/missing.jpg';
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: InstrumentPhoto(
                    instrument: EducationalInstrument.fromJson(data))))));
    await tester.pumpAndSettle();
    expect(find.text('Fotografía no disponible'), findsOneWidget);
    await tester.tap(find.text('Créditos de la fotografía'));
    await tester.pumpAndSettle();
    expect(find.textContaining(items.first.photo!.author), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
