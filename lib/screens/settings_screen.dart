import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_config.dart';
import '../providers/providers.dart';
import '../providers/theme_provider.dart';
import '../providers/palette_provider.dart';
import '../config/app_palette.dart';
import '../widgets/palette_options.dart';

/// Centro de información y configuración de Labster.
///
/// Organiza en tarjetas la apariencia, el modelo, permisos, privacidad,
/// detalles técnicos y licencias. La selección de tema se observa mediante
/// Riverpod para reflejar sus cambios sin reiniciar la navegación.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = _SettingsPalette.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final selectedPalette = ref.watch(paletteProvider);

    // Mantiene las barras del sistema integradas con el tema activo y conserva
    // el contraste de sus iconos tanto en modo claro como en modo oscuro.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: palette.background,
        statusBarIconBrightness:
            palette.isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness:
            palette.isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: palette.background,
        systemNavigationBarIconBrightness:
            palette.isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: palette.background,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(context, palette),
              Divider(
                height: 1,
                thickness: 1,
                indent: 20,
                endIndent: 20,
                color: palette.border,
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
                  children: [
                    _SettingsCard(
                      palette: palette,
                      icon: Icons.brightness_6_outlined,
                      title: 'Apariencia',
                      subtitle: selectedPalette == AppPalette.original
                          ? 'Tema ${_themeModeLabel(themeMode).toLowerCase()}'
                          : '${selectedPalette.label} · ${_themeModeLabel(themeMode)}',
                      onTap: () => _showThemeOptions(context),
                    ),
                    _SettingsCard(
                      palette: palette,
                      icon: Icons.psychology_outlined,
                      title: 'Reconocimiento',
                      subtitle: 'Modelo local, versión y clases',
                      onTap: () => _showModelInfo(context, ref),
                    ),
                    _SettingsCard(
                      palette: palette,
                      icon: Icons.photo_camera_outlined,
                      title: 'Cámara y permisos',
                      subtitle: 'Acceso a la cámara del dispositivo',
                      onTap: () => _showCameraPermissions(context, ref),
                    ),
                    _SettingsCard(
                      palette: palette,
                      icon: Icons.inventory_2_outlined,
                      title: 'Datos y privacidad',
                      subtitle: 'Escaneos almacenados únicamente en tu equipo',
                      onTap: () => _showPrivacyDialog(context),
                    ),
                    _SettingsCard(
                      palette: palette,
                      icon: Icons.memory_outlined,
                      title: 'Información técnica',
                      subtitle: 'Aplicación, modelo y almacenamiento',
                      onTap: () => _showTechnicalInfo(context),
                    ),
                    _SettingsCard(
                      palette: palette,
                      icon: Icons.gavel_outlined,
                      title: 'Términos y licencias',
                      subtitle: 'Uso responsable y software de terceros',
                      onTap: () => _showLegalOptions(context),
                    ),
                    _SettingsCard(
                      palette: palette,
                      icon: Icons.info_outline,
                      title: 'Acerca de Labster',
                      subtitle: 'Versión ${AppConfig.appVersion} · SENA',
                      onTap: () => _showAboutDialog(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Encabezado que vuelve a la ruta anterior o usa cámara como respaldo.
  Widget _buildHeader(BuildContext context, _SettingsPalette palette) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 18),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/camera');
              }
            },
            tooltip: 'Volver',
            icon: Icon(Icons.arrow_back, color: palette.primaryText),
          ),
          const SizedBox(width: 4),
          Text(
            'Ajustes',
            style: TextStyle(
              color: palette.primaryText,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  /// Permite elegir luminosidad y paleta por separado. La hoja es desplazable
  /// para que las opciones sigan accesibles en pantallas pequeñas o texto grande.
  Future<void> _showThemeOptions(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.88),
      builder: (sheetContext) => Consumer(
        builder: (context, ref, child) {
          final palette = _SettingsPalette.of(context);
          final selectedMode = ref.watch(themeModeProvider);
          return ColoredBox(
            color: palette.panel,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                      child: Text('Tema de la aplicación',
                          style: TextStyle(
                            color: palette.primaryText,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          )),
                    ),
                    _ThemeOption(
                      palette: palette,
                      icon: Icons.brightness_auto_outlined,
                      title: 'Sistema',
                      subtitle: 'Usa el tema configurado en tu dispositivo',
                      selected: selectedMode == ThemeMode.system,
                      onTap: () =>
                          _applyTheme(sheetContext, ref, ThemeMode.system),
                    ),
                    _ThemeOption(
                      palette: palette,
                      icon: Icons.light_mode_outlined,
                      title: 'Claro',
                      subtitle: 'Usa fondos claros de forma permanente',
                      selected: selectedMode == ThemeMode.light,
                      onTap: () =>
                          _applyTheme(sheetContext, ref, ThemeMode.light),
                    ),
                    _ThemeOption(
                      palette: palette,
                      icon: Icons.dark_mode_outlined,
                      title: 'Oscuro',
                      subtitle: 'Usa fondos oscuros de forma permanente',
                      selected: selectedMode == ThemeMode.dark,
                      onTap: () =>
                          _applyTheme(sheetContext, ref, ThemeMode.dark),
                    ),
                    const PaletteOptions(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Aplica y persiste el tema; ante un fallo mantiene abierta la hoja y avisa.
  Future<void> _applyTheme(
    BuildContext sheetContext,
    WidgetRef ref,
    ThemeMode mode,
  ) async {
    try {
      await ref.read(themeModeProvider.notifier).setThemeMode(mode);
      if (sheetContext.mounted) Navigator.pop(sheetContext);
    } on Object {
      if (!sheetContext.mounted) return;
      ScaffoldMessenger.of(sheetContext).showSnackBar(
        const SnackBar(
          content: Text('No se pudo guardar la preferencia de tema.'),
        ),
      );
    }
  }

  /// Combina la configuración declarada con las etiquetas disponibles del modelo.
  Future<void> _showModelInfo(BuildContext context, WidgetRef ref) {
    final labelCount = ref.read(tfliteServiceProvider).labels.length;

    return _showInfoDialog(
      context,
      title: 'Modelo de reconocimiento',
      icon: Icons.psychology_outlined,
      children: [
        _InfoRow(label: 'Versión', value: AppConfig.modelVersion),
        _InfoRow(
          label: 'Entrada',
          value: '${AppConfig.modelInputSize} × ${AppConfig.modelInputSize} px',
        ),
        _InfoRow(
          label: 'Clases disponibles',
          value:
              labelCount == 0 ? '10 instrumentos' : '$labelCount instrumentos',
        ),
        const _InfoRow(label: 'Procesamiento', value: 'Local, sin conexión'),
      ],
    );
  }

  /// Explica el uso de cámara y ofrece abrir la configuración del dispositivo.
  Future<void> _showCameraPermissions(
    BuildContext context,
    WidgetRef ref,
  ) {
    final palette = _SettingsPalette.of(context);
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: palette.panel,
        icon: Icon(
          Icons.photo_camera_outlined,
          color: palette.accent,
          size: 32,
        ),
        title: Text(
          'Cámara y permisos',
          style: TextStyle(color: palette.primaryText),
        ),
        content: Text(
          'LABSTER utiliza la cámara únicamente para capturar el instrumento que '
          'quieres identificar. Puedes revisar o cambiar el permiso desde los '
          'ajustes del dispositivo.',
          style: TextStyle(color: palette.secondaryText, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              // Se cierra primero el diálogo para no mantener un contexto modal
              // activo mientras Android o iOS abre su aplicación de ajustes.
              Navigator.pop(dialogContext);
              final opened =
                  await ref.read(cameraServiceProvider).openSettings();
              if (!context.mounted || opened) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('No se pudieron abrir los ajustes.'),
                ),
              );
            },
            child: const Text('Abrir ajustes'),
          ),
        ],
      ),
    );
  }

  /// Informa qué datos se guardan y confirma que el proceso es local.
  Future<void> _showPrivacyDialog(BuildContext context) {
    final palette = _SettingsPalette.of(context);
    return _showInfoDialog(
      context,
      title: 'Datos y privacidad',
      icon: Icons.shield_outlined,
      children: [
        Text(
          'Las imágenes, resultados, favoritos y notas se almacenan '
          'únicamente en este dispositivo. El reconocimiento se ejecuta de '
          'forma local y LABSTER no envía tus capturas a servidores externos.',
          style: TextStyle(color: palette.secondaryText, height: 1.55),
        ),
      ],
    );
  }

  /// Resume las tecnologías y versiones útiles para diagnóstico.
  Future<void> _showTechnicalInfo(BuildContext context) {
    return _showInfoDialog(
      context,
      title: 'Información técnica',
      icon: Icons.memory_outlined,
      children: const [
        _InfoRow(label: 'Aplicación', value: AppConfig.appVersion),
        _InfoRow(label: 'Modelo', value: AppConfig.modelVersion),
        _InfoRow(label: 'Motor', value: 'TensorFlow Lite'),
        _InfoRow(label: 'Base de datos', value: 'SQLite local'),
      ],
    );
  }

  /// Agrupa términos propios y licencias de terceros en una hoja inferior.
  Future<void> _showLegalOptions(BuildContext context) {
    final palette = _SettingsPalette.of(context);
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: palette.panel,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.fromLTRB(8, 4, 8, 12),
                child: Text(
                  'Términos y licencias',
                  style: TextStyle(
                    color: palette.primaryText,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            _LegalOption(
              palette: palette,
              icon: Icons.fact_check_outlined,
              title: 'Términos de uso',
              onTap: () {
                Navigator.pop(sheetContext);
                // No se espera el diálogo porque el toque ya completó su acción
                // y la hoja debe cerrar antes de presentarlo.
                unawaited(_showTermsDialog(context));
              },
            ),
            _LegalOption(
              palette: palette,
              icon: Icons.code_outlined,
              title: 'Licencias de código abierto',
              onTap: () {
                Navigator.pop(sheetContext);
                _openLicenses(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Advierte que la identificación es una ayuda educativa, no una garantía.
  Future<void> _showTermsDialog(BuildContext context) {
    final palette = _SettingsPalette.of(context);
    return _showInfoDialog(
      context,
      title: 'Términos de uso',
      icon: Icons.fact_check_outlined,
      children: [
        Text(
          'LABSTER es una herramienta educativa de apoyo. Las identificaciones '
          'pueden contener errores y deben verificarse visualmente antes de '
          'tomar decisiones de seguridad o manipular material de laboratorio.',
          style: TextStyle(color: palette.secondaryText, height: 1.55),
        ),
      ],
    );
  }

  /// Abre la página de licencias con el tema global actualmente seleccionado.
  void _openLicenses(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => const LicensePage(
          applicationName: AppConfig.appName,
          applicationVersion: AppConfig.appVersion,
        ),
      ),
    );
  }

  /// Presenta descripción, versión y autoría declaradas en AppConfig.
  Future<void> _showAboutDialog(BuildContext context) {
    final palette = _SettingsPalette.of(context);
    return _showInfoDialog(
      context,
      title: 'Acerca de LABSTER',
      icon: Icons.info_outline,
      children: [
        Text(
          AppConfig.appDescription,
          style: TextStyle(color: palette.secondaryText, height: 1.55),
        ),
        const SizedBox(height: 18),
        const _InfoRow(label: 'Versión', value: AppConfig.appVersion),
        const _InfoRow(label: 'Desarrollado por', value: AppConfig.appAuthor),
        const _InfoRow(label: 'Proyecto', value: 'SENA'),
      ],
    );
  }

  /// Plantilla común para diálogos informativos de apariencia consistente.
  Future<void> _showInfoDialog(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final palette = _SettingsPalette.of(context);
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: palette.panel,
        icon: Icon(icon, color: palette.accent, size: 32),
        title: Text(
          title,
          style: TextStyle(color: palette.primaryText),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta táctil reutilizada para cada categoría de ajustes.
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.palette,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final _SettingsPalette palette;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: palette.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(19),
          side: BorderSide(color: palette.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: palette.iconBackground,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: palette.accent,
                    size: 27,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: palette.primaryText,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.secondaryText,
                          fontSize: 13,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.chevron_right,
                  color: palette.secondaryText,
                  size: 28,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Fila de etiqueta y valor usada en fichas técnicas y de versión.
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = _SettingsPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: palette.secondaryText),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: palette.primaryText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Entrada navegable dentro de la hoja de términos y licencias.
class _LegalOption extends StatelessWidget {
  const _LegalOption({
    required this.palette,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final _SettingsPalette palette;
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: palette.accent),
      title: Text(
        title,
        style: TextStyle(color: palette.primaryText),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: palette.secondaryText,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

/// Opción táctil para elegir un modo de apariencia dentro de la hoja modal.
class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.palette,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final _SettingsPalette palette;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final selectedForeground = colors.onPrimaryContainer;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: selected ? colors.primaryContainer : palette.panel,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    icon,
                    color: selected ? selectedForeground : palette.accent,
                    size: 25,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: selected
                                ? selectedForeground
                                : palette.primaryText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: selected
                                ? selectedForeground
                                : palette.secondaryText,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    selected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color:
                        selected ? selectedForeground : palette.secondaryText,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Traduce los roles semánticos del tema global a la composición de Ajustes.
///
/// No almacena colores oscuros o claros propios: cada valor procede de
/// [ColorScheme], por lo que la pantalla responde también al modo del sistema.
class _SettingsPalette {
  const _SettingsPalette({
    required this.isDark,
    required this.background,
    required this.panel,
    required this.iconBackground,
    required this.border,
    required this.accent,
    required this.primaryText,
    required this.secondaryText,
  });

  factory _SettingsPalette.of(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return _SettingsPalette(
      isDark: theme.brightness == Brightness.dark,
      background: colors.surface,
      panel: colors.surfaceContainerLow,
      iconBackground: colors.primaryContainer,
      border: colors.outlineVariant,
      accent: colors.primary,
      primaryText: colors.onSurface,
      secondaryText: colors.onSurfaceVariant,
    );
  }

  final bool isDark;
  final Color background;
  final Color panel;
  final Color iconBackground;
  final Color border;
  final Color accent;
  final Color primaryText;
  final Color secondaryText;
}

/// Etiqueta breve que aparece en la tarjeta principal de apariencia.
String _themeModeLabel(ThemeMode mode) {
  return switch (mode) {
    ThemeMode.system => 'Sistema',
    ThemeMode.light => 'Claro',
    ThemeMode.dark => 'Oscuro',
  };
}
