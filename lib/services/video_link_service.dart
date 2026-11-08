import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Se sustituye en pruebas para no abrir el navegador real del usuario.
final videoLinkOpenerProvider =
    Provider<Future<bool> Function(Uri)>((ref) => VideoLinkService.open);

abstract final class VideoLinkService {
  /// Solo admite videos y búsquedas HTTPS de YouTube; no ejecuta esquemas
  /// arbitrarios procedentes de contenido importado o de SQLite.
  static bool isAllowed(Uri uri) =>
      uri.scheme == 'https' &&
      uri.host == 'www.youtube.com' &&
      uri.userInfo.isEmpty &&
      (!uri.hasPort || uri.port == 443) &&
      ((uri.path == '/watch' &&
              RegExp(r'^[A-Za-z0-9_-]{11}$')
                  .hasMatch(uri.queryParameters['v'] ?? '')) ||
          (uri.path == '/results' &&
              (uri.queryParameters['search_query'] ?? '').trim().isNotEmpty));

  /// Abrir correctamente significa entregar el enlace a otra aplicación.
  /// Los errores posteriores de red o reproducción los gestiona YouTube.
  static Future<bool> open(Uri uri) async {
    if (!isAllowed(uri)) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication)
          .timeout(const Duration(seconds: 10), onTimeout: () => false);
    } on Object {
      return false;
    }
  }
}
