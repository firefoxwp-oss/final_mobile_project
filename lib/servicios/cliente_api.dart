import 'package:http/http.dart' as http;

import '../configuracion.dart';
import 'almacen_sesion.dart';

/// Cliente de la API REST del servidor, la misma que usa la web.
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

  /// Dirección completa de una [ruta] de la API.
  Uri uri(String ruta) => Uri.parse('$_url$ruta');

  /// Libera la conexión HTTP.
  void cerrar() => _cliente.close();
}
