import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

import '../config/app_config.dart';

/// Reúne las operaciones de lectura, validación y almacenamiento de imágenes.
///
/// Se comparte como instancia única porque no mantiene datos por captura;
/// únicamente coordina archivos, configuración y transformaciones de imágenes.
/// Los métodos públicos convierten errores de E/S en valores de retorno seguros
/// (`null`, `false` o un resultado inválido) y dejan el detalle en el registro.
class ImageProcessingService {
  static final ImageProcessingService _instance =
      ImageProcessingService._internal();
  final Logger _logger = Logger();

  factory ImageProcessingService() {
    return _instance;
  }

  ImageProcessingService._internal();

  /// Lee una imagen desde [imagePath] y devuelve sus bytes.
  ///
  /// Si supera el tamaño configurado intenta reducirla. Solo devuelve `null`
  /// cuando un error impide localizar o leer el archivo. Si la decodificación o
  /// la compresión fallan, conserva y devuelve los bytes originales.
  Future<Uint8List?> loadAndProcessImage(String imagePath) async {
    try {
      _logger.i('Procesando imagen: $imagePath');

      final file = File(imagePath);
      if (!file.existsSync()) {
        throw Exception('Archivo no encontrado: $imagePath');
      }

      final bytes = await file.readAsBytes();

      // Las imágenes pequeñas se conservan sin recomprimir para evitar pérdida
      // innecesaria de detalle antes de enviarlas al modelo.
      if (bytes.length > AppConfig.maxImageSizeBytes) {
        _logger.w('Imagen muy grande, comprimiendo...');
        return await _compressImage(bytes);
      }

      return bytes;
    } catch (e) {
      _logger.e('Error procesando imagen: $e');
      return null;
    }
  }

  /// Corrige la orientación EXIF, limita el ancho a 1024 píxeles y codifica JPG.
  ///
  /// Si la imagen no puede decodificarse o la compresión falla, conserva los
  /// bytes originales para no descartar una captura que aún podría ser útil.
  Future<Uint8List?> _compressImage(Uint8List imageBytes) async {
    try {
      _logger.i('Comprimiendo imagen...');

      final image = img.decodeImage(imageBytes);
      if (image == null) {
        _logger.w('No se pudo decodificar la imagen');
        return imageBytes;
      }

      final orientedImage = img.bakeOrientation(image);
      final resized = img.copyResize(
        orientedImage,
        width: orientedImage.width > 1024 ? 1024 : orientedImage.width,
      );

      final compressed = img.encodeJpg(
        resized,
        quality: AppConfig.imageQuality,
      );

      _logger.i(
        'Imagen comprimida: ${imageBytes.length} -> ${compressed.length} bytes',
      );

      return Uint8List.fromList(compressed);
    } catch (e) {
      _logger.e('Error comprimiendo imagen: $e');
      return imageBytes;
    }
  }

  /// Valida existencia, formato y dimensiones mínimas de una imagen.
  ///
  /// También calcula un brillo promedio aproximado. Una exposición extrema se
  /// registra como advertencia, pero no invalida la captura; el llamador decide
  /// si muestra recomendaciones al usuario. Este método nunca propaga errores.
  Future<ImageValidationResult> validateImage(String imagePath) async {
    try {
      final file = File(imagePath);

      if (!file.existsSync()) {
        return ImageValidationResult(
          isValid: false,
          message: 'Archivo no encontrado',
        );
      }

      final size = file.lengthSync();
      if (size > AppConfig.maxImageSizeBytes) {
        _logger.i('La imagen se comprimirá antes de guardarla');
      }

      final bytes = await file.readAsBytes();
      final decodedImage = img.decodeImage(bytes);

      if (decodedImage == null) {
        return ImageValidationResult(
          isValid: false,
          message: 'Formato de imagen no válido',
        );
      }
      final image = img.bakeOrientation(decodedImage);

      // Política de calidad de la aplicación para evitar ampliar imágenes pequeñas.
      // No es una restricción del decodificador ni una garantía de precisión.
      if (image.width < 224 || image.height < 224) {
        return ImageValidationResult(
          isValid: false,
          message: 'Imagen muy pequeña (mín: 224x224)',
        );
      }

      // Se muestrea cada diez píxeles para estimar la exposición sin recorrer
      // todos los píxeles de fotografías grandes.
      double totalBrightness = 0;
      int pixelCount = 0;

      for (int y = 0; y < image.height; y += 10) {
        for (int x = 0; x < image.width; x += 10) {
          final pixel = image.getPixelSafe(x, y);
          final brightness = (pixel.r + pixel.g + pixel.b) / 3.0;
          totalBrightness += brightness;
          pixelCount++;
        }
      }

      final avgBrightness = totalBrightness / pixelCount;

      // Estos umbrales solo generan diagnóstico; la imagen sigue siendo válida.
      if (avgBrightness < 50) {
        _logger.w(
            'Imagen muy oscura (brillo promedio: ${avgBrightness.toStringAsFixed(1)})');
      } else if (avgBrightness > 200) {
        _logger.w(
            'Imagen muy clara (brillo promedio: ${avgBrightness.toStringAsFixed(1)})');
      }

      return ImageValidationResult(
        isValid: true,
        message: size > AppConfig.maxImageSizeBytes
            ? 'Imagen válida; se comprimirá antes del análisis'
            : 'Imagen válida',
        width: image.width,
        height: image.height,
        brightness: avgBrightness,
      );
    } catch (e) {
      return ImageValidationResult(
        isValid: false,
        message: 'Error validando imagen: $e',
      );
    }
  }

