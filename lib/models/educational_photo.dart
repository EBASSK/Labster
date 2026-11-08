/// Fotografía incluida en la aplicación, con procedencia y licencia conservadas.
/// Es material ilustrativo del catálogo; no forma parte del entrenamiento de IA.
class EducationalPhoto {
  final String asset;
  final String title;
  final String author;
  final String license;
  final String sourceUrl;
  final String licenseUrl;
  const EducationalPhoto(
      {required this.asset,
      required this.title,
      required this.author,
      required this.license,
      required this.sourceUrl,
      required this.licenseUrl});

  /// Tolera fichas antiguas sin foto y descarta rutas ajenas a nuestros recursos.
  static EducationalPhoto? tryParse(Object? value) {
    if (value is! Map) return null;
    for (final key in [
      'asset',
      'title',
      'author',
      'license',
      'sourceUrl',
      'licenseUrl'
    ]) {
      if (value[key] is! String || (value[key] as String).trim().isEmpty) {
        return null;
      }
    }
    if (!RegExp(r'^assets/catalog/photos/[a-z_]+\.jpg$')
        .hasMatch(value['asset'])) {
      return null;
    }
    for (final key in ['sourceUrl', 'licenseUrl']) {
      final uri = Uri.tryParse(value[key]);
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
    }
    return EducationalPhoto(
        asset: value['asset'],
        title: value['title'],
        author: value['author'],
        license: value['license'],
        sourceUrl: value['sourceUrl'],
        licenseUrl: value['licenseUrl']);
  }

  Map<String, dynamic> toJson() => {
        'asset': asset,
        'title': title,
        'author': author,
        'license': license,
        'sourceUrl': sourceUrl,
        'licenseUrl': licenseUrl
      };
}
