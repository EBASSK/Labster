import 'educational_video.dart';
import 'educational_photo.dart';

/// Ficha local compartida por catálogo y escaneos. Tener una ficha no implica
/// que el modelo instalado pueda reconocer esa clase.
class EducationalInstrument {
  final String id;
  final String name;
  final String englishName;
  final String category;
  final String description;
  final String principle;
  final List<String> parts;
  final List<String> steps;
  final List<String> applications;
  final List<String> safety;
  final String sourceName;
  final String sourceUrl;
  final EducationalVideo? video;
  final EducationalPhoto? photo;

  const EducationalInstrument(
      {required this.id,
      required this.name,
      required this.englishName,
      required this.category,
      required this.description,
      required this.principle,
      required this.parts,
      required this.steps,
      required this.applications,
      required this.safety,
      required this.sourceName,
      required this.sourceUrl,
      this.video,
      this.photo});

  /// Rechaza fichas incompletas antes de iniciar una escritura en SQLite.
  factory EducationalInstrument.fromJson(Map<String, dynamic> json) {
    String field(String key) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty) {
        throw FormatException('Campo educativo inválido: $key');
      }
      return value;
    }

    List<String> items(String key) {
      final value = json[key];
      if (value is! List ||
          value.isEmpty ||
          value.any((item) => item is! String || item.trim().isEmpty)) {
        throw FormatException('Sección educativa inválida: $key');
      }
      return List<String>.unmodifiable(value.cast<String>());
    }

    final url = field('sourceUrl');
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw const FormatException('Fuente educativa inválida');
    }
    return EducationalInstrument(
        id: field('id'),
        name: field('name'),
        englishName: field('englishName'),
        category: field('category'),
        description: field('description'),
        principle: field('principle'),
        parts: items('parts'),
        steps: items('steps'),
        applications: items('applications'),
        safety: items('safety'),
        sourceName: field('sourceName'),
        sourceUrl: url,
        video: EducationalVideo.tryParse(json['video']),
        photo: EducationalPhoto.tryParse(json['photo']));
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'englishName': englishName,
        'category': category,
        'description': description,
        'principle': principle,
        'parts': parts,
        'steps': steps,
        'applications': applications,
        'safety': safety,
        'sourceName': sourceName,
        'sourceUrl': sourceUrl,
        if (video != null) 'video': video!.toJson(),
        if (photo != null) 'photo': photo!.toJson()
      };
}
