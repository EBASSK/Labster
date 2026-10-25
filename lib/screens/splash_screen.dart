import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/providers.dart';

/// Pantalla de arranque que carga el modelo TFLite antes de abrir la cámara.
///
/// Mantiene una presentación mínima: logotipo, indicador de progreso y una
/// recuperación explícita si el modelo de reconocimiento no puede cargarse.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  // El mensaje solo tiene valor cuando la inicialización termina con error.
  String? _initializationError;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    // El provider centraliza únicamente la inicialización del servicio TFLite.
    _initializeApp();
  }

  /// Espera que el modelo TFLite esté listo y reemplaza el splash por la cámara.
  ///
  /// En un reintento se invalida el provider para ejecutar nuevamente todo el
  /// proceso, en vez de reutilizar el Future fallido anterior.
  Future<void> _initializeApp({bool retry = false}) async {
    if (retry) {
      ref.invalidate(initializationProvider);
    }

    if (mounted) {
      setState(() {
        _isInitializing = true;
        _initializationError = null;
      });
    }

    try {
      await ref.read(initializationProvider.future);
    } catch (_) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _initializationError =
              'No se pudo cargar el modelo de reconocimiento.';
        });
      }
      return;
    }

    // La operación puede terminar cuando la ruta ya no está montada.
    if (!mounted) return;
    context.go('/camera');
  }

  @override
  Widget build(BuildContext context) {
    // Fuerza iconos claros del sistema para conservar contraste con el fondo.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.black,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Center(
            child: _isInitializing ? _buildLoadingState() : _buildErrorState(),
          ),
        ),
      ),
    );
  }

  /// Construye el logotipo accesible y ofrece un icono de respaldo si falta el
  /// recurso gráfico empaquetado.
  Widget _buildLogo({double size = 78}) {
    return Semantics(
      label: 'Labster',
      image: true,
      child: Image.asset(
        'assets/imagenes/labster_logo.png',
        key: const Key('splashLogo'),
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return SizedBox(
            width: size,
            height: size,
            child: const Icon(
              Icons.science_outlined,
              color: Colors.white,
              size: 48,
            ),
          );
        },
      ),
    );
  }

  /// Superpone un indicador fino alrededor del logotipo durante la preparación.
  Widget _buildLoadingState() {
    return Semantics(
      key: const ValueKey('loading'),
      label: 'Labster, cargando',
      liveRegion: true,
      child: SizedBox(
        width: 112,
        height: 112,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const SizedBox(
              key: Key('splashProgress'),
              width: 108,
              height: 108,
              child: CircularProgressIndicator(
                color: Colors.white70,
                strokeWidth: 2,
              ),
            ),
            _buildLogo(),
          ],
        ),
      ),
    );
  }

  /// Informa el fallo de carga y permite repetir la inicialización completa.
  Widget _buildErrorState() {
    return Padding(
      key: const ValueKey('error'),
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildLogo(size: 82),
          const SizedBox(height: 24),
          Text(
            _initializationError!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: () => _initializeApp(retry: true),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white54),
            ),
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}
