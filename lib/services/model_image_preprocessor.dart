import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../config/app_config.dart';

/// Convierte una imagen codificada al tensor que exige el modelo desplegado.
///
/// El contrato de salida tiene forma `[1][alto][ancho][3]`: un lote con una
/// imagen, canales RGB y valores normalizados en el intervalo `[0, 1]`.
class ModelImagePreprocessor {
  const ModelImagePreprocessor();

  /// Decodifica [imageBytes], corrige su orientación y crea el tensor de entrada.
  ///
  /// La imagen se redimensiona directamente al tamaño configurado, sin recorte
  /// ni relleno, con el mismo muestreo de `ml/preprocessing.py`. Lanza
  /// [FormatException] cuando los bytes no representan una imagen decodificable.
  List<List<List<List<double>>>> preprocess(Uint8List imageBytes) {
    img.Image? decodedImage;
    try {
      decodedImage = img.decodeImage(imageBytes);
    } catch (_) {
      throw const FormatException('No se pudo decodificar la imagen');
    }
    if (decodedImage == null) {
      throw const FormatException('No se pudo decodificar la imagen');
    }

    // Materializa la orientación EXIF para que la cámara y el modelo observen
    // la imagen en la misma posición, independientemente del dispositivo.
    // RGB8 evita dividir valores de 16 bits por 255 o confundir índices de paleta
    // con colores. El canal alfa no forma parte del contrato del clasificador.
    final orientedImage = img.bakeOrientation(decodedImage).convert(
          format: img.Format.uint8,
          numChannels: 3,
        );
    // Muestreo bilineal de centros de píxel, idéntico a ml/preprocessing.py.
    // Conserva las fracciones y replica el borde; no recorta ni añade relleno.
    const size = AppConfig.modelInputSize;
    // El primer nivel corresponde al lote de tamaño uno; luego se recorren
    // filas, columnas y finalmente los tres canales RGB de cada píxel.
    return [
      List<List<List<double>>>.generate(
        AppConfig.modelInputSize,
        (y) => List<List<double>>.generate(
          AppConfig.modelInputSize,
          (x) {
            final sourceX = ((x + 0.5) * orientedImage.width / size - 0.5)
                .clamp(0.0, (orientedImage.width - 1).toDouble());
            final sourceY = ((y + 0.5) * orientedImage.height / size - 0.5)
                .clamp(0.0, (orientedImage.height - 1).toDouble());
            final x0 = sourceX.floor();
            final y0 = sourceY.floor();
            final x1 = (x0 + 1).clamp(0, orientedImage.width - 1);
            final y1 = (y0 + 1).clamp(0, orientedImage.height - 1);
            final wx = sourceX - x0;
            final wy = sourceY - y0;
            final a = orientedImage.getPixel(x0, y0);
            final b = orientedImage.getPixel(x1, y0);
            final c = orientedImage.getPixel(x0, y1);
            final d = orientedImage.getPixel(x1, y1);
            double interpolate(num av, num bv, num cv, num dv) =>
                ((av * (1 - wx) + bv * wx) * (1 - wy) +
                    (cv * (1 - wx) + dv * wx) * wy) /
                255.0;
            return [
              interpolate(a.r, b.r, c.r, d.r),
              interpolate(a.g, b.g, c.g, d.g),
              interpolate(a.b, b.b, c.b, d.b),
            ];
          },
          growable: false,
        ),
        growable: false,
      ),
    ];
  }
}
