import 'dart:async';

import 'package:flutter/foundation.dart';

import 'cliente_api.dart';

/// Notificación recibida de Firebase Cloud Messaging.
class NotificacionRecibida {
  /// Crea la notificación con su [titulo], [texto] y [datos].
  const NotificacionRecibida({
    required this.titulo,
    required this.texto,
    this.datos = const <String, String>{},
  });

  /// Título visible.
  final String titulo;

  /// Texto visible.
  final String texto;

  /// Datos del trabajo (`job_id` y `status`).
  final Map<String, String> datos;
}

/// Mensajería push del celular (Firebase Cloud Messaging).
abstract interface class MensajeriaPush {
  /// Pide permiso para mostrar notificaciones (Android 13 o superior).
  Future<void> pedirPermiso();

  /// Token que identifica al celular en Firebase.
  Future<String?> obtenerToken();

  /// Tokens nuevos cuando Firebase renueva el del celular.
  Stream<String> get tokensRenovados;

  /// Notificaciones que llegan con la aplicación abierta.
  Stream<NotificacionRecibida> get notificacionesEnPrimerPlano;

  /// Borra el token del celular en Firebase.
  Future<void> borrarToken();

  /// Canciones (`job_id`) de las notificaciones que el usuario toca con la
  /// aplicación en segundo plano.
  Stream<String> get cancionesTocadas;

  /// Canción de la notificación que abrió la aplicación cerrada, si la hay.
  Future<String?> cancionAlAbrir();
}

/// Muestra notificaciones en la barra del sistema.
abstract interface class MostradorNotificaciones {
  /// Crea el canal de notificaciones de los procesamientos.
  Future<void> preparar();

  /// Muestra una notificación con su [titulo] y [texto]; al tocarla se
  /// abre la [cancion].
  Future<void> mostrar(int id, String titulo, String texto, {String? cancion});

  /// Canciones de las notificaciones mostradas que el usuario toca.
  Stream<String> get cancionesTocadas;

  /// Canción de la notificación mostrada que abrió la aplicación, si la hay.
  Future<String?> cancionAlAbrir();
}

/// Sin notificaciones push, para iOS: Firebase Cloud Messaging en iOS exige
/// la cuenta de pago de Apple Developer. El estado de cada canción sigue
/// disponible en «Mis canciones» (RF-09).
class SinNotificaciones implements MensajeriaPush, MostradorNotificaciones {
  /// Crea el servicio vacío.
  const SinNotificaciones();

  @override
  Future<void> pedirPermiso() async {}

  @override
  Future<String?> obtenerToken() async => null;

  @override
  Stream<String> get tokensRenovados => const Stream<String>.empty();

  @override
  Stream<NotificacionRecibida> get notificacionesEnPrimerPlano =>
      const Stream<NotificacionRecibida>.empty();

  @override
  Future<void> borrarToken() async {}

  @override
  Future<void> preparar() async {}

  @override
  Future<void> mostrar(
    int id,
    String titulo,
    String texto, {
    String? cancion,
  }) async {}

  @override
  Stream<String> get cancionesTocadas => const Stream<String>.empty();

  @override
  Future<String?> cancionAlAbrir() async => null;
}

/// Notificaciones de finalización del procesamiento (Pb-4).
///
/// Al iniciar sesión registra el celular en el servidor; al cerrarla lo
/// elimina. Con la aplicación cerrada, Android muestra la notificación; con la
/// aplicación abierta, la muestra este servicio. Un fallo aquí nunca impide
/// usar la aplicación: el estado sigue disponible en «Mis canciones».
class ServicioNotificaciones {
  /// Crea el servicio sobre el [cliente] de la API.
  ServicioNotificaciones({
    required this.cliente,
    required this.mensajeria,
    required this.mostrador,
  });

  /// Cliente de la API para registrar y eliminar el celular.
  final ClienteApi cliente;

