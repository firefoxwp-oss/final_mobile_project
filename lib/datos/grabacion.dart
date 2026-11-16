/// Texto «Tono +2», «Tono −1» o «Tono original» de un tono en semitonos.
String textoTono(int semitonos) => semitonos == 0
    ? 'Tono original'
    : 'Tono ${semitonos > 0 ? '+$semitonos' : '−${-semitonos}'}';

/// Interpretación grabada sobre el instrumental (Pb-13); se guarda solo en el
/// celular, en la tabla `recordings`.
class Grabacion {
  /// Crea la grabación.
  const Grabacion({
    required this.idCancion,
    required this.titulo,
    required this.rutaVoz,
    required this.rutaInstrumental,
    required this.semitonos,
    required this.vozGuia,
    required this.duracionSegundos,
    required this.fecha,
    this.id,
  });

  /// Identificador en el celular; `null` antes de guardarla.
  final int? id;

  /// Canción del servidor que se grabó.
  final String idCancion;

  /// Nombre de la canción, para listarla sin conexión.
  final String titulo;

  /// Voz grabada con el micrófono.
  final String rutaVoz;

  /// Copia del instrumental en el tono usado.
  final String rutaInstrumental;

  /// Tono usado, de −6 a +6 semitonos.
  final int semitonos;

  /// Volumen de la voz guía al grabar, de 0 a 100.
  final int vozGuia;

  /// Duración de la grabación.
  final int duracionSegundos;

  /// Fecha y hora de la grabación.
  final DateTime fecha;

  /// Texto «Tono +2» o «Tono original» de la grabación.
  String get tono => textoTono(semitonos);
}
