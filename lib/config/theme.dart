import 'package:flutter/material.dart';
import 'app_palette.dart';

/// Sistema visual compartido por todas las pantallas de Labster.
///
/// Centralizar colores, tipografías, espaciados y sombras evita valores aislados
/// en los widgets y mantiene coherencia entre los modos claro y oscuro.
class AppTheme {
  // Colores de identidad usados en acciones y elementos destacados.
  static const Color primaryColor = Color(0xFF2563EB); // Azul
  static const Color secondaryColor = Color(0xFF10B981); // Verde
  static const Color accentColor = Color(0xFFF59E0B); // Naranja
  // Alias cortos conservados para los componentes que ya consumen estos nombres.
  static const Color primary = primaryColor;
  static const Color secondary = secondaryColor;
  static const Color accent = accentColor;
  // Fondo oscuro base utilizado fuera de los componentes de Material.
  static const Color darkBg = Color(0xFF111827);

  // Neutros para fondos, superficies, texto secundario y divisores.
  static const Color darkGrey = Color(0xFF1F2937);
  static const Color mediumGrey = Color(0xFF6B7280);
  static const Color lightGrey = Color(0xFFF3F4F6);
  static const Color whiteColor = Color(0xFFFFFFFF);

  // Colores semánticos: comunican éxito, error, advertencia o información.
  static const Color successColor = Color(0xFF10B981);
  static const Color errorColor = Color(0xFFEF4444);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color infoColor = Color(0xFF3B82F6);

  // `fromSeed` genera todos los roles de Material 3 (contenedores, contornos y
  // variantes de superficie) para que los componentes respondan de forma
  // coherente al brillo claro u oscuro sin colores locales improvisados.
  static final ColorScheme lightColorScheme = ColorScheme.fromSeed(
    seedColor: primaryColor,
    brightness: Brightness.light,
  ).copyWith(
    secondary: secondaryColor,
    tertiary: accentColor,
    error: errorColor,
  );

  static final ColorScheme darkColorScheme = ColorScheme.fromSeed(
    seedColor: primaryColor,
    brightness: Brightness.dark,
  ).copyWith(
    secondary: secondaryColor,
    tertiary: accentColor,
    error: errorColor,
  );

