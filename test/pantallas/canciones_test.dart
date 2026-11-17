import 'dart:async';
import 'dart:convert';

import 'package:final_mobile_project/app.dart';
import 'package:final_mobile_project/pantallas/pantalla_detalle_cancion.dart';
import 'package:final_mobile_project/pantallas/pantalla_karaoke.dart';
import 'package:final_mobile_project/servicios/almacen_sesion.dart';
import 'package:final_mobile_project/servicios/cliente_api.dart';
import 'package:final_mobile_project/servicios/servicio_notificaciones.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _tokens =
    '{"access_token":"a","refresh_token":"r","token_type":"bearer"}';

Map<String, dynamic> _trabajo(String id, String estado, String archivo) =>
    <String, dynamic>{
      'id': id,
      'source_filename': archivo,
      'status': estado,
      'progress': estado == 'done' ? 100 : 45,
      'queue_position': estado == 'queued' ? 2 : null,
      'duration_seconds': 225,
      'video_type': 'karaoke',
      'separation_model': estado == 'done' ? 'demucs' : null,
    };

/// Servidor simulado: [trabajos] devuelve la lista de cada consulta.
ClienteApi _cliente(
  List<Map<String, dynamic>> Function() trabajos, {
  int estadoJobs = 200,
  int estadoRefresh = 200,
}) => ClienteApi(
  url: 'https://api.prueba',
  cliente: MockClient((http.Request peticion) async {
    return switch (peticion.url.path) {
      '/jobs' => http.Response.bytes(
        utf8.encode(jsonEncode(trabajos())),
        estadoJobs,
      ),
      '/jobs/1' => http.Response.bytes(
        utf8.encode(jsonEncode(_trabajo('1', 'done', 'Terminada.mp4'))),
        200,
      ),
      '/refresh' => http.Response(_tokens, estadoRefresh),
      _ => http.Response(_tokens, 200),
    };
  }),
);

/// Firebase simulado: el usuario toca la notificación con [tocadas].
class _MensajeriaFalsa implements MensajeriaPush {
  final StreamController<String> tocadas = StreamController<String>();

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
  Stream<String> get cancionesTocadas => tocadas.stream;

  @override
  Future<String?> cancionAlAbrir() async => null;
}

class _MostradorFalso implements MostradorNotificaciones {
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

Future<void> _abrirApp(
  WidgetTester tester,
  ClienteApi cliente, {
  ServicioNotificaciones? notificaciones,
}) async {
  await AlmacenSesion().guardarTokens(acceso: 'a', renovacion: 'r');
  await tester.pumpWidget(
    KaraokeApp(cliente: cliente, notificaciones: notificaciones),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  final List<Map<String, dynamic>> tresCanciones = <Map<String, dynamic>>[
    _trabajo('3', 'queued', 'En espera.mp4'),
    _trabajo('2', 'running', 'Procesando.mp4'),
    _trabajo('1', 'done', 'Terminada.mp4'),
  ];

  testWidgets('lista las canciones del usuario con su estado', (tester) async {
    await _abrirApp(tester, _cliente(() => tresCanciones));

    expect(find.text('En espera'), findsOneWidget);
    expect(find.text('En cola · posición 2'), findsOneWidget);
    expect(find.text('Procesando · 45 %'), findsOneWidget);
    expect(find.text('Terminada · 3:45'), findsOneWidget);
    expect(
      find.text('Solo las canciones terminadas se pueden abrir'),
      findsOneWidget,
    );
  });

  testWidgets('al tocar una canción terminada se abre su detalle', (
    tester,
  ) async {
    await _abrirApp(tester, _cliente(() => tresCanciones));

    await tester.tap(find.text('Terminada'));
    await tester.pumpAndSettle();

    expect(find.text('Separación de la voz'), findsOneWidget);
    expect(find.text('Demucs v4'), findsOneWidget);
    expect(find.text('Karaoke'), findsOneWidget);
  });

  testWidgets('desde el detalle se abre el Modo Karaoke', (tester) async {
    await _abrirApp(tester, _cliente(() => tresCanciones));
    await tester.tap(find.text('Terminada'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('botonCantar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('botonCantar')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(PantallaKaraoke), findsOneWidget);
    expect(find.text('Modo Karaoke'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('una canción solo instrumental no tiene Modo Karaoke', (
    tester,
  ) async {
    final Map<String, dynamic> instrumental = _trabajo(
      '1',
      'done',
      'Terminada.mp4',
    )..['video_type'] = 'instrumental';
    await _abrirApp(
      tester,
      _cliente(() => <Map<String, dynamic>>[instrumental]),
    );
    await tester.tap(find.text('Terminada'));
    await tester.pumpAndSettle();

    expect(find.text('Instrumental'), findsOneWidget);
    expect(find.byKey(const Key('botonCantar')), findsNothing);
  });

  testWidgets('las canciones no terminadas no se abren', (tester) async {
    await _abrirApp(tester, _cliente(() => tresCanciones));

    await tester.tap(find.text('En espera'));
    await tester.tap(find.text('Procesando'));
    await tester.pumpAndSettle();

    expect(find.text('Separación de la voz'), findsNothing);
    expect(find.text('Mis canciones'), findsOneWidget);
  });

  testWidgets('la lista se actualiza al deslizarla hacia abajo', (
    tester,
  ) async {
    List<Map<String, dynamic>> actuales = <Map<String, dynamic>>[
      _trabajo('2', 'running', 'Procesando.mp4'),
    ];
    await _abrirApp(tester, _cliente(() => actuales));
    expect(find.text('Procesando · 45 %'), findsOneWidget);

    actuales = <Map<String, dynamic>>[_trabajo('2', 'done', 'Procesando.mp4')];
    await tester.fling(find.text('Procesando'), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(find.text('Terminada · 3:45'), findsOneWidget);
  });

  testWidgets('muestra un mensaje si no hay canciones', (tester) async {
    await _abrirApp(tester, _cliente(() => <Map<String, dynamic>>[]));

    expect(
      find.text(
        'Todavía no tienes canciones. Sube una con el botón «Subir canción».',
      ),
      findsOneWidget,
    );
  });

  testWidgets('muestra un mensaje si el servidor falla', (tester) async {
    await _abrirApp(
      tester,
      _cliente(() => <Map<String, dynamic>>[], estadoJobs: 500),
    );

    expect(find.text('Error del servidor (500)'), findsOneWidget);
  });

  testWidgets('si la sesión vence vuelve al inicio de sesión', (tester) async {
    await _abrirApp(
      tester,
      _cliente(
        () => <Map<String, dynamic>>[],
        estadoJobs: 401,
        estadoRefresh: 401,
      ),
    );

    expect(find.text('Iniciar sesión'), findsOneWidget);
  });

  testWidgets('al tocar la notificación se abre la canción terminada', (
    tester,
  ) async {
    final ClienteApi cliente = _cliente(() => tresCanciones);
    final _MensajeriaFalsa fcm = _MensajeriaFalsa();
    await _abrirApp(
      tester,
      cliente,
      notificaciones: ServicioNotificaciones(
        cliente: cliente,
        mensajeria: fcm,
        mostrador: _MostradorFalso(),
      ),
    );

    fcm.tocadas.add('1');
    await tester.pumpAndSettle();

    expect(find.byType(PantallaDetalleCancion), findsOneWidget);
    expect(find.text('Demucs v4'), findsOneWidget);
  });
}
