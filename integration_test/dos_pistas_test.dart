// Prueba de la reproducción sincronizada de dos pistas en el celular
// (Pb-10, Sp-1).
//
// Descarga el instrumental y la voz comprimidos (M4A) de una canción
// terminada, los reproduce a la vez y mide la separación entre ambos al
// empezar, mientras suenan, al adelantar y al cambiar el volumen de la voz.
//
//   flutter test integration_test/dos_pistas_test.dart
//     --dart-define=PRUEBA_EMAIL=... --dart-define=PRUEBA_CLAVE=...
//     --dart-define=JOB_ID=...
import 'dart:io';

import 'package:final_mobile_project/configuracion.dart';
import 'package:final_mobile_project/servicios/almacen_sesion.dart';
import 'package:final_mobile_project/servicios/cliente_api.dart';
import 'package:final_mobile_project/servicios/reproductor_pistas.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

const String _correo = String.fromEnvironment('PRUEBA_EMAIL');
const String _clave = String.fromEnvironment('PRUEBA_CLAVE');
const String _trabajo = String.fromEnvironment('JOB_ID');

Future<String> _descargar(ClienteApi cliente, String pista) async {
  final String? token = await AlmacenSesion().leerTokenAcceso();
  final http.Response respuesta = await http.get(
    cliente.uri('/descargar/$pista/$_trabajo'),
    headers: <String, String>{'Authorization': 'Bearer $token'},
  );
  expect(respuesta.statusCode, 200);
  final File archivo = File('${Directory.systemTemp.path}/$pista.m4a');
  await archivo.writeAsBytes(respuesta.bodyBytes);
  return archivo.path;
}

/// Corrige la separación cada 250 ms durante [tiempo], como lo hace el
/// Modo Karaoke, y devuelve la mayor separación de los últimos 2 s, ya
/// corregida.
Future<int> _observar(ReproductorPistas reproductor, Duration tiempo) async {
  final DateTime fin = DateTime.now().add(tiempo);
  final DateTime estable = fin.subtract(const Duration(seconds: 2));
  int mayor = 0;
  while (DateTime.now().isBefore(fin)) {
    await reproductor.sincronizar();
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final int ms = reproductor.desfaseEntrePistas.inMilliseconds;
    if (DateTime.now().isAfter(estable) && ms > mayor) mayor = ms;
  }
  return mayor;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('el instrumental y la voz suenan sincronizados', (_) async {
    await cargarConfiguracion();
    final ClienteApi cliente = ClienteApi();
    await cliente.iniciarSesion(_correo, _clave);
    final List<String> rutas = <String>[
      await _descargar(cliente, 'instrumental_comprimido'),
      await _descargar(cliente, 'voz_comprimida'),
    ];
    final ReproductorPistas reproductor = ReproductorPistas(<PistaAudio>[
      PistaDispositivo(),
      PistaDispositivo(),
    ]);
    await reproductor.cargar(rutas);
    await reproductor.cambiarVolumen(1, 0.3);

    await reproductor.reproducir();
    final int alEmpezar = await _observar(
      reproductor,
      const Duration(seconds: 8),
    );
    await reproductor.buscar(const Duration(seconds: 15));
    final int alAdelantar = await _observar(
      reproductor,
      const Duration(seconds: 5),
    );
    await reproductor.cambiarVolumen(1, 1);
    final int alCambiarVoz = await _observar(
      reproductor,
      const Duration(seconds: 5),
    );
    final Duration posicion = reproductor.posicion;
    await reproductor.liberar();

    debugPrint(
      'DESFASE duracion=${reproductor.duracion} al_empezar=$alEmpezar ms '
      'al_adelantar=$alAdelantar ms al_cambiar_voz=$alCambiarVoz ms '
      'posicion_final=$posicion',
    );
    expect(posicion, greaterThan(const Duration(seconds: 20)));
    for (final int ms in <int>[alEmpezar, alAdelantar, alCambiarVoz]) {
      expect(
        ms,
        lessThanOrEqualTo(ReproductorPistas.tolerancia.inMilliseconds),
      );
    }
  });
}
