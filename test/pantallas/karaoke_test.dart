import 'dart:convert';
import 'dart:io';

import 'package:final_mobile_project/pantallas/pantalla_karaoke.dart';
import 'package:final_mobile_project/servicios/almacen_sesion.dart';
import 'package:final_mobile_project/servicios/cancion.dart';
import 'package:final_mobile_project/servicios/cliente_api.dart';
import 'package:final_mobile_project/servicios/grabador_voz.dart';
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

  final List<String> rutas = <String>[];

  @override
  Future<Duration?> cargar(String ruta) async {
    rutas.add(ruta);
    return const Duration(seconds: 12);
  }

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

/// Micrófono simulado: escribe un archivo al grabar.
class _GrabadorFalso implements GrabadorVoz {
  _GrabadorFalso({this.permiso = true});

  final bool permiso;
  String? ruta;
  bool grabando = false;

  @override
  Future<bool> pedirPermisoMicrofono() async => permiso;

  @override
  Future<void> iniciar(String destino) async {
    ruta = destino;
    grabando = true;
    // WAV mono de 16 bits, sin muestras
    File(destino).writeAsBytesSync(<int>[
      ...'RIFF'.codeUnits, 36, 0, 0, 0, ...'WAVEfmt '.codeUnits, //
      16, 0, 0, 0, 1, 0, 1, 0, 68, 172, 0, 0, 136, 88, 1, 0, 2, 0, 16, 0,
      ...'data'.codeUnits, 0, 0, 0, 0,
    ]);
  }

  @override
  Future<String?> detener() async {
    grabando = false;
    return ruta;
  }

  @override
  Future<void> liberar() async {}
}

