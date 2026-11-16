import 'package:record/record.dart';

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

/// Grabador con el micrófono del celular, en AAC (M4A) como las pistas.
class GrabadorDispositivo implements GrabadorVoz {
  final AudioRecorder _grabador = AudioRecorder();

  /// Una sola voz: mono, con la misma calidad que las pistas comprimidas.
  static const RecordConfig configuracion = RecordConfig(
    bitRate: 128000,
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
