/// Fuente única de constantes funcionales y metadatos de Labster.
///
/// La clase no puede instanciarse: sus valores son estáticos y se consultan
/// desde servicios, almacenamiento y componentes de interfaz.
abstract final class AppConfig {
  // Recursos y parámetros del modelo de clasificación ejecutado localmente.
  // Las rutas deben coincidir con los recursos declarados en `pubspec.yaml`.
  static const String modelPath = 'assets/models/instrument_model.tflite';
  static const String labelsPath = 'assets/models/labels.txt';
  // Ancho y alto esperados por la entrada cuadrada del modelo.
  static const int modelInputSize = 224;
  // Identifica la revisión del modelo, no la versión general de la aplicación.
  static const String modelVersion = '2.0.0';
  // Umbral provisional de aviso en Resultados; no validado con un conjunto
  // externo. No filtra las predicciones ni impide guardarlas en el historial.
  static const double confidenceThreshold = 0.5;

  // Nombre físico y versión del esquema de la base de datos SQLite local.
  // Incrementar `databaseVersion` requiere definir su migración correspondiente.
  static const String databaseName = 'lab_instruments.db';
  static const int databaseVersion = 1;

  // Límites utilizados al validar y comprimir las fotografías capturadas.
  static const int maxImageSizeBytes = 5 * 1024 * 1024;
  // Calidad JPEG expresada en una escala de 0 a 100.
  static const int imageQuality = 85;

  // Metadatos mostrados al usuario en títulos y pantallas informativas.
  static const String appName = 'Labster';
  static const String appVersion = '1.0.0';
  static const String appAuthor = 'EBASSK';
  static const String appDescription =
      'Identifica instrumentos de laboratorio sin conexión';
}
