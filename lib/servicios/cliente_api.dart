import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../configuracion.dart';
import 'almacen_sesion.dart';
import 'cancion.dart';
import 'letra.dart';
import 'selector_video.dart';

/// Pistas del Modo Karaoke y su nombre en el servicio de descarga.
const Map<String, String> pistasKaraoke = <String, String>{
  'instrumental': 'instrumental_comprimido',
  'voz': 'voz_comprimida',
};

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
  /// Crea el cliente; [cliente], [almacen], [url] y [carpetaPistas]
  /// permiten reemplazarlos en las pruebas.
  ClienteApi({
    http.Client? cliente,
    AlmacenSesion? almacen,
    String? url,
    Future<Directory> Function()? carpetaPistas,
  }) : _cliente = cliente ?? http.Client(),
       almacen = almacen ?? AlmacenSesion(),
       _url = url ?? urlApi,
       _carpetaPistas = carpetaPistas ?? getApplicationCacheDirectory;

  final http.Client _cliente;
  final String _url;
  final Future<Directory> Function() _carpetaPistas;

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
    final http.Response respuesta = await _conToken('GET', ruta);
    return jsonDecode(utf8.decode(respuesta.bodyBytes));
  }

  /// Canciones del usuario, de la más reciente a la más antigua.
  Future<List<Cancion>> listarCanciones() async {
    final List<dynamic> trabajos = await obtener('/jobs') as List<dynamic>;
    return <Cancion>[
      for (final dynamic trabajo in trabajos)
        Cancion.desdeJson(trabajo as Map<String, dynamic>),
    ];
  }

  /// Canción (trabajo) con su estado, posición en la cola y avance.
  Future<Cancion> obtenerTrabajo(String id) async => Cancion.desdeJson(
    await obtener('/jobs/${Uri.encodeComponent(id)}') as Map<String, dynamic>,
  );

  /// Letra sincronizada por palabra de la canción (Pb-10).
  Future<Letra> obtenerLetra(String id) async => Letra.desdeJson(
    await obtener('/jobs/${Uri.encodeComponent(id)}/letra')
        as Map<String, dynamic>,
  );

  /// Descarga una pista del Modo Karaoke (`instrumental` o `voz`) en audio
  /// comprimido y devuelve la ruta del archivo en el celular.
  ///
  /// Las pistas quedan en la caché de la aplicación: al volver a abrir la
  /// canción se reproducen sin descargarlas otra vez.
  Future<String> obtenerPista(String id, String pista) async {
    final String? tipo = pistasKaraoke[pista];
    if (tipo == null) throw ArgumentError.value(pista, 'pista');
    final Directory carpeta = Directory(
      '${(await _carpetaPistas()).path}/pistas',
    );
    final File archivo = File('${carpeta.path}/${id}_$pista.m4a');
    if (await archivo.exists() && await archivo.length() > 0) {
      return archivo.path;
    }
    final http.Response respuesta = await _conToken(
      'GET',
      '/descargar/$tipo/${Uri.encodeComponent(id)}',
    );
    await carpeta.create(recursive: true);
    // Se escribe aparte y se renombra: una descarga cortada no queda como
    // pista válida en la caché
    final File parcial = File('${archivo.path}.parcial');
    await parcial.writeAsBytes(respuesta.bodyBytes, flush: true);
    await parcial.rename(archivo.path);
    return archivo.path;
  }

  /// Sube el [video] para procesarlo y devuelve el id del trabajo en cola
  /// (Pb-9). [alProgreso] recibe la fracción enviada, de 0 a 1.
  ///
  /// El archivo se envía por partes, sin cargarlo entero en memoria.
  Future<String> subirVideo(
    VideoElegido video,
    String tipoVideo, {
    void Function(double avance)? alProgreso,
  }) async {
    // Un video grande tarda en subir: se parte de un token recién renovado
    if (!await renovarSesion()) {
      throw const ErrorApi(
        'Tu sesión venció. Vuelve a iniciar sesión.',
        sesionVencida: true,
      );
    }
    final String? acceso = await almacen.leerTokenAcceso();
    int enviados = 0;
    final Stream<List<int>> datos = video.archivo.openRead().map((
      List<int> parte,
    ) {
      enviados += parte.length;
      alProgreso?.call(
        video.bytes == 0 ? 1 : (enviados / video.bytes).clamp(0, 1),
      );
      return parte;
    });
    final http.MultipartRequest peticion =
        http.MultipartRequest('POST', uri('/procesar-video/'))
          ..headers['Authorization'] = 'Bearer $acceso'
          ..fields['video_type'] = tipoVideo
          ..files.add(
            http.MultipartFile(
              'file',
              datos,
              video.bytes,
              filename: video.nombre,
            ),
          );
    final http.Response respuesta;
    try {
      respuesta = await http.Response.fromStream(await _cliente.send(peticion));
    } on http.ClientException {
      throw const ErrorApi('No se pudo conectar con el servidor');
    }
    if (respuesta.statusCode == 400 || respuesta.statusCode == 413) {
      throw ErrorApi(_detalle(respuesta) ?? 'El archivo no es válido');
    }
    _comprobar(respuesta);
    final Map<String, dynamic> datosRespuesta =
        jsonDecode(respuesta.body) as Map<String, dynamic>;
    return datosRespuesta['job_id'] as String;
  }

  /// Registra el celular para recibir las notificaciones de finalización.
  Future<void> registrarDispositivo(String token) async {
    await _conToken(
      'POST',
      '/dispositivos',
      cuerpo: <String, String>{'token': token, 'platform': 'android'},
    );
  }

  /// Elimina el celular al cerrar sesión: deja de recibir notificaciones.
  Future<void> eliminarDispositivo(String token) async {
    await _conToken('DELETE', '/dispositivos/${Uri.encodeComponent(token)}');
  }

  /// Cierra la sesión y borra los tokens del dispositivo.
  Future<void> cerrarSesion() => almacen.borrar();

  /// Libera la conexión HTTP.
  void cerrar() => _cliente.close();

  /// Petición protegida a una [ruta]; si el token de acceso venció, lo
  /// renueva y repite la petición una vez.
  Future<http.Response> _conToken(
    String metodo,
    String ruta, {
    Object? cuerpo,
  }) async {
    http.Response respuesta = await _peticion(metodo, ruta, cuerpo);
    if (respuesta.statusCode == 401) {
      if (!await renovarSesion()) {
        throw const ErrorApi(
          'Tu sesión venció. Vuelve a iniciar sesión.',
          sesionVencida: true,
        );
      }
      respuesta = await _peticion(metodo, ruta, cuerpo);
    }
    _comprobar(respuesta);
    return respuesta;
  }

  Future<http.Response> _peticion(
    String metodo,
    String ruta,
    Object? cuerpo,
  ) async {
    final String? acceso = await almacen.leerTokenAcceso();
    final Map<String, String> cabeceras = <String, String>{
      'Authorization': 'Bearer $acceso',
      if (cuerpo != null) ..._json,
    };
    return _enviar(() async {
      final http.Request peticion = http.Request(metodo, uri(ruta))
        ..headers.addAll(cabeceras);
      if (cuerpo != null) peticion.body = jsonEncode(cuerpo);
      return http.Response.fromStream(await _cliente.send(peticion));
    });
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

  /// Mensaje del servidor (`detail`) para el usuario, si lo hay.
  String? _detalle(http.Response respuesta) {
    try {
      final Object? cuerpo = jsonDecode(utf8.decode(respuesta.bodyBytes));
      if (cuerpo is Map<String, dynamic> && cuerpo['detail'] is String) {
        return cuerpo['detail'] as String;
      }
    } on FormatException {
      return null;
    }
    return null;
  }

  void _comprobar(http.Response respuesta) {
    if (respuesta.statusCode >= 200 && respuesta.statusCode < 300) return;
    throw ErrorApi(
      _detalle(respuesta) ?? 'Error del servidor (${respuesta.statusCode})',
    );
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
