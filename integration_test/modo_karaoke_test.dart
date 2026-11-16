// Medición del Modo Karaoke en el celular (Pb-10, Sp-7).
//
// - Inicio de la reproducción (meta RR-06: menos de 3 s con datos móviles
//   4G): desde que se abre el Modo Karaoke, sin pistas en la caché, hasta que
//   la canción suena.
// - Desfase de la letra (meta RR-07: 100 ms como máximo): en el instante en
//   que la pantalla resalta cada palabra se registra la posición del audio;
//   el desfase es esa posición menos el inicio de la palabra en la letra.
//
// Para simular 4G en el emulador, antes de la prueba:
//   adb emu network speed 5000:12000   (subida:bajada en kbit/s)
//   adb emu network delay 60:60        (latencia en ms)
//
//   flutter drive --profile --driver=test_driver/integration_test.dart
//     --target=integration_test/modo_karaoke_test.dart
//     --dart-define=PRUEBA_EMAIL=... --dart-define=PRUEBA_CLAVE=...
//     --dart-define=JOB_ID=...
import 'dart:io';

import 'package:final_mobile_project/configuracion.dart';
import 'package:final_mobile_project/pantallas/pantalla_karaoke.dart';
import 'package:final_mobile_project/servicios/cancion.dart';
import 'package:final_mobile_project/servicios/cliente_api.dart';
import 'package:final_mobile_project/servicios/letra.dart';
import 'package:final_mobile_project/servicios/reproductor_pistas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

const String _correo = String.fromEnvironment('PRUEBA_EMAIL');
const String _clave = String.fromEnvironment('PRUEBA_CLAVE');
const String _trabajo = String.fromEnvironment('JOB_ID');

/// Reproductor real que registra el desfase de cada palabra en el instante
/// en que la pantalla la resalta.
class _ReproductorMedido extends ReproductorPistas {
  _ReproductorMedido()
    : super(<PistaAudio>[PistaDispositivo(), PistaDispositivo()]);

  final List<int> desfases = <int>[];
  PalabraLetra? _ultima;

  @override
  LetraResaltada resaltarPalabra(Duration posicionAudio) {
    final LetraResaltada resaltada = super.resaltarPalabra(posicionAudio);
    final Duration momento =
        posicionAudio + Duration(milliseconds: configuracion.desfaseMs);
    if (letra.lineas.isEmpty || !sonando) return resaltada;
    final List<PalabraLetra> empezadas = letra
        .lineas[letra.indiceLinea(momento)]
        .palabras
        .where((PalabraLetra p) => p.inicio <= momento)
        .toList();
    if (empezadas.isNotEmpty && empezadas.last != _ultima) {
      _ultima = empezadas.last;
      desfases.add((momento - empezadas.last.inicio).inMilliseconds);
    }
    return resaltada;
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('inicio de la reproducción y desfase de la letra', (
    tester,
  ) async {
    await cargarConfiguracion();
    final Directory pistas = Directory(
      '${(await getApplicationCacheDirectory()).path}/pistas',
    );
    if (await pistas.exists()) await pistas.delete(recursive: true);
    final ClienteApi cliente = ClienteApi();
    await cliente.iniciarSesion(_correo, _clave);
    final Cancion cancion = await cliente.obtenerTrabajo(_trabajo);
    final _ReproductorMedido reproductor = _ReproductorMedido();

    final Stopwatch inicio = Stopwatch()..start();
    await tester.pumpWidget(
      MaterialApp(
        home: PantallaKaraoke(
          cliente: cliente,
          cancion: cancion,
          crearReproductor: () => reproductor,
        ),
      ),
    );
    final Finder boton = find.byKey(const Key('botonReproducir'));
    while (tester.widget<IconButton>(boton).onPressed == null &&
        inicio.elapsed < const Duration(seconds: 30)) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.tap(boton);
    while (reproductor.posicion == Duration.zero &&
        inicio.elapsed < const Duration(seconds: 30)) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    final int inicioMs = inicio.elapsedMilliseconds;

    // La canción suena mientras la pantalla resalta las palabras
    await tester.pump(const Duration(seconds: 24));
    await reproductor.pausar();
    final List<int> desfases = reproductor.desfases;

    final List<int> absolutos = desfases.map((int d) => d.abs()).toList();
    final double promedio =
        absolutos.reduce((int a, int b) => a + b) / absolutos.length;
    final int maximo = absolutos.reduce((int a, int b) => a > b ? a : b);
    debugPrint(
      'MEDICION inicio=$inicioMs ms palabras=${desfases.length} '
      'desfase_promedio=${promedio.toStringAsFixed(1)} ms '
      'desfase_maximo=$maximo ms',
    );
    expect(inicioMs, lessThan(3000));
    expect(desfases.length, greaterThan(10));
    expect(maximo, lessThanOrEqualTo(100));
    await tester.pumpWidget(const SizedBox());
  });
}
