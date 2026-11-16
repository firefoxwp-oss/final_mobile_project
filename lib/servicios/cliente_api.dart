import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../configuracion.dart';
import 'almacen_sesion.dart';

/// Error de la API con un mensaje comprensible para el usuario.
class ErrorApi implements Exception {
  /// Crea el error con el [mensaje] que se muestra al usuario.
  const ErrorApi(this.mensaje, {this.sesionVencida = false});

  /// Mensaje para el usuario.
  final String mensaje;

  /// Indica que hay que volver a iniciar sesión.
  final bool sesionVencida;

  @override
  String toString() => mensaje;
}

/// Cliente de la API REST del servidor, la misma que usa la web.
///
/// Autentica con tokens JWT: el de acceso acompaña cada petición y el de
/// renovación permite obtener uno nuevo sin pedir otra vez la contraseña.
class ClienteApi {
  /// Crea el cliente; [cliente], [almacen] y [url] permiten reemplazarlos en
  /// las pruebas.
  ClienteApi({http.Client? cliente, AlmacenSesion? almacen, String? url})
    : _cliente = cliente ?? http.Client(),
      almacen = almacen ?? AlmacenSesion(),
      _url = url ?? urlApi;

  final http.Client _cliente;
  final String _url;

  /// Almacén de los tokens de la sesión.
  final AlmacenSesion almacen;

  static const Duration _espera = Duration(seconds: 20);
  static const Map<String, String> _json = <String, String>{
    'Content-Type': 'application/json',
  };

  /// Dirección completa de una [ruta] de la API.
  Uri uri(String ruta) => Uri.parse('$_url$ruta');

  /// Inicia sesión con la cuenta del sistema y guarda los tokens.
  Future<void> iniciarSesion(String correo, String clave) async {
    final http.Response respuesta = await _enviar(
      () => _cliente.post(
        uri('/login'),
        headers: _json,
        body: jsonEncode(<String, String>{
          'email': correo.trim(),
          'password': clave,
        }),
      ),
    );
    if (respuesta.statusCode == 401) {
      throw const ErrorApi('Correo o contraseña incorrectos');
    }
    if (respuesta.statusCode == 422) {
      throw const ErrorApi('Revisa el formato del correo electrónico');
    }
    _comprobar(respuesta);
    await _guardarTokens(respuesta);
  }

  /// Indica si hay una sesión activa al abrir la aplicación.
  ///
  /// La sesión sigue activa mientras el token de renovación sea válido. Sin
  /// conexión se conserva, y se valida en la siguiente petición.
  Future<bool> haySesion() async {
    if (await almacen.leerTokenRenovacion() == null) return false;
    try {
      return await renovarSesion();
    } on ErrorApi catch (e) {
      return !e.sesionVencida;
    }
  }

  /// Obtiene un token de acceso nuevo. Devuelve `false` si la sesión venció.
  Future<bool> renovarSesion() async {
    final String? renovacion = await almacen.leerTokenRenovacion();
    if (renovacion == null) return false;
    final http.Response respuesta = await _enviar(
      () => _cliente.post(
        uri('/refresh'),
        headers: _json,
        body: jsonEncode(<String, String>{'refresh_token': renovacion}),
      ),
    );
    if (respuesta.statusCode == 401) {
      await almacen.borrar();
      return false;
    }
    _comprobar(respuesta);
    await _guardarTokens(respuesta);
    return true;
  }

  /// Consulta una [ruta] protegida y devuelve el cuerpo JSON.
  ///
  /// Si el token de acceso venció, lo renueva y repite la petición una vez.
  Future<Object?> obtener(String ruta) async {
    http.Response respuesta = await _obtenerConToken(ruta);
    if (respuesta.statusCode == 401) {
      if (!await renovarSesion()) {
        throw const ErrorApi(
          'Tu sesión venció. Vuelve a iniciar sesión.',
          sesionVencida: true,
        );
      }
      respuesta = await _obtenerConToken(ruta);
    }
    _comprobar(respuesta);
    return jsonDecode(utf8.decode(respuesta.bodyBytes));
  }

  /// Cierra la sesión y borra los tokens del dispositivo.
  Future<void> cerrarSesion() => almacen.borrar();

  /// Libera la conexión HTTP.
  void cerrar() => _cliente.close();

  Future<http.Response> _obtenerConToken(String ruta) async {
    final String? acceso = await almacen.leerTokenAcceso();
    return _enviar(
      () => _cliente.get(
        uri(ruta),
        headers: <String, String>{'Authorization': 'Bearer $acceso'},
      ),
    );
  }

  Future<http.Response> _enviar(
    Future<http.Response> Function() peticion,
  ) async {
    try {
      return await peticion().timeout(_espera);
    } on TimeoutException {
      throw const ErrorApi('El servidor no respondió a tiempo');
    } on http.ClientException {
      throw const ErrorApi('No se pudo conectar con el servidor');
    }
  }

  void _comprobar(http.Response respuesta) {
    if (respuesta.statusCode >= 200 && respuesta.statusCode < 300) return;
    throw ErrorApi('Error del servidor (${respuesta.statusCode})');
  }

  Future<void> _guardarTokens(http.Response respuesta) async {
    final Map<String, dynamic> datos =
        jsonDecode(respuesta.body) as Map<String, dynamic>;
    await almacen.guardarTokens(
      acceso: datos['access_token'] as String,
      renovacion: datos['refresh_token'] as String,
    );
  }
}
