// Prueba de la grabación de la interpretación en el celular (Pb-13, Sp-19).
//
// Graba la voz con el micrófono mientras suena la canción, la guarda y la
// busca en «Mis grabaciones»: comprueba que la voz y la copia del
// instrumental quedan en el celular, fuera de la caché, y que se escuchan
// juntas sin pedir nada al servidor. Con --dart-define=SIN_PERMISO=true
// comprueba que, sin el permiso del micrófono, se explica cómo darlo y no se
// graba (antes: adb shell pm revoke <paquete> android.permission.RECORD_AUDIO).
//
//   flutter drive --profile --driver=test_driver/integration_test.dart
//     --target=integration_test/grabacion_test.dart
//     --dart-define=PRUEBA_EMAIL=... --dart-define=PRUEBA_CLAVE=...
//     --dart-define=JOB_ID=...
import 'dart:io';

import 'package:final_mobile_project/configuracion.dart';
import 'package:final_mobile_project/datos/almacen_grabaciones.dart';
import 'package:final_mobile_project/datos/grabacion.dart';
import 'package:final_mobile_project/pantallas/pantalla_grabaciones.dart';
import 'package:final_mobile_project/pantallas/pantalla_karaoke.dart';
import 'package:final_mobile_project/servicios/cancion.dart';
import 'package:final_mobile_project/servicios/cliente_api.dart';
import 'package:final_mobile_project/servicios/reproductor_pistas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

const String _correo = String.fromEnvironment('PRUEBA_EMAIL');
const String _clave = String.fromEnvironment('PRUEBA_CLAVE');
const String _trabajo = String.fromEnvironment('JOB_ID');
const bool _sinPermiso = bool.fromEnvironment('SIN_PERMISO');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<(ClienteApi, Cancion)> iniciar() async {
    await cargarConfiguracion();
    final ClienteApi cliente = ClienteApi();
    await cliente.iniciarSesion(_correo, _clave);
    return (cliente, await cliente.obtenerTrabajo(_trabajo));
  }

  Future<void> esperarCarga(WidgetTester tester) async {
    final Finder boton = find.byKey(const Key('botonGrabar'));
    while (tester.widget<FilledButton>(boton).onPressed == null) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.ensureVisible(boton);
  }

  testWidgets('graba, guarda y escucha la interpretación', (tester) async {
    final (ClienteApi cliente, Cancion cancion) = await iniciar();
    final AlmacenGrabaciones almacen = AlmacenGrabaciones();
    final int antes = (await almacen.listar()).length;
    await tester.pumpWidget(
      MaterialApp(
        home: PantallaKaraoke(
          cliente: cliente,
          cancion: cancion,
          almacenGrabaciones: almacen,
        ),
      ),
    );
    await esperarCarga(tester);

    await tester.tap(find.byKey(const Key('botonGrabar')));
    await tester.pump(const Duration(seconds: 8));
    expect(find.byKey(const Key('avisoGrabacion')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('botonDetener')));
    await tester.tap(find.byKey(const Key('botonDetener')));
    await tester.pump(const Duration(seconds: 1));
    await tester.ensureVisible(find.text('Guardar'));
    await tester.tap(find.text('Guardar'));
    await tester.pump(const Duration(seconds: 1));

    final List<Grabacion> grabaciones = await almacen.listar();
    expect(grabaciones, hasLength(antes + 1));
    final Grabacion nueva = grabaciones.first;
    final String documentos = (await getApplicationDocumentsDirectory()).path;
    for (final String ruta in <String>[nueva.rutaVoz, nueva.rutaInstrumental]) {
      expect(ruta, startsWith(documentos));
      expect(File(ruta).lengthSync(), greaterThan(10000));
    }
    expect(nueva.duracionSegundos, inInclusiveRange(7, 9));

    // «Mis grabaciones» solo usa archivos del celular, no el servidor
    final ReproductorPistas reproductor = ReproductorPistas(<PistaAudio>[
      PistaDispositivo(),
      PistaDispositivo(),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: PantallaGrabaciones(
          almacen: almacen,
          crearReproductor: () => reproductor,
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byType(TarjetaGrabacion).first);
    await tester.pump(const Duration(seconds: 3));
    debugPrint(
      'GRABACION ${nueva.duracionSegundos} s, voz '
      '${File(nueva.rutaVoz).lengthSync()} B, suena=${reproductor.sonando}, '
      'separacion=${reproductor.desfaseEntrePistas.inMilliseconds} ms',
    );
    expect(reproductor.sonando, isTrue);
    expect(reproductor.posicion, greaterThan(const Duration(seconds: 1)));
    await tester.pumpWidget(const SizedBox());
    await almacen.eliminar(nueva);
  }, skip: _sinPermiso);

  testWidgets('sin el permiso del micrófono no se graba', (tester) async {
    final (ClienteApi cliente, Cancion cancion) = await iniciar();
    await tester.pumpWidget(
      MaterialApp(
        home: PantallaKaraoke(cliente: cliente, cancion: cancion),
      ),
    );
    await esperarCarga(tester);

    await tester.tap(find.byKey(const Key('botonGrabar')));
    await tester.pump(const Duration(seconds: 2));

    expect(find.byKey(const Key('dialogoPermiso')), findsOneWidget);
    expect(find.byKey(const Key('avisoGrabacion')), findsNothing);
    await tester.tap(find.text('Entendido'));
    await tester.pumpWidget(const SizedBox());
  }, skip: !_sinPermiso);
}