void main() {
  late Directory cache;
  late _PistaFalsa instrumental;
  late _PistaFalsa voz;
  late _GrabadorFalso grabador;
  final List<String> peticiones = <String>[];

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{
      'token_acceso': 'acceso',
      'token_renovacion': 'renovacion',
    });
    SharedPreferences.setMockInitialValues(<String, Object>{});
    cache = await Directory.systemTemp.createTemp('karaoke');
    peticiones.clear();
    instrumental = _PistaFalsa();
    voz = _PistaFalsa();
    grabador = _GrabadorFalso();
  });

  tearDown(() => cache.delete(recursive: true));

  Future<void> abrir(
    WidgetTester tester, {
    int estadoLetra = 200,
    int estadoTono = 200,
  }) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ClienteApi cliente = ClienteApi(
      url: 'https://api.prueba',
      almacen: AlmacenSesion(),
      carpetaPistas: () async => cache,
      cliente: MockClient((http.Request p) async {
        peticiones.add(p.url.path);
        if (p.url.path.contains('/tono/')) {
          // El servidor tarda en generar el tono la primera vez
          await Future<void>.delayed(const Duration(milliseconds: 200));
          return estadoTono == 200
              ? http.Response.bytes(<int>[9, 9], 200)
              : http.Response.bytes(
                  utf8.encode(
                    jsonEncode(<String, String>{
                      'detail': 'La canción no tiene esta pista',
                    }),
                  ),
                  estadoTono,
                );
        }
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
          crearGrabador: () => grabador,
          carpetaGrabaciones: () async => cache,
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

  /// Ejecuta en tiempo real las tareas del archivo y del micrófono.
  Future<void> esperar(WidgetTester tester) async {
    for (int i = 0; i < 15; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('graba la voz mientras suena la canción desde el inicio', (
    tester,
  ) async {
    await abrir(tester);
    instrumental.posicion = const Duration(seconds: 6);

    await tester.tap(find.byKey(const Key('botonGrabar')));
    await esperar(tester);

    expect(grabador.grabando, isTrue);
    expect(grabador.ruta, contains('grabaciones'));
    expect(instrumental.sonando && voz.sonando, isTrue);
    expect(find.byKey(const Key('avisoGrabacion')), findsOneWidget);
    expect(find.text('Usa audífonos para que solo se grabe tu voz'), findsOne);
    // Mientras se graba no se cambia el tono ni la posición
    final IconButton tono = tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip('Subir Tono'),
        matching: find.byType(IconButton),
      ),
    );
    expect(tono.onPressed, isNull);

    instrumental.posicion = const Duration(seconds: 4);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Grabando · 0:04'), findsOneWidget);

    await tester.tap(find.byKey(const Key('botonDetener')));
    await esperar(tester);

    expect(grabador.grabando, isFalse);
    expect(instrumental.sonando, isFalse);
    expect(find.byKey(const Key('resultadoGrabacion')), findsOneWidget);
    expect(find.text('mi_cancion · 0:04'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('la grabación termina con la canción', (tester) async {
    await abrir(tester);
    await tester.tap(find.byKey(const Key('botonGrabar')));
    await esperar(tester);

    instrumental.posicion = const Duration(seconds: 12);
    await esperar(tester);

    expect(grabador.grabando, isFalse);
    expect(find.byKey(const Key('resultadoGrabacion')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('descartar borra la grabación', (tester) async {
    await abrir(tester);
    await tester.tap(find.byKey(const Key('botonGrabar')));
    await esperar(tester);
    await tester.tap(find.byKey(const Key('botonDetener')));
    await esperar(tester);
    final File voz = File(grabador.ruta!);
    expect(voz.existsSync(), isTrue);

    await tester.ensureVisible(find.text('Descartar'));
    await tester.tap(find.text('Descartar'));
    await esperar(tester);

    expect(voz.existsSync(), isFalse);
    expect(find.byKey(const Key('resultadoGrabacion')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('sin el permiso del micrófono explica cómo darlo', (
    tester,
  ) async {
    grabador = _GrabadorFalso(permiso: false);
    await abrir(tester);

    await tester.tap(find.byKey(const Key('botonGrabar')));
    await esperar(tester);

    expect(find.byKey(const Key('dialogoPermiso')), findsOneWidget);
    expect(find.textContaining('Permisos → Micrófono'), findsOneWidget);
    expect(grabador.grabando, isFalse);
    expect(instrumental.sonando, isFalse);
    await tester.tap(find.text('Entendido'));
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

  /// Espera a que lleguen las pistas del tono nuevo.
  Future<void> esperarTono(WidgetTester tester) async {
    for (int i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      if (find.text('Preparando el tono…').evaluate().isEmpty) break;
    }
    await tester.pump();
  }

  /// Toca un botón del tono y espera a que lleguen las pistas.
  Future<void> cambiarTono(WidgetTester tester, String boton) async {
    await tester.tap(find.byTooltip(boton));
    await tester.pump();
    await esperarTono(tester);
  }

  IconButton boton(WidgetTester tester, String tooltip) =>
      tester.widget<IconButton>(
        find.ancestor(
          of: find.byTooltip(tooltip),
          matching: find.byType(IconButton),
        ),
      );

  testWidgets('cambia el tono sin mover la canción de su posición', (
    tester,
  ) async {
    await abrir(tester);
    await tester.tap(find.byKey(const Key('botonReproducir')));
    await tester.pump();
    instrumental.posicion = const Duration(seconds: 5);

    await tester.tap(find.byTooltip('Subir Tono'));
    await tester.pump();
    expect(find.text('Preparando el tono…'), findsOneWidget);
    expect(boton(tester, 'Subir Tono').onPressed, isNull);
    await esperarTono(tester);

    expect(find.text('+1'), findsOneWidget);
    expect(find.text('Preparando el tono…'), findsNothing);
    expect(peticiones.where((String p) => p.contains('/tono/')), <String>[
      '/jobs/abc/tono/1/instrumental',
      '/jobs/abc/tono/1/voz',
    ]);
    expect(instrumental.rutas.last, endsWith('abc_instrumental_1.m4a'));
    expect(voz.rutas.last, endsWith('abc_voz_1.m4a'));
    expect(instrumental.posicion, const Duration(seconds: 5));
    expect(instrumental.sonando && voz.sonando, isTrue);
    // La voz guía conserva su nivel con las pistas nuevas
    expect(voz.nivel, 0.3);
    await tester.tap(find.byKey(const Key('botonReproducir')));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('el tono va de −6 a +6 y se recuerda para la canción', (
    tester,
  ) async {
    await abrir(tester);
    for (int i = 0; i < 6; i++) {
      await cambiarTono(tester, 'Subir Tono');
    }
    expect(find.text('+6'), findsOneWidget);
    expect(boton(tester, 'Subir Tono').onPressed, isNull);
    for (int i = 0; i < 12; i++) {
      await cambiarTono(tester, 'Bajar Tono');
    }
    expect(find.text('−6'), findsOneWidget);
    expect(boton(tester, 'Bajar Tono').onPressed, isNull);
    await tester.pumpWidget(const SizedBox());

    // Al volver a abrir la canción suena en el último tono elegido
    peticiones.clear();
    instrumental.rutas.clear();
    await abrir(tester);
    expect(find.text('−6'), findsOneWidget);
    // Las pistas en −6 ya están en la caché del celular
    expect(instrumental.rutas.last, endsWith('abc_instrumental_-6.m4a'));
    expect(peticiones.where((String p) => p.contains('/tono/')), isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('si el tono no se puede generar vuelve al anterior', (
    tester,
  ) async {
    await abrir(tester, estadoTono: 404);

    await cambiarTono(tester, 'Subir Tono');

    expect(find.text('Original'), findsOneWidget);
    expect(find.text('La canción no tiene esta pista'), findsOneWidget);
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
