import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Guarda los tokens de la sesión cifrados en el dispositivo.
class AlmacenSesion {
  /// Crea el almacén; [almacen] permite reemplazarlo en las pruebas.
  AlmacenSesion({FlutterSecureStorage? almacen})
    : _almacen = almacen ?? const FlutterSecureStorage();

  final FlutterSecureStorage _almacen;

  static const String _claveAcceso = 'token_acceso';
  static const String _claveRenovacion = 'token_renovacion';

  /// Guarda el token de acceso y el de renovación.
  Future<void> guardarTokens({
    required String acceso,
    required String renovacion,
  }) async {
    await _almacen.write(key: _claveAcceso, value: acceso);
    await _almacen.write(key: _claveRenovacion, value: renovacion);
  }

  /// Token de acceso guardado, o `null` si no hay sesión.
  Future<String?> leerTokenAcceso() => _almacen.read(key: _claveAcceso);

  /// Token de renovación guardado, o `null` si no hay sesión.
  Future<String?> leerTokenRenovacion() => _almacen.read(key: _claveRenovacion);

  /// Borra los tokens al cerrar sesión.
  Future<void> borrar() async {
    await _almacen.delete(key: _claveAcceso);
    await _almacen.delete(key: _claveRenovacion);
  }
}
