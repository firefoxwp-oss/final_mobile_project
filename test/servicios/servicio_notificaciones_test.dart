import 'dart:async';
import 'dart:convert';

import 'package:final_mobile_project/servicios/almacen_sesion.dart';
import 'package:final_mobile_project/servicios/cliente_api.dart';
import 'package:final_mobile_project/servicios/servicio_notificaciones.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Firebase simulado: entrega un token fijo y permite emitir eventos.
class _MensajeriaFalsa implements MensajeriaPush {
  _MensajeriaFalsa({this.falla = false, this.inicial});

  final String token = 'token-del-celular';
  final bool falla;
  final String? inicial;
  final StreamController<String> tocadas = StreamController<String>();
  final StreamController<String> renovados = StreamController<String>();
  final StreamController<NotificacionRecibida> mensajes =
      StreamController<NotificacionRecibida>();
  bool permisoPedido = false;
  bool tokenBorrado = false;

  @override
  Future<void> pedirPermiso() async => permisoPedido = true;

  @override
  Future<String?> obtenerToken() async {
    if (falla) throw Exception('sin Google Play Services');
    return token;
  }

  @override
  Stream<String> get tokensRenovados => renovados.stream;

  @override
  Stream<NotificacionRecibida> get notificacionesEnPrimerPlano =>
      mensajes.stream;

  @override
  Future<void> borrarToken() async => tokenBorrado = true;

  @override
  Stream<String> get cancionesTocadas => tocadas.stream;

  @override
  Future<String?> cancionAlAbrir() async => inicial;
}

class _MostradorFalso implements MostradorNotificaciones {
  final List<String> mostradas = <String>[];
  final StreamController<String> tocadas = StreamController<String>();

  @override
  Future<void> preparar() async {}

  @override
  Future<void> mostrar(
    int id,
    String titulo,
    String texto, {
    String? cancion,
  }) async => mostradas.add('$titulo|$texto|$cancion');

  @override
  Stream<String> get cancionesTocadas => tocadas.stream;

  @override
  Future<String?> cancionAlAbrir() async => null;
}

/// Servidor simulado que registra las peticiones de /dispositivos.
class _Servidor {
  final List<String> peticiones = <String>[];

  ClienteApi cliente() => ClienteApi(
    cliente: MockClient((http.Request p) async {
      final String cuerpo = p.body.isEmpty
          ? ''
          : (jsonDecode(p.body) as Map<String, dynamic>)['token'] as String;
      peticiones.add('${p.method} ${Uri.decodeComponent(p.url.path)} $cuerpo');
      return http.Response('{}', p.method == 'POST' ? 201 : 204);
    }),
    almacen: AlmacenSesion(),
    url: 'https://api.prueba',
  );
}

void main() {
  setUp(
    () => FlutterSecureStorage.setMockInitialValues(<String, String>{
      'token_acceso': 'acceso',
      'token_renovacion': 'renovacion',
    }),
  );

  test('al iniciar sesión registra el celular en el servidor', () async {
    final _Servidor servidor = _Servidor();
    final _MensajeriaFalsa fcm = _MensajeriaFalsa();
    final ServicioNotificaciones servicio = ServicioNotificaciones(
      cliente: servidor.cliente(),
      mensajeria: fcm,
      mostrador: _MostradorFalso(),
    );

    await servicio.iniciarSesion();

    expect(fcm.permisoPedido, isTrue);
    expect(servidor.peticiones, <String>[
      'POST /dispositivos token-del-celular',
    ]);
  });

  test('un token renovado se vuelve a registrar', () async {
    final _Servidor servidor = _Servidor();
    final _MensajeriaFalsa fcm = _MensajeriaFalsa();
    final ServicioNotificaciones servicio = ServicioNotificaciones(
      cliente: servidor.cliente(),
      mensajeria: fcm,
      mostrador: _MostradorFalso(),
    );
    await servicio.iniciarSesion();

    fcm.renovados.add('token-nuevo');
    await pumpEventQueue();

    expect(servidor.peticiones.last, 'POST /dispositivos token-nuevo');
  });

  test('con la app abierta muestra la notificación recibida', () async {
    final _MensajeriaFalsa fcm = _MensajeriaFalsa();
    final _MostradorFalso mostrador = _MostradorFalso();
    await ServicioNotificaciones(
      cliente: _Servidor().cliente(),
      mensajeria: fcm,
      mostrador: mostrador,
    ).iniciarSesion();

    fcm.mensajes.add(
      const NotificacionRecibida(
        titulo: 'Tu canción está lista',
        texto: 'mi_cancion.mp4 ya se puede cantar',
        datos: <String, String>{'job_id': 'abc', 'status': 'done'},
      ),
    );
    await pumpEventQueue();

    expect(mostrador.mostradas, <String>[
      'Tu canción está lista|mi_cancion.mp4 ya se puede cantar|abc',
    ]);
  });

  test('al cerrar sesión elimina el celular del servidor', () async {
    final _Servidor servidor = _Servidor();
    final _MensajeriaFalsa fcm = _MensajeriaFalsa();
    final ServicioNotificaciones servicio = ServicioNotificaciones(
      cliente: servidor.cliente(),
      mensajeria: fcm,
      mostrador: _MostradorFalso(),
    );
    await servicio.iniciarSesion();

    await servicio.cerrarSesion();

    expect(servidor.peticiones.last, 'DELETE /dispositivos/token-del-celular ');
    expect(fcm.tokenBorrado, isTrue);
  });

  test('si Firebase no está disponible la sesión sigue funcionando', () async {
    final _Servidor servidor = _Servidor();
    final ServicioNotificaciones servicio = ServicioNotificaciones(
      cliente: servidor.cliente(),
      mensajeria: _MensajeriaFalsa(falla: true),
      mostrador: _MostradorFalso(),
    );

    await servicio.iniciarSesion();
    await servicio.cerrarSesion();

    expect(servidor.peticiones, isEmpty);
  });

  test('al tocar una notificación se abre su canción', () async {
    final _MensajeriaFalsa fcm = _MensajeriaFalsa(inicial: 'cerrada');
    final _MostradorFalso mostrador = _MostradorFalso();
    final ServicioNotificaciones servicio = ServicioNotificaciones(
      cliente: _Servidor().cliente(),
      mensajeria: fcm,
      mostrador: mostrador,
    );
    final List<String> abiertas = <String>[];

    await servicio.alTocarNotificacion(abiertas.add);
    fcm.tocadas.add('segundo-plano');
    mostrador.tocadas.add('abierta');
    await pumpEventQueue();
    servicio.quitarAlTocar(abiertas.add);
    mostrador.tocadas.add('ignorada');
    await pumpEventQueue();

    expect(abiertas, <String>['cerrada', 'segundo-plano', 'abierta']);
  });
}
