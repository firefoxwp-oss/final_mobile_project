// Prueba de la alineación de la voz grabada en el celular (Pb-13, Sp-16 y
// Sp-19).
//
// Graba sin cancelación de eco mientras el instrumental suena por el
// parlante: el micrófono capta el instrumental con el mismo retraso que
// tendría la voz de quien canta al oírlo. La grabación ya alineada queda en
// la carpeta externa de la aplicación y, mientras la prueba espera, se mide
// en la computadora con tool/medir_alineacion.py (meta: 100 ms o menos):
//
//   flutter drive --profile --driver=test_driver/integration_test.dart
//     --target=integration_test/alineacion_test.dart
//     --dart-define=PRUEBA_EMAIL=... --dart-define=PRUEBA_CLAVE=...
//     --dart-define=JOB_ID=...
//   adb pull <ruta que muestra la prueba> voz.wav
//   python tool/medir_alineacion.py voz.wav instrumental.m4a
import 'dart:io';

import 'package:final_mobile_project/configuracion.dart';
import 'package:final_mobile_project/datos/configuracion_karaoke.dart';
import 'package:final_mobile_project/pantallas/pantalla_karaoke.dart';
import 'package:final_mobile_project/servicios/cliente_api.dart';
import 'package:final_mobile_project/servicios/grabador_voz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

const String _correo = String.fromEnvironment('PRUEBA_EMAIL');
const String _clave = String.fromEnvironment('PRUEBA_CLAVE');
const String _trabajo = String.fromEnvironment('JOB_ID');

/// Grabador sin cancelación de eco: capta el instrumental del parlante.
class _GrabadorBucle implements GrabadorVoz {
  final AudioRecorder _g = AudioRecorder();
  String? ruta;

  @override
  Future<bool> pedirPermisoMicrofono() => _g.hasPermission();

  @override
  Future<void> iniciar(String destino) => _g.start(
    const RecordConfig(
      encoder: AudioEncoder.wav,
      numChannels: 1,
      audioInterruption: AudioInterruptionMode.none,
    ),
    path: destino,
  );

  @override
  Future<String?> detener() async => ruta = await _g.stop();

  @override
  Future<void> liberar() => _g.dispose();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('graba el instrumental del parlante', (tester) async {
    await cargarConfiguracion();
    await const ConfiguracionKaraoke(vozGuia: 0).guardar(_trabajo);
    final ClienteApi cliente = ClienteApi();
    await cliente.iniciarSesion(_correo, _clave);
    final cancion = await cliente.obtenerTrabajo(_trabajo);
    final _GrabadorBucle grabador = _GrabadorBucle();
    final Directory externa = (await getExternalStorageDirectory())!;
    await tester.pumpWidget(
      MaterialApp(
        home: PantallaKaraoke(
          cliente: cliente,
          cancion: cancion,
          crearGrabador: () => grabador,
          carpetaGrabaciones: () async => externa,
        ),
      ),
    );
    final Finder boton = find.byKey(const Key('botonGrabar'));
    while (tester.widget<FilledButton>(boton).onPressed == null) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.ensureVisible(boton);
    await tester.tap(boton);
    await tester.pump(const Duration(seconds: 15));
    await tester.ensureVisible(find.byKey(const Key('botonDetener')));
    await tester.tap(find.byKey(const Key('botonDetener')));
    await tester.pump(const Duration(seconds: 2));
    debugPrint('GRABACION_ALINEADA ${grabador.ruta}');
    // Tiempo para copiar la grabación antes de que se desinstale la app
    await tester.pump(const Duration(seconds: 40));
    expect(File(grabador.ruta!).existsSync(), isTrue);
  });
}
