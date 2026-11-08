/// Metadatos de un enlace concreto, comprobados sin descargar el video.
/// La fecha no garantiza disponibilidad futura ni reproducción sin conexión.
class EducationalVideo {
  final String id;
  final String title;
  final String channel;
  final String checkedOn;
  final String note;
  const EducationalVideo(
      {required this.id,
      required this.title,
      required this.channel,
      required this.checkedOn,
      required this.note});

  Uri get uri => Uri.https('www.youtube.com', '/watch', {'v': id});

  /// Un recurso ausente o mal formado no debe impedir leer la ficha local.
  static EducationalVideo? tryParse(Object? value) {
    if (value is! Map) return null;
    for (final key in ['id', 'title', 'channel', 'checkedOn', 'note']) {
      if (value[key] is! String || (value[key] as String).trim().isEmpty) {
        return null;
      }
    }
    if (!RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(value['id'] as String) ||
        DateTime.tryParse(value['checkedOn'] as String) == null) {
      return null;
    }
    return EducationalVideo(
        id: value['id'] as String,
        title: value['title'] as String,
        channel: value['channel'] as String,
        checkedOn: value['checkedOn'] as String,
        note: value['note'] as String);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'channel': channel,
        'checkedOn': checkedOn,
        'note': note
      };
}
