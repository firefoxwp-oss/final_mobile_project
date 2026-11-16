import 'dart:convert';
import 'dart:io';

import 'package:final_mobile_project/pantallas/pantalla_karaoke.dart';
import 'package:final_mobile_project/servicios/almacen_sesion.dart';
import 'package:final_mobile_project/servicios/cancion.dart';
import 'package:final_mobile_project/servicios/cliente_api.dart';
import 'package:final_mobile_project/servicios/reproductor_pistas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

final Cancion _cancion = Cancion.desdeJson(<String, dynamic>{
  'id': 'abc',
  'source_filename': 'mi_cancion.mp4',
  'status': 'done',
  'progress': 100,
  'duration_seconds': 225,
  'video_type': 'karaoke',
});

const Map<String, Object> _letra = <String, Object>{
  'lineas': <Object>[
    <String, Object>{
      'inicio': 1.0,
      'fin': 3.0,
      'palabras': <Object>[
        <String, Object>{'texto': 'y', 'inicio': 1.0, 'fin': 1.2},
        <String, Object>{'texto': 'la', 'inicio': 1.3, 'fin': 1.5},
        <String, Object>{'texto': 'noche', 'inicio': 1.6, 'fin': 2.8},
      ],
    },
    <String, Object>{
      'inicio': 4.0,
      'fin': 7.0,
      'palabras': <Object>[
        <String, Object>{'texto': 'cantando', 'inicio': 4.0, 'fin': 4.6},
        <String, Object>{'texto': 'bajo', 'inicio': 4.7, 'fin': 5.1},
        <String, Object>{'texto': 'la', 'inicio': 5.2, 'fin': 5.4},
        <String, Object>{'texto': 'luz', 'inicio': 5.5, 'fin': 7.0},
      ],
    },
    <String, Object>{
      'inicio': 8.0,
      'fin': 10.0,
      'palabras': <Object>[
        <String, Object>{'texto': 'hasta', 'inicio': 8.0, 'fin': 10.0},
      ],
    },
  ],
};

/// Pista simulada: la prueba fija su posición.
class _PistaFalsa implements PistaAudio {
  @override
  Duration posicion = Duration.zero;
  double nivel = 1;
  bool sonando = false;

  @override
  Future<Duration?> cargar(String ruta) async => const Duration(seconds: 12);

  @override
  Future<void> reproducir() async => sonando = true;

  @override
  Future<void> pausar() async => sonando = false;

  @override
  Future<void> buscar(Duration destino) async => posicion = destino;

  @override
  Future<void> lista() async {}

  @override
  Future<void> volumen(double valor) async => nivel = valor;

  @override
  Future<void> velocidad(double factor) async {}

  @override
  Future<void> liberar() async {}
}

