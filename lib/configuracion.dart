/// Configuración de la aplicación.
library;

/// URL base de la API REST.
///
/// Se define al compilar con `--dart-define=API_URL=https://...`. Por
/// defecto apunta al servidor local visto desde el emulador de Android.
const String urlApi = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://10.0.2.2:8000',
);

/// Dirección de la plataforma web, donde se registran las cuentas.
///
/// Se define al compilar con `--dart-define=WEB_URL=https://...`.
const String urlWeb = String.fromEnvironment(
  'WEB_URL',
  defaultValue: 'http://localhost:5173',
);
