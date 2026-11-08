/// Relaciona etiquetas de inferencia e historial con IDs estables del catálogo.
/// Esta correspondencia permite abrir fichas; no añade clases al modelo TFLite.
class InstrumentCatalogLink {
  static const aliases = <String, String>{
    'bureta': 'buretas',
    'buretas': 'buretas',
    'crisol': 'crisoles',
    'crisoles': 'crisoles',
    'embudo': 'embudos',
    'embudos': 'embudos',
    'gradilla': 'gradillas',
    'gradillas': 'gradillas',
    'matraz': 'matraces',
    'matraces': 'matraces',
    'microscopio': 'microscopio',
    'pinzas de laboratorio': 'pinzas',
    'pinza': 'pinzas',
    'pinzas': 'pinzas',
    'pipeta': 'pipetas',
    'pipetas': 'pipetas',
    'probeta': 'probeta',
    'probetas': 'probeta',
    'vasos precipitado': 'vasos_precipitado',
    'vasos de precipitado': 'vasos_precipitado',
    'vaso de precipitados': 'vasos_precipitado',
    'vaso de precipitado': 'vasos_precipitado',
    'spectrophotometer': 'spectrophotometer',
    'espectrofotómetro': 'spectrophotometer',
    'centrifuge': 'centrifuge',
    'centrífuga de laboratorio': 'centrifuge',
    'autoclave': 'autoclave',
    'incubator': 'incubator',
    'incubadora de laboratorio': 'incubator',
    'analytical balance': 'analytical_balance',
    'balanza analítica': 'analytical_balance',
    'ph meter': 'ph_meter',
    'medidor de ph': 'ph_meter',
    'magnetic stirrer': 'magnetic_stirrer',
    'agitador magnético': 'magnetic_stirrer',
    'water bath': 'water_bath',
    'baño maría de laboratorio': 'water_bath',
    'refractometer': 'refractometer',
    'refractómetro': 'refractometer',
    'conductivity meter': 'conductivity_meter',
    'conductímetro': 'conductivity_meter',
  };

  /// Admite nombres antiguos y el formato con guiones bajos de labels.txt.
  /// Una etiqueta desconocida nunca se redirige a una ficha aproximada.
  static String? idForLabel(String label) => aliases[label
      .trim()
      .toLowerCase()
      .replaceAll('_', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')];
}
