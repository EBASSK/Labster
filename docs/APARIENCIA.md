# Paletas de CUAC

En **Ajustes → Apariencia → Paleta de colores** se puede elegir:

| Paleta | Colores de la referencia |
|---|---|
| Bruma invernal | `#313C45`, `#4F6271`, `#778CA4`, `#B3BFCB`, `#D5DBE2` |
| Océano profundo | `#01162B`, `#00385A`, `#6A90B4`, `#94A2BF`, `#D2DBEB` |

CUAC original sigue disponible. La paleta y el modo Sistema/Claro/Oscuro son
preferencias independientes: ambas se leen antes del primer frame. La selección
de paleta actualiza MaterialApp sin recrear GoRouter ni perder la pantalla abierta.
La hoja admite desplazamiento para pantallas pequeñas y texto grande.

## Responsabilidades documentadas en el código

- `lib/config/app_palette.dart`: identificadores persistentes y colores exactos.
- `lib/config/theme.dart`: asignación de colores a roles Material, contraste de
  texto/botones y adaptación de superficies para cada luminosidad.
- `lib/services/palette_preferences_service.dart`: archivo privado de selección;
  una lectura inválida vuelve a CUAC original y un fallo de escritura se propaga.
- `lib/providers/palette_provider.dart`: estado observable, escrituras en orden y
  restauración de la paleta previa ante un fallo.
- `lib/main.dart`: recuperación al iniciar y aplicación global de ambos temas.
- `lib/screens/settings_screen.dart`: acceso al selector y resumen de preferencias.
- `lib/widgets/palette_options.dart`: muestras de los cinco colores, selección
  accesible con radio, bloqueo mientras se guarda y mensaje ante errores.
- `test/palette_test.dart`: persistencia entre sesiones, recuperación ante fallo,
  contraste mínimo 4,5:1 en pares principales y navegación sin reinicios.

Las superficies secundarias mezclan tonos de la paleta para distinguir tarjetas
y paneles. Los colores de éxito/error conservan su función. Cámara y Splash
mantienen el fondo negro previsto por su diseño; los temas se aplican a las
pantallas que consumen el esquema global (Ajustes, Historial, Resultados y Detalle).

## Verificación

```powershell
flutter test --no-pub
dart analyze lib test
```

En un teléfono: seleccionar ambas paletas, alternar luminosidad, reiniciar la app
y comprobar que se conservan las preferencias. Revisar también Historial,
Resultados y Detalle, incluyendo campos de texto y botones.

Resultado de esta revisión: 28 pruebas de la suite aprobadas, análisis Dart sin
incidencias y cuatro vistas de prueba de 390 × 844 revisadas (ambas paletas en
claro/oscuro). Las vistas de widgets no sustituyen la revisión en un teléfono.