  /// Mensajería push del celular.
  final MensajeriaPush mensajeria;

  /// Barra de notificaciones del sistema.
  final MostradorNotificaciones mostrador;

  String? _token;
  final List<StreamSubscription<Object>> _suscripciones =
      <StreamSubscription<Object>>[];
  final List<StreamSubscription<String>> _toques =
      <StreamSubscription<String>>[];
  void Function(String cancion)? _alTocar;

  /// Registra el celular para recibir notificaciones del usuario.
  Future<void> iniciarSesion() async {
    try {
      await _cancelarSuscripciones();
      await mostrador.preparar();
      // El celular se registra antes de pedir el permiso: el registro no debe
      // esperar a que el usuario responda el diálogo de Android.
      _token = await mensajeria.obtenerToken();
      if (_token != null) await cliente.registrarDispositivo(_token!);
      _suscripciones
        ..add(mensajeria.tokensRenovados.listen(_registrarToken))
        ..add(
          mensajeria.notificacionesEnPrimerPlano.listen(
            (NotificacionRecibida n) =>
                unawaited(mostrarNotificacion(n.titulo, n.texto, n.datos)),
          ),
        );
    } on Object catch (e) {
      // Sin Firebase o sin conexión la aplicación sigue funcionando (RF-09)
      _token = null;
      _registrarError('registrar el celular', e);
      return;
    }
    try {
      await mensajeria.pedirPermiso();
    } on Object catch (e) {
      _registrarError('pedir el permiso de notificaciones', e);
    }
  }

  /// Muestra la notificación de una canción terminada o con error.
  Future<void> mostrarNotificacion(
    String titulo,
    String texto, [
    Map<String, String> datos = const <String, String>{},
  ]) async {
    final int id = (datos['job_id'] ?? titulo).hashCode & 0x7fffffff;
    await mostrador.mostrar(id, titulo, texto, cancion: datos['job_id']);
  }

  /// Al tocar una notificación se llama a [abrir] con su canción, con la
  /// aplicación abierta, en segundo plano o cerrada (Pb-9).
  Future<void> alTocarNotificacion(void Function(String cancion) abrir) async {
    _alTocar = abrir;
    if (_toques.isNotEmpty) return;
    try {
      await mostrador.preparar();
      _toques
        ..add(mensajeria.cancionesTocadas.listen(_abrirCancion))
        ..add(mostrador.cancionesTocadas.listen(_abrirCancion));
      final String? inicial =
          await mensajeria.cancionAlAbrir() ?? await mostrador.cancionAlAbrir();
      if (inicial != null) _abrirCancion(inicial);
    } on Object catch (e) {
      _registrarError('escuchar las notificaciones tocadas', e);
    }
  }

  /// Deja de abrir canciones con [abrir], p. ej. al salir de la pantalla.
  void quitarAlTocar(void Function(String cancion) abrir) {
    if (_alTocar == abrir) _alTocar = null;
  }

  void _abrirCancion(String cancion) => _alTocar?.call(cancion);

  /// Elimina el celular: después de cerrar sesión ya no recibe
  /// notificaciones.
  Future<void> cerrarSesion() async {
    await _cancelarSuscripciones();
    final String? token = _token;
    _token = null;
    try {
      if (token != null) await cliente.eliminarDispositivo(token);
      await mensajeria.borrarToken();
    } on Object catch (e) {
      _registrarError('eliminar el celular', e);
    }
  }

  Future<void> _registrarToken(String token) async {
    _token = token;
    try {
      await cliente.registrarDispositivo(token);
    } on Object catch (e) {
      _registrarError('registrar el token renovado', e);
    }
  }

  Future<void> _cancelarSuscripciones() async {
    for (final StreamSubscription<Object> s in _suscripciones) {
      await s.cancel();
    }
    _suscripciones.clear();
  }

  void _registrarError(String accion, Object error) {
    debugPrint('[notificaciones] no se pudo $accion: $error');
  }
}
