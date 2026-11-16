// Prueba del cambio de tono en el celular (Pb-11, Sp-13).
//
// Reproduce una canción en el Modo Karaoke, sube un semitono, vuelve al tono
// original y elige otra vez el mismo tono. Comprueba que la duración de la
// canción no cambia, que sigue desde la misma posición con la letra
// resaltada, que con 0 semitonos se cargan las pistas originales y que un
// tono ya elegido se usa en menos de 3 s (RR-09).
//
//   flutter drive --profile --driver=test_driver/integration_test.dart
//     --target=integration_test/tono_test.dart
//     --dart-define=PRUEBA_EMAIL=... --dart-define=PRUEBA_CLAVE=...
//     --dart-define=JOB_ID=...
import 'package:final_mobile_project/configuracion.dart';
import 'package:final_mobile_project/datos/configuracion_karaoke.dart';
import 'package:final_mobile_project/pantallas/pantalla_karaoke.dart';
import 'package:final_mobile_project/servicios/cancion.dart';
import 'package:final_mobile_project/servicios/cliente_api.dart';
import 'package:final_mobile_project/servicios/reproductor_pistas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const String _correo = String.fromEnvironment('PRUEBA_EMAIL');
const String _clave = String.fromEnvironment('PRUEBA_CLAVE');
const String _trabajo = String.fromEnvironment('JOB_ID');

/// Pista real que recuerda el último archivo cargado.
class _PistaVista extends PistaDispositivo {
  String? ruta;

  @override
  Future<Duration?> cargar(String ruta) {
    this.ruta = ruta;
    return super.cargar(ruta);
  }
}

/// Resultado de tocar un botón del tono mientras suena la canción.
class _Cambio {
  _Cambio(this.milisegundos, this.antes, this.despues, this.duracion);

  final int milisegundos;
  final Duration antes;
  final Duration despues;
  final Duration? duracion;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('el tono cambia sin cambiar la canción', (tester) async {
    await cargarConfiguracion();
    // La prueba empieza en el tono original
    await const ConfiguracionKaraoke().guardar(_trabajo);
    final ClienteApi cliente = ClienteApi();
    await cliente.iniciarSesion(_correo, _clave);
    final Cancion cancion = await cliente.obtenerTrabajo(_trabajo);
    final _PistaVista instrumental = _PistaVista();
    final ReproductorPistas reproductor = ReproductorPistas(<PistaAudio>[
      instrumental,
      PistaDispositivo(),
    ]);
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
    while (tester.widget<IconButton>(boton).onPressed == null) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final Duration? original = reproductor.duracion;
    final String rutaOriginal = instrumental.ruta!;
    await tester.tap(boton);
    await tester.pump(const Duration(seconds: 3));

    Future<_Cambio> tocar(String tooltip) async {
      final Duration antes = reproductor.posicion;
      final Stopwatch tiempo = Stopwatch()..start();
      await tester.tap(find.byTooltip(tooltip));
      await tester.pump(const Duration(milliseconds: 50));
      while (find.text('Preparando el tono…').evaluate().isNotEmpty) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      final int ms = tiempo.elapsedMilliseconds;
      await tester.pump(const Duration(milliseconds: 500));
      final _Cambio cambio = _Cambio(
        ms,
        antes,
        reproductor.posicion,
        reproductor.duracion,
      );
      await tester.pump(const Duration(seconds: 2));
      return cambio;
    }

    final _Cambio subir = await tocar('Subir Tono');
    expect(find.text('+1'), findsOneWidget);
    final String rutaTono = instrumental.ruta!;
    final _Cambio volver = await tocar('Bajar Tono');
    expect(find.text('Original'), findsOneWidget);
    final String rutaVuelta = instrumental.ruta!;
    final _Cambio otraVez = await tocar('Subir Tono');
    await reproductor.pausar();

    debugPrint(
      'TONO subir=${subir.milisegundos} ms volver=${volver.milisegundos} ms '
      'reutilizar=${otraVez.milisegundos} ms '
      'duracion=${original?.inMilliseconds}/'
      '${subir.duracion?.inMilliseconds} ms',
    );
    for (final _Cambio cambio in <_Cambio>[subir, volver, otraVez]) {
      // La canción sigue desde donde estaba, sin volver atrás
      expect(cambio.despues, greaterThanOrEqualTo(cambio.antes));
      // Cambiar el tono no cambia la duración
      expect(
        (cambio.duracion! - original!).abs(),
        lessThan(const Duration(milliseconds: 100)),
      );
    }
    expect(rutaTono, endsWith('_instrumental_1.m4a'));
    expect(rutaVuelta, rutaOriginal);
    expect(otraVez.milisegundos, lessThan(3000));
    expect(volver.milisegundos, lessThan(3000));
    final String linea = tester
        .widget<RichText>(
          find.descendant(
            of: find.byKey(const Key('lineaActual')),
            matching: find.byType(RichText),
          ),
        )
        .text
        .toPlainText();
    expect(linea, isNotEmpty);
    await tester.pumpWidget(const SizedBox());
  });
}