void main() {
  late Directory cache;
  late _PistaFalsa instrumental;
  late _PistaFalsa voz;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{
      'token_acceso': 'acceso',
      'token_renovacion': 'renovacion',
    });
    SharedPreferences.setMockInitialValues(<String, Object>{});
    cache = await Directory.systemTemp.createTemp('karaoke');
    instrumental = _PistaFalsa();
    voz = _PistaFalsa();
  });

  tearDown(() => cache.delete(recursive: true));

  Future<void> abrir(WidgetTester tester, {int estadoLetra = 200}) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ClienteApi cliente = ClienteApi(
      url: 'https://api.prueba',
      almacen: AlmacenSesion(),
      carpetaPistas: () async => cache,
      cliente: MockClient((http.Request p) async {
        if (p.url.path.endsWith('/letra')) {
          return estadoLetra == 200
              ? http.Response(jsonEncode(_letra), 200)
              : http.Response.bytes(
                  utf8.encode(
                    jsonEncode(<String, String>{
                      'detail': 'La canción no tiene letra',
                    }),
                  ),
                  estadoLetra,
                );
        }
        return http.Response.bytes(<int>[1, 2, 3], 200);
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PantallaKaraoke(
          cliente: cliente,
          cancion: _cancion,
          crearReproductor: () =>
              ReproductorPistas(<PistaAudio>[instrumental, voz]),
        ),
      ),
    );
    // Espera a que termine la carga de la letra y las pistas
    for (int i = 0; i < 30; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
    }
  }

  RichText linea(WidgetTester tester) => tester.widget<RichText>(
    find.descendant(
      of: find.byKey(const Key('lineaActual')),
      matching: find.byType(RichText),
    ),
  );

  String cantado(WidgetTester tester) {
    String texto = '';
    linea(tester).text.visitChildren((InlineSpan parte) {
      if (parte is TextSpan && parte.style?.color == PanelLetra.colorCantado) {
        texto = parte.text ?? '';
      }
      return true;
    });
    return texto;
  }

  testWidgets('muestra los elementos del prototipo de Pb-10', (tester) async {
    await abrir(tester);

    expect(find.text('Modo Karaoke'), findsOneWidget);
    expect(find.text('mi_cancion.mp4'), findsOneWidget);
    expect(find.byKey(const Key('panelLetra')), findsOneWidget);
    expect(find.text('Voz guía'), findsOneWidget);
    expect(find.text('30 %'), findsOneWidget);
    expect(find.text('Original'), findsOneWidget);
    expect(find.text('0 ms'), findsOneWidget);
    expect(find.text('Grabar'), findsOneWidget);
    expect(find.text('0:12'), findsOneWidget);
    // La voz guía empieza en 30 %
    expect(voz.nivel, 0.3);
    expect(linea(tester).text.toPlainText(), 'y la noche');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('resalta las palabras según la posición del audio', (
    tester,
  ) async {
    await abrir(tester);
    await tester.tap(find.byKey(const Key('botonReproducir')));
    await tester.pump();
    expect(instrumental.sonando && voz.sonando, isTrue);

    instrumental.posicion = const Duration(milliseconds: 4800);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('y la noche'), findsOneWidget);
    expect(linea(tester).text.toPlainText(), 'cantando bajo la luz');
    expect(cantado(tester), 'cantando bajo ');
    expect(find.text('hasta'), findsOneWidget);

    instrumental.posicion = const Duration(milliseconds: 5600);
    await tester.pump(const Duration(milliseconds: 50));
    expect(cantado(tester), 'cantando bajo la luz');

    await tester.tap(find.byKey(const Key('botonReproducir')));
    await tester.pump();
    expect(instrumental.sonando || voz.sonando, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('la voz guía cambia el volumen de la voz', (tester) async {
    await abrir(tester);

    await tester.drag(
      find.byKey(const Key('controlVozGuia')),
      const Offset(-400, 0),
    );
    await tester.pump();

    expect(voz.nivel, 0);
    expect(instrumental.nivel, 1);
    expect(find.text('0 %'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('recuerda la voz guía y la sincronía', (tester) async {
    await abrir(tester);
    await tester.drag(
      find.byKey(const Key('controlVozGuia')),
      const Offset(-400, 0),
    );
    await tester.tap(find.byTooltip('Bajar Sincronía'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());

    // Al volver a abrir el Modo Karaoke se usan los valores elegidos
    voz = _PistaFalsa();
    await abrir(tester);
    expect(find.text('0 %'), findsOneWidget);
    expect(find.text('-50 ms'), findsOneWidget);
    expect(voz.nivel, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('la sincronía corre la palabra resaltada', (tester) async {
    await abrir(tester);
    await tester.tap(find.byKey(const Key('botonReproducir')));
    await tester.pump();
    instrumental.posicion = const Duration(milliseconds: 4800);
    await tester.pump(const Duration(milliseconds: 50));
    expect(cantado(tester), 'cantando bajo ');

    // Con −200 ms la letra se resalta más tarde: «bajo» todavía no empieza
    for (int i = 0; i < 4; i++) {
      await tester.tap(find.byTooltip('Bajar Sincronía'));
    }
    await tester.pump();
    expect(find.text('-200 ms'), findsOneWidget);
    expect(cantado(tester), 'cantando ');
    await tester.tap(find.byKey(const Key('botonReproducir')));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('una canción sin letra muestra el motivo', (tester) async {
    await abrir(tester, estadoLetra: 404);

    expect(find.text('La canción no tiene letra'), findsOneWidget);
    final IconButton reproducir = tester.widget<IconButton>(
      find.byKey(const Key('botonReproducir')),
    );
    expect(reproducir.onPressed, isNull);
  });

  testWidgets('el tono va de −6 a +6 semitonos', (tester) async {
    await abrir(tester);
    final Finder subir = find.byTooltip('Subir Tono');
    final Finder bajar = find.byTooltip('Bajar Tono');
    IconButton boton(Finder f) => tester.widget<IconButton>(
      find.ancestor(of: f, matching: find.byType(IconButton)),
    );

    for (int i = 0; i < 8; i++) {
      await tester.tap(subir);
      await tester.pump();
    }
    expect(find.text('+6'), findsOneWidget);
    expect(boton(subir).onPressed, isNull);

    for (int i = 0; i < 14; i++) {
      await tester.tap(bajar);
      await tester.pump();
    }
    expect(find.text('−6'), findsOneWidget);
    expect(boton(bajar).onPressed, isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('la sincronía cambia en pasos de 50 ms', (tester) async {
    await abrir(tester);

    await tester.tap(find.byTooltip('Subir Sincronía'));
    await tester.pump();
    expect(find.text('50 ms'), findsOneWidget);

    await tester.tap(find.byTooltip('Bajar Sincronía'));
    await tester.tap(find.byTooltip('Bajar Sincronía'));
    await tester.pump();
    expect(find.text('-50 ms'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  test('formatoTiempo muestra minutos y segundos', () {
    expect(formatoTiempo(const Duration(minutes: 3, seconds: 45)), '3:45');
    expect(formatoTiempo(const Duration(seconds: 62)), '1:02');
  });
}
