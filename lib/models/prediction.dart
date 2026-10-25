/// Rangos semánticos usados por la interfaz para interpretar una confianza.
enum ConfidenceLevel { high, medium, low }

/// Resultado individual producido por el modelo de reconocimiento.
///
/// Además de alimentar la pantalla de resultados, sus instancias se serializan
/// dentro de cada registro del historial para conservar las mejores opciones.
class Prediction {
  /// Etiqueta legible del instrumento, por ejemplo, «Microscopio».
  final String name;

  /// Puntuación normalizada entre 0.0 y 1.0; no es una probabilidad de acierto
  /// calibrada. Se conserva el nombre `confidence` por compatibilidad con SQLite.
  final double confidence;

  /// Agrupación funcional del instrumento, como «Óptica» o «Medición».
  final String category;

  /// Explicación opcional que puede complementar el resultado.
  final String? description;

  /// Referencia opcional a una imagen ilustrativa del instrumento.
  final String? imageUrl;

  const Prediction({
    required this.name,
    required this.confidence,
    required this.category,
    this.description,
    this.imageUrl,
  });

  /// Convierte la confianza normalizada a un porcentaje entero para la interfaz.
  ///
  /// Por ejemplo, un valor de `0.85` se presenta como `85`.
  int getConfidencePercent() {
    return (confidence * 100).toInt();
  }

  /// Traduce el valor numérico a un nivel de confianza comprensible.
  ///
  /// Estos cortes pertenecen a este modelo de presentación; algunas pantallas
  /// definen sus propios colores. No representan una validación estadística.
  ConfidenceLevel getConfidenceLevel() {
    if (confidence >= 0.8) {
      return ConfidenceLevel.high;
    }
    if (confidence >= 0.5) {
      return ConfidenceLevel.medium;
    }
    return ConfidenceLevel.low;
  }

  /// Devuelve el color hexadecimal asociado al nivel de confianza.
  ///
  /// Se entrega como texto porque el modelo no depende de clases visuales de
  /// Flutter y así también puede serializarse o reutilizarse fuera de widgets.
  String getConfidenceColor() {
    final level = getConfidenceLevel();
    switch (level) {
      case ConfidenceLevel.high:
        return '#10B981'; // Verde: confianza alta.
      case ConfidenceLevel.medium:
        return '#F59E0B'; // Naranja: resultado que conviene revisar.
      case ConfidenceLevel.low:
        return '#EF4444'; // Rojo: confianza insuficiente.
    }
  }

  /// Convierte la predicción a un mapa apto para JSON y persistencia local.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'confidence': confidence,
      'category': category,
      'description': description,
      'imageUrl': imageUrl,
    };
  }

  /// Reconstruye una predicción a partir de datos JSON almacenados.
  factory Prediction.fromJson(Map<String, dynamic> json) {
    return Prediction(
      name: json['name'] as String,
      confidence: json['confidence'] as double,
      category: json['category'] as String,
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String?,
    );
  }
}