  /// Genera una miniatura JPG cuadrada del tamaño solicitado.
  /// Devuelve `null` cuando la ruta o el formato no son válidos.
  Future<Uint8List?> getThumbnail(
    String imagePath, {
    int size = 128,
  }) async {
    try {
      _logger.i('Generando miniatura...');

      final file = File(imagePath);
      if (!file.existsSync()) return null;

      final bytes = await file.readAsBytes();
      final decodedImage = img.decodeImage(bytes);

      if (decodedImage == null) return null;
      final image = img.bakeOrientation(decodedImage);

      final thumbnail = img.copyResize(
        image,
        width: size,
        height: size,
      );

      return Uint8List.fromList(img.encodeJpg(thumbnail));
    } catch (e) {
      _logger.e('Error generando miniatura: $e');
      return null;
    }
  }

  /// Lee metadatos básicos sin conservar la imagen decodificada en memoria.
  /// Devuelve `null` si el archivo no existe o no representa una imagen válida.
  Future<ImageInfo?> getImageInfo(String imagePath) async {
    try {
      final file = File(imagePath);
      if (!file.existsSync()) return null;

      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) return null;

      return ImageInfo(
        path: imagePath,
        size: bytes.length,
        width: image.width,
        height: image.height,
        format: _detectFormat(bytes),
        lastModified: file.lastModifiedSync(),
      );
    } catch (e) {
      _logger.e('Error obteniendo info de imagen: $e');
      return null;
    }
  }

  /// Detecta JPG, PNG o GIF por su firma binaria, no por la extensión.
  String _detectFormat(Uint8List bytes) {
    if (bytes.length < 4) return 'unknown';

    // JPG: FF D8 FF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return 'jpg';
    }

    // PNG: 89 50 4E 47
    if (bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'png';
    }

    // GIF: 47 49 46
    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) {
      return 'gif';
    }

    return 'unknown';
  }

  /// Guarda bytes dentro del directorio privado `scans` de la aplicación.
  ///
  /// Crea el directorio cuando sea necesario y devuelve la ruta definitiva;
  /// devuelve `null` si el sistema no permite completar la escritura.
  Future<String?> saveImage(Uint8List imageBytes, String filename) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final dir = Directory('${appDir.path}/scans');

      if (!dir.existsSync()) {
        await dir.create(recursive: true);
      }

      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(imageBytes);

      _logger.i('Imagen guardada: ${file.path}');
      return file.path;
    } catch (e) {
      _logger.e('Error guardando imagen: $e');
      return null;
    }
  }

  /// Elimina el archivo indicado y confirma si realmente pudo borrarse.
  /// Una ruta inexistente o un error de E/S producen `false`.
  Future<bool> deleteImage(String imagePath) async {
    try {
      final file = File(imagePath);
      if (file.existsSync()) {
        await file.delete();
        _logger.i('Imagen eliminada: $imagePath');
        return true;
      }
      return false;
    } catch (e) {
      _logger.e('Error eliminando imagen: $e');
      return false;
    }
  }
}

/// Resultado inmutable de la revisión previa al análisis de una imagen.
class ImageValidationResult {
  /// Indica si la imagen cumple formato y dimensiones mínimas.
  final bool isValid;

  /// Mensaje apto para diagnóstico o presentación en la interfaz.
  final String message;

  /// Dimensiones corregidas según la orientación EXIF, si pudieron obtenerse.
  final int? width;
  final int? height;

  /// Brillo promedio estimado en el intervalo de 0 a 255.
  final double? brightness;

  ImageValidationResult({
    required this.isValid,
    required this.message,
    this.width,
    this.height,
    this.brightness,
  });

  @override
  String toString() =>
      'ImageValidationResult(isValid: $isValid, message: $message, brightness: $brightness)';
}

/// Metadatos básicos de un archivo de imagen almacenado localmente.
class ImageInfo {
  /// Ruta absoluta del archivo consultado.
  final String path;

  /// Tamaño del archivo en bytes.
  final int size;

  /// Dimensiones codificadas de la imagen.
  final int width;
  final int height;

  /// Formato detectado por firma binaria: `jpg`, `png`, `gif` o `unknown`.
  final String format;

  /// Fecha de modificación reportada por el sistema de archivos.
  final DateTime lastModified;

  ImageInfo({
    required this.path,
    required this.size,
    required this.width,
    required this.height,
    required this.format,
    required this.lastModified,
  });

  /// Tamaño del archivo expresado en megabytes con dos decimales.
  String get sizeInMB => '${(size / (1024 * 1024)).toStringAsFixed(2)} MB';

  /// Dimensiones codificadas en el formato `ancho x alto`, sin espacios.
  String get dimensions => '${width}x$height';

  @override
  String toString() =>
      'ImageInfo(format: $format, dimensions: $dimensions, size: $sizeInMB)';
}
