import 'dart:convert';

import 'package:final_mobile_project/app.dart';
import 'package:final_mobile_project/servicios/almacen_sesion.dart';
import 'package:final_mobile_project/servicios/cliente_api.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

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
      '/refresh' => http.Response(_tokens, estadoRefresh),
      _ => http.Response(_tokens, 200),
    };
  }),
);

Future<void> _abrirApp(WidgetTester tester, ClienteApi cliente) async {
  await AlmacenSesion().guardarTokens(acceso: 'a', renovacion: 'r');
  await tester.pumpWidget(KaraokeApp(cliente: cliente));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues(<String, String>{}));

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
      find.text('Todavía no tienes canciones. Súbelas desde la web.'),
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
}
