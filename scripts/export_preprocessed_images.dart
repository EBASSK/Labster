import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:lab_instrument_identifier/services/model_image_preprocessor.dart';

/// Exporta los tensores reales de Dart para compararlos con Python/TFLite.
/// AVIF se excluye porque no lo decodifica el paquete image; la cámara usa JPEG.
void main() {
  final manifest =
      jsonDecode(File('ml/artifacts/split_manifest.json').readAsStringSync())
          as List;
  final directory = Directory('build/dart_tensors')
    ..createSync(recursive: true);
  final records = <Map<String, dynamic>>[];
  for (var index = 0; index < manifest.length; index++) {
    final item = manifest[index] as Map<String, dynamic>;
    if (item['split'] != 'test' || (item['path'] as String).endsWith('.avif')) {
      continue;
    }
    final tensor = const ModelImagePreprocessor()
        .preprocess(File('ml/${item['path']}').readAsBytesSync());
    final values = Float32List.fromList(
        tensor.first.expand((row) => row.expand((pixel) => pixel)).toList());
    final filename = '$index.f32';
    File('${directory.path}/$filename')
        .writeAsBytesSync(values.buffer.asUint8List());
    records.add({...item, 'tensor_file': filename});
  }
  File('${directory.path}/manifest.json')
      .writeAsStringSync(jsonEncode(records));
  stdout.writeln('Tensores exportados: ${records.length}');
}
