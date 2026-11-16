/// Configuración de la aplicación.
///
/// Los valores se leen del archivo `.env` al ejecutar o compilar con
/// `--dart-define-from-file=.env` (ver `.env.example`).
library;

/// URL base de la API REST.
///
/// Variable `API_URL`. Por defecto apunta al servidor local visto desde el
/// emulador de Android.
const String urlApi = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://10.0.2.2:8000',
);

/// Dirección de la plataforma web, donde se registran las cuentas.
///
/// Variable `WEB_URL`.
const String urlWeb = String.fromEnvironment(
  'WEB_URL',
  defaultValue: 'http://localhost:5173',
);
