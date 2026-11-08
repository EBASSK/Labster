import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/educational_instrument.dart';
import '../services/video_link_service.dart';

/// Mantiene lectura y navegación local disponibles aunque falle un enlace.
class InstrumentVideo extends ConsumerStatefulWidget {
  final EducationalInstrument instrument;
  const InstrumentVideo({super.key, required this.instrument});
  @override
  ConsumerState<InstrumentVideo> createState() => _InstrumentVideoState();
}

class _InstrumentVideoState extends ConsumerState<InstrumentVideo> {
  bool _opening = false;
  String? _error;
  Uri get _search => Uri.https('www.youtube.com', '/results', {
        'search_query':
            '${widget.instrument.name} funcionamiento uso laboratorio'
      });

  Future<void> _open(Uri uri) async {
    setState(() {
      _opening = true;
      _error = null;
    });
    var opened = false;
    try {
      opened = await ref.read(videoLinkOpenerProvider)(uri);
    } on Object {
      opened = false;
    }
    if (!mounted) return;
    setState(() {
      _opening = false;
      if (!opened) {
        _error =
            'No se pudo abrir YouTube. Comprueba que tengas una aplicación compatible o copia el enlace.';
      }
    });
  }

  Future<void> _copy() async {
    try {
      await Clipboard.setData(ClipboardData(
          text: (widget.instrument.video?.uri ?? _search).toString()));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enlace copiado')));
    } on Object {
      if (mounted) {
        setState(() => _error =
            'No se pudo copiar el enlace. Puedes seleccionarlo a continuación.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final video = widget.instrument.video;
    final theme = Theme.of(context);
    return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Recursos audiovisuales', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          if (video == null)
            const Text('Video pendiente de verificación.')
          else ...[
            Text(video.title, style: theme.textTheme.titleMedium),
            Text('Canal: ${video.channel}'),
            Text(video.note),
            const SizedBox(height: 8),
            OutlinedButton.icon(
                onPressed: _opening ? null : () => _open(video.uri),
                icon: const Icon(Icons.play_circle_outline),
                label: const Text('Ver en YouTube')),
          ],
          const Text(
              'Los videos necesitan internet y se abren fuera de Labster. La ficha sigue disponible sin conexión.'),
          const SizedBox(height: 8),
          const Text(
              'Si el video no está disponible, puedes buscar otra explicación. Los resultados de búsqueda no están verificados.'),
          Wrap(spacing: 8, children: [
            TextButton(
                onPressed: _opening ? null : () => _open(_search),
                child: const Text('Buscar en YouTube')),
            TextButton(onPressed: _copy, child: const Text('Copiar enlace')),
          ]),
          if (_opening)
            const LinearProgressIndicator(semanticsLabel: 'Abriendo YouTube'),
          if (_error != null) ...[
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            SelectableText((video?.uri ?? _search).toString()),
          ],
        ]));
  }
}
