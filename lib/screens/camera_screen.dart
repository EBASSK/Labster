import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/providers.dart';
import '../services/camera_service.dart';

/// Pantalla principal de captura.
///
/// Administra la vista previa de la cámara, sus permisos y ciclo de vida, y
/// envía la fotografía al proveedor de predicción antes de abrir resultados.
class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen>
    with WidgetsBindingObserver {
  /// Servicio compartido que encapsula el controlador nativo de la cámara.
  late final CameraService _cameraService;

  // Estos indicadores separan una cámara lista de una inicialización en curso.
  // La distinción evita mostrar la vista previa o iniciar el proceso dos veces.
  bool _isInitialized = false;
  bool _isInitializingCamera = false;

  // Se marca como falsa mientras otra ruta cubre esta pantalla. Así no se
  // intenta reabrir la cámara hasta que el usuario realmente regrese.
  bool _isScreenActive = true;
  bool _isCapturing = false;
  bool _isFlashOn = false;

  // Conserva la liberación en curso para que reanudar espere a que el
  // controlador anterior haya terminado de cerrarse.
  Future<void>? _suspensionFuture;
  String? _cameraError;
  String? _cameraErrorCode;

  // Límites informados por el dispositivo; no todos los teléfonos admiten el
  // mismo intervalo de zoom.
  double _zoomLevel = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 1.0;

  /// Indica si el error actual requiere que el usuario cambie un permiso.
  bool get _isPermissionError {
    return _cameraErrorCode == 'CameraAccessDenied' ||
        _cameraErrorCode == 'CameraAccessDeniedWithoutPrompt' ||
        _cameraErrorCode == 'CameraAccessRestricted';
  }

  @override
  void initState() {
    super.initState();
    // El observador permite liberar el recurso cuando la aplicación pasa a
    // segundo plano y recuperarlo al volver.
    WidgetsBinding.instance.addObserver(this);
    _cameraService = ref.read(cameraServiceProvider);
    unawaited(_initializeCamera());
  }

  /// Inicializa la cámara y obtiene sus límites de zoom sin permitir carreras.
  Future<void> _initializeCamera() async {
    if (!_isScreenActive || _isInitializingCamera) return;

    _isInitializingCamera = true;
    if (mounted) {
      setState(() {
        _cameraError = null;
        _cameraErrorCode = null;
      });
    }

    try {
      await _cameraService.initialize();
      final limits = await _cameraService.getZoomLimits();

      // La operación nativa puede terminar después de abandonar la pantalla;
      // en ese caso se libera inmediatamente el controlador recién creado.
      if (!mounted || !_isScreenActive) {
        await _cameraService.dispose();
        return;
      }

      if (!_cameraService.isInitialized || _cameraService.controller == null) {
        setState(() {
          _isInitialized = false;
          _cameraErrorCode = null;
          _cameraError =
              'La cámara se cerró antes de completar la inicialización. '
              'Vuelve a intentarlo.';
        });
        return;
      }

      final minZoom = limits['min'] ?? 1.0;
      setState(() {
        _isInitialized = true;
        _minZoom = minZoom;
        _maxZoom = limits['max'] ?? minZoom;
        _zoomLevel = minZoom;
        _isFlashOn = false;
      });
    } on CameraException catch (error) {
      // Se conserva el código nativo para distinguir permisos de otros fallos.
      if (!mounted) return;
      setState(() {
        _isInitialized = false;
        _cameraErrorCode = error.code;
        _cameraError = _messageForCameraError(error.code);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isInitialized = false;
        _cameraErrorCode = null;
        _cameraError =
            'No se pudo abrir la cámara. Cierra otras aplicaciones que '
            'puedan estar usándola y vuelve a intentarlo.';
      });
    } finally {
      _isInitializingCamera = false;
    }
  }

  /// Convierte los códigos del complemento de cámara en mensajes comprensibles.
  String _messageForCameraError(String code) {
    switch (code) {
      case 'CameraAccessDenied':
      case 'CameraAccessDeniedWithoutPrompt':
        return 'Labster necesita acceso a la cámara para identificar '
            'instrumentos. Concede el permiso en los ajustes del dispositivo.';
      case 'CameraAccessRestricted':
        return 'El acceso a la cámara está restringido en este dispositivo. '
            'Revisa los controles de seguridad o administración.';
      default:
        return 'No se pudo iniciar la cámara. Reinicia la aplicación e '
            'inténtalo nuevamente.';
    }
  }

  /// Abre la configuración del sistema cuando el permiso no puede solicitarse
  /// nuevamente desde la aplicación.
  Future<void> _openDeviceSettings() async {
    final opened = await _cameraService.openSettings();
    if (!mounted || opened) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No se pudieron abrir los ajustes del dispositivo.'),
      ),
    );
  }

  /// Captura una imagen, ejecuta la clasificación local y abre sus resultados.
  Future<void> _captureAndPredict() async {
    if (_isCapturing || !_isInitialized) return;

    var loadingDialogIsOpen = false;
    setState(() => _isCapturing = true);

    try {
      // El diálogo impide nuevas acciones mientras la captura y la inferencia
      // se completan de forma asíncrona.
      unawaited(
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
            ),
          ),
        ),
      );
      loadingDialogIsOpen = true;

      final image = await _cameraService.takePicture();
      if (image == null) {
        // Cerrar explícitamente el diálogo evita dejar una capa bloqueando la
        // interfaz cuando el dispositivo no entrega un archivo.
        if (!mounted) return;
        if (loadingDialogIsOpen) {
          Navigator.of(context, rootNavigator: true).pop();
          loadingDialogIsOpen = false;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo capturar la imagen.')),
        );
        return;
      }

      await ref.read(predictionNotifierProvider.notifier).predict(image.path);

      if (mounted && loadingDialogIsOpen) {
        Navigator.of(context, rootNavigator: true).pop();
        loadingDialogIsOpen = false;
      }

      if (mounted) {
        // La ruta recibe la ubicación temporal; al guardar se crea una copia
        // procesada dentro del almacenamiento privado de la aplicación.
        await _openRoute('/results', extra: image.path);
      }
    } catch (error) {
      if (mounted && loadingDialogIsOpen) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo analizar la imagen: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  /// Intenta alternar entre flash apagado y luz continua (`torch`).
  Future<void> _toggleFlash() async {
    await _cameraService.toggleFlash();
    if (!mounted) return;

    setState(() {
      _isFlashOn = _cameraService.currentFlashMode != FlashMode.off;
    });
  }

  /// Aplica el valor del control deslizante directamente al controlador nativo.
  Future<void> _handleZoom(double value) async {
    await _cameraService.controller?.setZoomLevel(value);
    if (!mounted) return;
    setState(() => _zoomLevel = value);
  }

  /// Abre una pantalla secundaria sin mantener ocupado el recurso de cámara.
  ///
  /// `push` permite esperar el regreso desde historial, ajustes o resultados;
  /// al completarse, esta misma instancia vuelve a inicializar la cámara.
  Future<void> _openRoute(String route, {Object? extra}) async {
    _isScreenActive = false;
    await _cameraService.dispose();
    if (!mounted) return;
    setState(() => _isInitialized = false);

    await context.push(route, extra: extra);

    if (!mounted) return;
    _isScreenActive = true;
    await _initializeCamera();
  }

  /// Serializa la suspensión para no disponer el mismo controlador dos veces.
  Future<void> _suspendCamera() {
    final pendingSuspension = _suspensionFuture;
    if (pendingSuspension != null) return pendingSuspension;

    final suspension = _releaseCamera();
    _suspensionFuture = suspension;
    return suspension.whenComplete(() {
      if (identical(_suspensionFuture, suspension)) {
        _suspensionFuture = null;
      }
    });
  }

  /// Libera la cámara y refleja inmediatamente el estado detenido en la UI.
  Future<void> _releaseCamera() async {
    await _cameraService.dispose();
    if (mounted) {
      setState(() {
        _isInitialized = false;
        _isFlashOn = false;
      });
    }
  }

  /// Espera cualquier cierre pendiente y recupera la cámara al volver al frente.
  Future<void> _resumeCamera() async {
    await _suspensionFuture;
    if (!mounted || !_isScreenActive || _cameraService.isInitialized) return;
    await _initializeCamera();
  }

  /// Libera la cámara al perder el primer plano y la recupera al reanudar.
  ///
  /// Android también notifica `inactive` al abrir el diálogo de permisos; por
  /// eso solo se suspende cuando ya existe un controlador completamente activo.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraService.controller;
    final hasActiveController =
        controller != null && controller.value.isInitialized;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // En Android, el diálogo de permisos también produce el estado
      // `inactive`. Se ignora esa transición hasta que exista un controlador
      // completamente inicializado para no interrumpir la solicitud.
      if (hasActiveController) {
        unawaited(_suspendCamera());
      }
      return;
    }

    if (state == AppLifecycleState.resumed &&
        _isScreenActive &&
        !_cameraService.isInitialized) {
      unawaited(_resumeCamera());
    }
  }

  @override
  Widget build(BuildContext context) {
    // Los estados de error y preparación se renderizan antes de intentar usar
    // CameraPreview, que exige un controlador inicializado.
    if (_cameraError != null) {
      return _buildCameraError();
    }

    if (!_isInitialized || _cameraService.controller == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text('Capturar'),
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              ),
              SizedBox(height: 18),
              Text(
                'Preparando cámara',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_cameraService.controller!),
          CustomPaint(painter: CameraFramePainter()),
          _buildTopBar(),
          _buildCaptureGuidance(),
          _buildBottomControls(),
        ],
      ),
    );
  }

  /// Presenta una recuperación específica para permisos o un reintento general.
  Widget _buildCameraError() {
    return Scaffold(
      appBar: AppBar(title: const Text('Capturar')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isPermissionError
                    ? Icons.camera_alt_outlined
                    : Icons.camera_enhance_outlined,
                size: 56,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 20),
              Text(
                _isPermissionError
                    ? 'Permiso de cámara requerido'
                    : 'Cámara no disponible',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                _cameraError!,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (_isPermissionError)
                FilledButton.icon(
                  onPressed: _openDeviceSettings,
                  icon: const Icon(Icons.settings_outlined),
                  label: const Text('Abrir ajustes'),
                )
              else
                FilledButton.icon(
                  onPressed: _initializeCamera,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Barra superpuesta con accesos a historial y ajustes.
  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              _CameraIconButton(
                icon: Icons.history_outlined,
                tooltip: 'Historial',
                onPressed: () => _openRoute('/history'),
              ),
              const Expanded(
                child: Text(
                  'Escanear instrumento',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _CameraIconButton(
                icon: Icons.settings_outlined,
                tooltip: 'Ajustes',
                onPressed: () => _openRoute('/settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Mensaje breve de encuadre colocado sobre la vista previa.
  Widget _buildCaptureGuidance() {
    return Positioned(
      top: 88,
      left: 24,
      right: 24,
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.64),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white24),
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Text(
              'Centra un instrumento dentro del marco',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Controles inferiores de zoom, flash y obturador.
  Widget _buildBottomControls() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        minimum: const EdgeInsets.only(bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_maxZoom - _minZoom > 0.1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Row(
                  children: [
                    const Icon(
                      Icons.zoom_out,
                      color: Colors.white70,
                      size: 18,
                    ),
                    Expanded(
                      child: Slider(
                        value: _zoomLevel.clamp(_minZoom, _maxZoom),
                        min: _minZoom,
                        max: _maxZoom,
                        onChanged: _handleZoom,
                        activeColor: Colors.white,
                        inactiveColor: Colors.white30,
                      ),
                    ),
                    SizedBox(
                      width: 38,
                      child: Text(
                        '${_zoomLevel.toStringAsFixed(1)}x',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 6, 28, 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _CameraIconButton(
                    icon: _isFlashOn
                        ? Icons.flash_on_outlined
                        : Icons.flash_off_outlined,
                    tooltip: _isFlashOn ? 'Desactivar flash' : 'Activar flash',
                    onPressed: _toggleFlash,
                    active: _isFlashOn,
                  ),
                  Semantics(
                    button: true,
                    label: 'Capturar imagen',
                    child: GestureDetector(
                      onTap: _isCapturing ? null : _captureAndPredict,
                      child: AnimatedOpacity(
                        opacity: _isCapturing ? 0.5 : 1,
                        duration: const Duration(milliseconds: 160),
                        child: Container(
                          width: 78,
                          height: 78,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            color: Colors.black26,
                          ),
                          child: Center(
                            child: Container(
                              width: 62,
                              height: 62,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48, height: 48),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _isScreenActive = false;
    // `dispose` no puede ser asíncrono; el servicio finaliza el cierre sin
    // bloquear la destrucción del widget.
    unawaited(_cameraService.dispose());
    super.dispose();
  }
}

/// Botón circular reutilizado por las acciones superpuestas de la cámara.
class _CameraIconButton extends StatelessWidget {
  const _CameraIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon),
      tooltip: tooltip,
      color: active ? Colors.black : Colors.white,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: active ? Colors.white : Colors.black54,
        minimumSize: const Size(48, 48),
        shape: const CircleBorder(
          side: BorderSide(color: Colors.white24),
        ),
      ),
    );
  }
}

/// Dibuja la máscara oscura y las esquinas que delimitan el área de captura.
class CameraFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // El marco se adapta al lado más pequeño y limita su altura para conservar
    // espacio para instrucciones y controles en pantallas compactas.
    final frameSize =
        math.min(300.0, math.min(size.width - 48, size.height * 0.4));
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: frameSize,
      height: frameSize,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(18));

    final overlayPath = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(rrect)
      ..fillType = PathFillType.evenOdd;

    // El relleno par-impar oscurece el exterior sin cubrir el área central.
    canvas.drawPath(
      overlayPath,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.5)
        ..style = PaintingStyle.fill,
    );

    const cornerSize = 38.0;
    final cornerPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke;

    canvas.drawPath(
      Path()
        ..moveTo(rect.left, rect.top + cornerSize)
        ..lineTo(rect.left, rect.top)
        ..lineTo(rect.left + cornerSize, rect.top),
      cornerPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(rect.right - cornerSize, rect.top)
        ..lineTo(rect.right, rect.top)
        ..lineTo(rect.right, rect.top + cornerSize),
      cornerPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(rect.left, rect.bottom - cornerSize)
        ..lineTo(rect.left, rect.bottom)
        ..lineTo(rect.left + cornerSize, rect.bottom),
      cornerPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(rect.right - cornerSize, rect.bottom)
        ..lineTo(rect.right, rect.bottom)
        ..lineTo(rect.right, rect.bottom - cornerSize),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(CameraFramePainter oldDelegate) => false;
}
