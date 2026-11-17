/// Configuración de la aplicación.
///
/// Los valores se leen del archivo `.env` del proyecto, que se empaqueta con
/// la aplicación y se carga al iniciarla (ver `.env.example`).
library;

import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Carga el archivo `.env`; se llama una vez al iniciar la aplicación.
Future<void> cargarConfiguracion() => dotenv.load();

String _valor(String nombre, String porDefecto) {
  final String? valor = dotenv.isInitialized ? dotenv.maybeGet(nombre) : null;
  return valor == null || valor.isEmpty ? porDefecto : valor;
}

/// URL base de la API REST (variable `API_URL`).
///
/// Por defecto apunta al servidor local visto desde el emulador de Android.
String get urlApi => _valor('API_URL', 'http://10.0.2.2:8000');

/// Dirección de la plataforma web, donde se registran las cuentas (variable
/// `WEB_URL`).
String get urlWeb => _valor('WEB_URL', 'http://localhost:5173');
