import 'dart:io';

import 'package:final_mobile_project/datos/almacen_grabaciones.dart';
import 'package:final_mobile_project/datos/grabacion.dart';
import 'package:final_mobile_project/pantallas/pantalla_grabaciones.dart';
import 'package:final_mobile_project/pantallas/pantalla_karaoke.dart';
import 'package:final_mobile_project/servicios/reproductor_pistas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Pista simulada que recuerda el archivo cargado.
class _PistaFalsa implements PistaAudio {
  @override
  Duration posicion = Duration.zero;
  String? ruta;
  double nivel = 1;
  bool sonando = false;

  @override
  Future<Duration?> cargar(String archivo) async {
    ruta = archivo;
    return const Duration(seconds: 10);
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

void main() {
  late Directory carpeta;
  late AlmacenGrabaciones almacen;
  late _PistaFalsa instrumental;
  late _PistaFalsa voz;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    carpeta = await Directory.systemTemp.createTemp('grabaciones');
    almacen = AlmacenGrabaciones(
      fabrica: databaseFactoryFfi,
      rutaBase: inMemoryDatabasePath,
      carpeta: () async => carpeta,
    );
    instrumental = _PistaFalsa();
    voz = _PistaFalsa();
  });

  tearDown(() async {
    await almacen.cerrar();
    await carpeta.delete(recursive: true);
  });

  Future<Grabacion> guardar(String titulo, int semitonos, DateTime fecha) {
    final File archivo = File('${carpeta.path}/voz_$titulo.wav')
      ..writeAsBytesSync(<int>[1]);
    final File pista = File('${carpeta.path}/pista_$titulo.m4a')
      ..writeAsBytesSync(<int>[2]);
    return almacen.guardar(
      Grabacion(
        idCancion: 'abc',
        titulo: titulo,
        rutaVoz: archivo.path,
        rutaInstrumental: '',
        semitonos: semitonos,
        vozGuia: 30,
        duracionSegundos: 225,
        fecha: fecha,
      ),
      pista.path,
    );
  }

  Future<void> abrir(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PantallaGrabaciones(
          almacen: almacen,
          crearReproductor: () =>
              ReproductorPistas(<PistaAudio>[instrumental, voz]),
        ),
      ),
    );
    await esperar(tester);
  }

  testWidgets('lista las grabaciones guardadas en el celular', (tester) async {
    final DateTime ahora = DateTime.now();
    await tester.runAsync(() async {
      await guardar('40 y 20', 0, ahora.subtract(const Duration(days: 1)));
      await guardar('mi_cancion', 2, ahora);
    });

    await abrir(tester);

    expect(find.text('Mis grabaciones'), findsOneWidget);
    expect(find.text('mi_cancion'), findsOneWidget);
    expect(find.textContaining('Tono +2'), findsOneWidget);
    expect(find.textContaining('Tono original'), findsOneWidget);
    expect(find.textContaining('3:45'), findsNWidgets(2));
    expect(
      find.text('Las grabaciones se guardan solo en el celular'),
      findsOneWidget,
    );
    // La más reciente primero
    expect(
      tester.getTopLeft(find.text('mi_cancion')).dy,
      lessThan(tester.getTopLeft(find.text('40 y 20')).dy),
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('escuchar reproduce la voz con su instrumental', (tester) async {
    final Grabacion guardada =
        (await tester.runAsync(() => guardar('mi_cancion', 2, DateTime.now())))
            as Grabacion;
    await abrir(tester);

    await tester.tap(find.text('mi_cancion'));
    await esperar(tester);

    expect(instrumental.ruta, guardada.rutaInstrumental);
    expect(voz.ruta, guardada.rutaVoz);
    expect(instrumental.sonando && voz.sonando, isTrue);
    expect(voz.nivel, 1);
    expect(find.byKey(const Key('barraGrabacion')), findsOneWidget);
    expect(find.text('mi_cancion · Tono +2'), findsOneWidget);

    instrumental.posicion = const Duration(seconds: 5);
    await tester.pump(const Duration(milliseconds: 300));
    final LinearProgressIndicator barra = tester
        .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
    // La barra sigue la duración de la grabación (3:45), no la del audio
    expect(barra.value, closeTo(5 / 225, 0.001));

    await tester.tap(find.byTooltip('Pausar'));
    await tester.pump();
    expect(instrumental.sonando, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('la grabación termina donde terminó la voz', (tester) async {
    await tester.runAsync(() => guardar('mi_cancion', 0, DateTime.now()));
    await abrir(tester);
    await tester.tap(find.text('mi_cancion'));
    await esperar(tester);

    // El instrumental dura más que la grabación de 3:45
    instrumental.posicion = const Duration(minutes: 3, seconds: 46);
    await tester.pump(const Duration(milliseconds: 300));
    await esperar(tester);

    expect(instrumental.sonando || voz.sonando, isFalse);
    expect(instrumental.posicion, Duration.zero);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('eliminar pide confirmación y borra la grabación', (
    tester,
  ) async {
    await tester.runAsync(() => guardar('mi_cancion', 0, DateTime.now()));
    await abrir(tester);

    await tester.tap(find.byTooltip('Eliminar grabación'));
    await tester.pumpAndSettle();
    expect(find.text('¿Eliminar la grabación de «mi_cancion»?'), findsOne);
    await tester.tap(find.text('Eliminar'));
    await esperar(tester);

    expect(find.byKey(const Key('sinGrabaciones')), findsOneWidget);
    expect(await tester.runAsync(almacen.listar), isEmpty);
  });

  testWidgets('sin grabaciones explica cómo grabar', (tester) async {
    await abrir(tester);

    expect(find.byKey(const Key('sinGrabaciones')), findsOneWidget);
  });

  testWidgets('el aviso y la tarjeta de la grabación', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: <Widget>[
              AvisoGrabacion(tiempo: Duration(seconds: 42), tono: 'Tono +2'),
              ResultadoGrabacion(
                titulo: 'mi_cancion',
                duracion: Duration(minutes: 3, seconds: 45),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Grabando · 0:42'), findsOneWidget);
    expect(find.text('Tono +2'), findsOneWidget);
    expect(find.text('Grabación terminada'), findsOneWidget);
    expect(find.text('mi_cancion · 3:45'), findsOneWidget);
    for (final String boton in <String>['Escuchar', 'Descartar', 'Guardar']) {
      expect(find.text(boton), findsOneWidget);
    }
  });

  test('la fecha dice hoy, ayer o el día', () {
    final DateTime ahora = DateTime(2026, 11, 16, 22);
    expect(
      formatoFecha(DateTime(2026, 11, 16, 21, 15), ahora: ahora),
      'Hoy, 21:15',
    );
    expect(
      formatoFecha(DateTime(2026, 11, 15, 19, 40), ahora: ahora),
      'Ayer, 19:40',
    );
    expect(formatoFecha(DateTime(2026, 11, 2, 10), ahora: ahora), '02/11');
  });

  test('el tono de la grabación', () {
    expect(textoTono(-1), 'Tono −1');
    expect(textoTono(0), 'Tono original');
  });
}

/// Ejecuta en tiempo real las tareas de SQLite y de los archivos.
Future<void> esperar(WidgetTester tester) async {
  for (int i = 0; i < 10; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}
