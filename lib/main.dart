import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'config/theme.dart';
import 'config/app_config.dart';
import 'models/scan_history.dart';
import 'providers/theme_provider.dart';
import 'providers/palette_provider.dart';
import 'services/palette_preferences_service.dart';
import 'screens/splash_screen.dart';
import 'screens/camera_screen.dart';
import 'screens/results_screen.dart';
import 'screens/history_screen.dart';
import 'screens/detail_screen.dart';
import 'screens/settings_screen.dart';
import 'services/theme_preferences_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // La preferencia se lee antes del primer frame para que la aplicación no
  // muestre brevemente un tema distinto al que eligió el usuario.
  final themePreferences = ThemePreferencesService();
  final initialThemeMode = await themePreferences.loadThemeMode();
  final palettePreferences = PalettePreferencesService();
  final initialPalette = await palettePreferences.loadPalette();

  // ProviderScope crea el contenedor global donde Riverpod conserva y comparte
  // el estado de los servicios durante toda la ejecución de la aplicación.
  runApp(
    ProviderScope(
      overrides: [
        themePreferencesStoreProvider.overrideWithValue(themePreferences),
        initialThemeModeProvider.overrideWithValue(initialThemeMode),
        paletteStoreProvider.overrideWithValue(palettePreferences),
        initialPaletteProvider.overrideWithValue(initialPalette),
      ],
      child: const MyApp(),
    ),
  );
}

/// Widget raíz de Labster.
///
/// Conserva una única instancia del enrutador aunque cambie el tema. Así, una
/// selección visual no reinicia la navegación ni devuelve al usuario al splash.
class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    // GoRouter se crea una sola vez para mantener la pila de rutas durante las
    // reconstrucciones provocadas por una nueva preferencia de apariencia.
    _router = GoRouter(
      // El splash es la entrada porque allí se preparan los recursos necesarios
      // antes de habilitar el flujo principal de captura.
      initialLocation: '/',
      routes: [
        // Inicialización del modelo local y transición hacia la cámara.
        GoRoute(
          path: '/',
          builder: (context, state) => const SplashScreen(),
        ),
        // Vista principal para encuadrar y capturar el instrumento.
        GoRoute(
          path: '/camera',
          builder: (context, state) => const CameraScreen(),
        ),
        // La ruta de la fotografía se transmite mediante `extra` porque es un
        // dato temporal del flujo y no necesita formar parte de la URL.
        GoRoute(
          path: '/results',
          builder: (context, state) {
            // La conversión admite null para poder responder de forma segura si
            // otro punto de la aplicación abre esta ruta sin una fotografía.
            final imagePath = state.extra as String?;
            if (imagePath == null || imagePath.isEmpty) {
              return const Scaffold(
                body: Center(
                  child: Text('No se encontró la ruta de resultados.'),
                ),
              );
            }
            return ResultsScreen(imagePath: imagePath);
          },
        ),
        // Lista persistida de identificaciones realizadas anteriormente.
        GoRoute(
          path: '/history',
          builder: (context, state) => const HistoryScreen(),
        ),
        // El identificador permite recuperar el registro desde SQLite. `extra`
        // evita otra consulta cuando la pantalla anterior ya posee el objeto.
        GoRoute(
          path: '/detail/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            final scan = state.extra as ScanHistory?;
            return DetailScreen(scanId: id, scan: scan);
          },
        ),
        // Preferencias e información técnica de la aplicación.
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
      // Cualquier ruta desconocida termina en una vista recuperable, desde la
      // que el usuario puede volver a ejecutar la inicialización normal.
      errorBuilder: (context, state) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: ${state.error}'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/'),
                child: const Text('Volver al inicio'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final palette = ref.watch(paletteProvider);

    // MaterialApp.router enlaza GoRouter con Material 3 y aplica en tiempo real
    // el modo del sistema, claro u oscuro seleccionado desde Ajustes.
    return MaterialApp.router(
      title: AppConfig.appName,
      theme: AppTheme.forPalette(palette, Brightness.light),
      darkTheme: AppTheme.forPalette(palette, Brightness.dark),
      themeMode: themeMode,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}