  /// Tema claro construido sobre Material 3.
  ///
  /// Define los estilos por defecto de los controles para que las pantallas solo
  /// tengan que personalizar aquello que sea específico de su composición.
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: lightColorScheme,
    scaffoldBackgroundColor: lightColorScheme.surface,
    appBarTheme: AppBarTheme(
      elevation: 0,
      backgroundColor: lightColorScheme.surface,
      foregroundColor: lightColorScheme.onSurface,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: lightColorScheme.onSurface,
        fontSize: 20,
        fontWeight: FontWeight.bold,
        fontFamily: 'Poppins',
      ),
    ),
    textTheme: _buildTextTheme(),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: whiteColor,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 2,
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          fontFamily: 'Poppins',
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryColor,
        side: const BorderSide(color: primaryColor, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          fontFamily: 'Poppins',
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: lightColorScheme.surfaceContainerLowest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: lightColorScheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: lightColorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: errorColor),
      ),
      labelStyle: TextStyle(
        color: lightColorScheme.onSurfaceVariant,
        fontFamily: 'Poppins',
      ),
    ),
    cardTheme: CardTheme(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: lightColorScheme.surfaceContainerLow,
    ),
  );

  /// Tema oscuro equivalente al tema claro, con superficies y textos adaptados.
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: darkColorScheme,
    scaffoldBackgroundColor: darkColorScheme.surface,
    appBarTheme: AppBarTheme(
      elevation: 0,
      backgroundColor: darkColorScheme.surface,
      foregroundColor: darkColorScheme.onSurface,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: darkColorScheme.onSurface,
        fontSize: 20,
        fontWeight: FontWeight.bold,
        fontFamily: 'Poppins',
      ),
    ),
    textTheme: _buildDarkTextTheme(),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: whiteColor,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 2,
      ),
    ),
    cardTheme: CardTheme(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: darkColorScheme.surfaceContainerLow,
    ),
  );

  /// Aplica una paleta sin alterar el modo de luminosidad elegido por el usuario.
  /// Los tonos extremos se reservan para texto y fondos; los intermedios se usan
  /// en contenedores y bordes. Los estados de error conservan su significado.
  static ThemeData forPalette(AppPalette palette, Brightness brightness) {
    final base = brightness == Brightness.dark ? darkTheme : lightTheme;
    if (palette == AppPalette.original) return base;
    final dark = brightness == Brightness.dark;
    final colors = palette.colors;
    final foreground = dark ? colors[4] : colors[0];
    final background = dark ? colors[0] : colors[4];
    final primary = dark ? colors[3] : colors[1];
    final onPrimary = dark ? colors[0] : colors[4];
    final panel =
        Color.lerp(background, dark ? colors[1] : Colors.white, 0.35)!;
    final scheme = ColorScheme.fromSeed(
      seedColor: colors[2],
      brightness: brightness,
    ).copyWith(
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: dark ? colors[1] : colors[3],
      onPrimaryContainer: foreground,
      secondary: primary,
      onSecondary: onPrimary,
      secondaryContainer: dark ? colors[1] : colors[3],
      onSecondaryContainer: foreground,
      tertiary: primary,
      onTertiary: onPrimary,
      surface: background,
      onSurface: foreground,
      onSurfaceVariant: foreground,
      surfaceContainerLowest: background,
      surfaceContainerLow: panel,
      surfaceContainer: panel,
      surfaceContainerHigh: Color.lerp(background, colors[2], 0.18),
      surfaceContainerHighest: Color.lerp(background, colors[2], 0.25),
      outline: colors[2],
      outlineVariant: Color.lerp(background, colors[2], 0.5),
      inverseSurface: foreground,
      onInverseSurface: background,
      inversePrimary: dark ? colors[1] : colors[3],
      surfaceTint: colors[2],
    );
    // copyWith conserva tamaños y tipografías existentes; se sustituyen también
    // los estilos que antes fijaban el azul original fuera del ColorScheme.
    return base.copyWith(
      colorScheme: scheme,
      primaryColor: scheme.primary,
      dividerColor: scheme.outlineVariant,
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: primary,
        selectionColor: primary.withValues(alpha: 0.25),
        selectionHandleColor: primary,
      ),
      scaffoldBackgroundColor: scheme.surface,
      textTheme:
          base.textTheme.apply(bodyColor: foreground, displayColor: foreground),
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: scheme.surface,
        foregroundColor: foreground,
        titleTextStyle:
            base.appBarTheme.titleTextStyle?.copyWith(color: foreground),
      ),
      cardTheme: base.cardTheme.copyWith(color: panel),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: (base.elevatedButtonTheme.style ?? const ButtonStyle()).copyWith(
          backgroundColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.disabled)
                  ? foreground.withValues(alpha: 0.12)
                  : primary),
          foregroundColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.disabled)
                  ? foreground.withValues(alpha: 0.38)
                  : onPrimary),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        side: BorderSide(color: primary),
      )),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        fillColor: panel,
        labelStyle: TextStyle(color: foreground),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primary, width: 2),
        ),
      ),
    );
  }

  /// Escala tipográfica para superficies claras.
  ///
  /// Los estilos solicitan Poppins para títulos y Roboto para lectura continua.
  /// Como esas fuentes no se empaquetan actualmente en `pubspec.yaml`, Flutter
  /// utiliza la alternativa disponible en el sistema cuando no las encuentra.
  static TextTheme _buildTextTheme() {
    return const TextTheme(
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: darkGrey,
        fontFamily: 'Poppins',
      ),
      displayMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: darkGrey,
        fontFamily: 'Poppins',
      ),
      displaySmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: darkGrey,
        fontFamily: 'Poppins',
      ),
      headlineMedium: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: darkGrey,
        fontFamily: 'Poppins',
      ),
      headlineSmall: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: darkGrey,
        fontFamily: 'Poppins',
      ),
      titleLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: darkGrey,
        fontFamily: 'Poppins',
      ),
      titleMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: darkGrey,
        fontFamily: 'Poppins',
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: darkGrey,
        fontFamily: 'Roboto',
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: mediumGrey,
        fontFamily: 'Roboto',
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: mediumGrey,
        fontFamily: 'Roboto',
      ),
    );
  }

  /// Escala tipográfica para fondos oscuros con contraste accesible.
  static TextTheme _buildDarkTextTheme() {
    return const TextTheme(
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: whiteColor,
        fontFamily: 'Poppins',
      ),
      displayMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: whiteColor,
        fontFamily: 'Poppins',
      ),
      displaySmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: whiteColor,
        fontFamily: 'Poppins',
      ),
      headlineMedium: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: whiteColor,
        fontFamily: 'Poppins',
      ),
      headlineSmall: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: whiteColor,
        fontFamily: 'Poppins',
      ),
      titleLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: whiteColor,
        fontFamily: 'Poppins',
      ),
      titleMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: whiteColor,
        fontFamily: 'Poppins',
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: whiteColor,
        fontFamily: 'Roboto',
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: Color(0xFFD1D5DB),
        fontFamily: 'Roboto',
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: Color(0xFF9CA3AF),
        fontFamily: 'Roboto',
      ),
    );
  }

  // Escala de espaciado. Los widgets deben preferir estos pasos para conservar
  // un ritmo visual uniforme entre márgenes, separaciones y rellenos.
  static const double paddingXS = 4;
  static const double paddingSM = 8;
  static const double paddingMD = 16;
  static const double paddingLG = 24;
  static const double paddingXL = 32;

  // Escala de radios para controles, tarjetas y superficies contenedoras.
  static const double radiusXS = 4;
  static const double radiusSM = 8;
  static const double radiusMD = 12;
  static const double radiusLG = 16;

  // Niveles de elevación reutilizables. La opacidad y el desenfoque aumentan de
  // forma progresiva para representar la distancia de cada superficie.
  static final BoxShadow shadowSM = BoxShadow(
    color: Colors.black.withValues(alpha: 0.05),
    blurRadius: 2,
    offset: const Offset(0, 1),
  );

  static final BoxShadow shadowMD = BoxShadow(
    color: Colors.black.withValues(alpha: 0.1),
    blurRadius: 4,
    offset: const Offset(0, 2),
  );

  static final BoxShadow shadowLG = BoxShadow(
    color: Colors.black.withValues(alpha: 0.15),
    blurRadius: 8,
    offset: const Offset(0, 4),
  );
}
