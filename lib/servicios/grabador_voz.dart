import 'dart:io';
import 'dart:typed_data';

import 'package:record/record.dart';

/// Corrección del inicio de la voz grabada, medida con la prueba de bucle
/// del parlante al micrófono (Sp-16) en un Samsung Galaxy A16: el inicio de
/// la canción que se estima con la posición del reproductor ya incluye la
/// latencia del parlante y del micrófono, y queda 50 ms después del real.
const Duration correccionGrabacion = Duration(milliseconds: -50);

/// Recorta el inicio de la voz grabada (WAV) en [desfase], para que quede
/// alineada con el instrumental; con un desfase negativo agrega silencio.
Future<void> alinearVoz(String ruta, Duration desfase) async {
  final Uint8List wav = await File(ruta).readAsBytes();
  final ByteData datos = ByteData.sublistView(wav);
  // Cabecera RIFF: se busca el bloque «fmt » y el bloque «data»
  int posicion = 12;
  int canales = 1;
  int muestrasPorSegundo = 44100;
  int bytesPorMuestra = 2;
  while (posicion + 8 <= wav.length) {
    final String bloque = String.fromCharCodes(wav, posicion, posicion + 4);
    final int tamano = datos.getUint32(posicion + 4, Endian.little);
    if (bloque == 'fmt ') {
      canales = datos.getUint16(posicion + 10, Endian.little);
      muestrasPorSegundo = datos.getUint32(posicion + 12, Endian.little);
      bytesPorMuestra = datos.getUint16(posicion + 22, Endian.little) ~/ 8;
    }
    if (bloque == 'data') break;
    posicion += 8 + tamano;
  }
  final int inicioDatos = posicion + 8;
  final int bloqueMuestra = canales * bytesPorMuestra;
  final int muestras = (desfase.inMicroseconds * muestrasPorSegundo / 1000000)
      .round();
  final Uint8List audio = Uint8List.sublistView(wav, inicioDatos);
  final Uint8List alineado = muestras >= 0
      ? Uint8List.sublistView(
          audio,
          (muestras * bloqueMuestra).clamp(0, audio.length),
        )
      : (Uint8List(-muestras * bloqueMuestra + audio.length)..setRange(
          -muestras * bloqueMuestra,
          -muestras * bloqueMuestra + audio.length,
          audio,
        ));
  final Uint8List cabecera = Uint8List.fromList(wav.sublist(0, inicioDatos));
  final ByteData tamanos = ByteData.sublistView(cabecera);
  tamanos.setUint32(4, cabecera.length - 8 + alineado.length, Endian.little);
  tamanos.setUint32(inicioDatos - 4, alineado.length, Endian.little);
  final File destino = File(ruta);
  await destino.writeAsBytes(<int>[...cabecera, ...alineado], flush: true);
}

/// Grabación de la voz con el micrófono del celular (Pb-13).
abstract interface class GrabadorVoz {
  /// Pide el permiso del micrófono; devuelve si fue concedido.
  Future<bool> pedirPermisoMicrofono();

  /// Empieza a grabar en el archivo [ruta].
  Future<void> iniciar(String ruta);

  /// Termina la grabación y devuelve la ruta de la voz grabada.
  Future<String?> detener();

  /// Libera el micrófono.
  Future<void> liberar();
}

/// Grabador con el micrófono del celular, en WAV: así la voz se puede
/// recortar para alinearla con el instrumental.
class GrabadorDispositivo implements GrabadorVoz {
  final AudioRecorder _grabador = AudioRecorder();

  /// Una sola voz: mono, a 44,1 kHz como las pistas.
  static const RecordConfig configuracion = RecordConfig(
    encoder: AudioEncoder.wav,
    numChannels: 1,
    // Atenúan el instrumental que capta el micrófono si no hay audífonos
    echoCancel: true,
    noiseSuppress: true,
    // El instrumental suena a propósito mientras se graba: la grabación no
    // se pausa cuando el reproductor toma el audio del celular
    audioInterruption: AudioInterruptionMode.none,
  );

  @override
  Future<bool> pedirPermisoMicrofono() => _grabador.hasPermission();

  @override
  Future<void> iniciar(String ruta) =>
      _grabador.start(configuracion, path: ruta);

  @override
  Future<String?> detener() => _grabador.stop();

  @override
  Future<void> liberar() => _grabador.dispose();
}
