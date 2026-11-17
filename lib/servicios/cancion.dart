/// Estados de una canción, los mismos de un trabajo del servidor.
enum EstadoCancion {
  /// Espera en la cola de procesamiento.
  enCola,

  /// Se está procesando.
  procesando,

  /// Terminó y se puede abrir.
  terminada,

  /// Terminó con un error.
  error,

  /// El usuario canceló el procesamiento.
  cancelada;

  /// Estado correspondiente al valor `status` de la API.
  static EstadoCancion desdeApi(String estado) => switch (estado) {
    'queued' => enCola,
    'running' => procesando,
    'done' => terminada,
    'cancelled' => cancelada,
    _ => error,
  };
}

/// Canción procesada (un trabajo del servidor), tal como la muestra la app.
class Cancion {
  /// Crea una canción.
  const Cancion({
    required this.id,
    required this.nombreArchivo,
    required this.estado,
    required this.progreso,
    this.posicionEnCola,
    this.duracionSegundos,
    this.tipoVideo,
    this.modeloSeparacion,
    this.error,
  });

  /// Crea la canción a partir de un trabajo de la API (`GET /jobs`).
  factory Cancion.desdeJson(Map<String, dynamic> json) => Cancion(
    id: json['id'] as String,
    nombreArchivo: json['source_filename'] as String,
    estado: EstadoCancion.desdeApi(json['status'] as String),
    progreso: json['progress'] as int,
    posicionEnCola: json['queue_position'] as int?,
    duracionSegundos: json['duration_seconds'] as int?,
    tipoVideo: json['video_type'] as String?,
    modeloSeparacion: json['separation_model'] as String?,
    error: json['error'] as String?,
  );

  /// Identificador del trabajo.
  final String id;

  /// Nombre del archivo subido.
  final String nombreArchivo;

  /// Estado actual.
  final EstadoCancion estado;

  /// Avance del procesamiento, de 0 a 100.
  final int progreso;

  /// Posición en la cola mientras espera.
  final int? posicionEnCola;

  /// Duración del video o audio, en segundos.
  final int? duracionSegundos;

  /// `karaoke` o `instrumental`.
  final String? tipoVideo;

  /// Modelo de separación utilizado (`demucs` o `spleeter`).
  final String? modeloSeparacion;

  /// Motivo del error, si lo hubo.
  final String? error;

  /// Nombre de la canción, sin la extensión del archivo.
  String get titulo {
    final int punto = nombreArchivo.lastIndexOf('.');
    return punto > 0 ? nombreArchivo.substring(0, punto) : nombreArchivo;
  }

  /// Solo las canciones terminadas se pueden abrir.
  bool get sePuedeAbrir => estado == EstadoCancion.terminada;

  /// Duración con el formato `m:ss`, o `null` si no se conoce.
  String? get duracion {
    final int? segundos = duracionSegundos;
    if (segundos == null) return null;
    final String resto = (segundos % 60).toString().padLeft(2, '0');
    return '${segundos ~/ 60}:$resto';
  }

  /// Línea de estado de la tarjeta, como en el prototipo.
  String get detalle => switch (estado) {
    EstadoCancion.terminada =>
      duracion == null ? 'Terminada' : 'Terminada · $duracion',
    EstadoCancion.procesando => 'Procesando · $progreso %',
    EstadoCancion.enCola =>
      posicionEnCola == null ? 'En cola' : 'En cola · posición $posicionEnCola',
    EstadoCancion.error => 'Error en el procesamiento',
    EstadoCancion.cancelada => 'Cancelada',
  };
}
