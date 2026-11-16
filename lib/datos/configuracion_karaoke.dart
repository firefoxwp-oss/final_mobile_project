/// Configuración del Modo Karaoke de una canción en el celular (Pb-10 y
/// Pb-11): nivel de la voz guía, ajuste de sincronía de la letra y tono.
class ConfiguracionKaraoke {
  /// Crea la configuración; la voz guía empieza en 30 %.
  const ConfiguracionKaraoke({
    this.vozGuia = 30,
    this.desfaseMs = 0,
    this.semitonos = 0,
  });

  /// Volumen de la voz guía, de 0 a 100.
  final int vozGuia;

  /// Ajuste de la letra en milisegundos: con un valor negativo la letra se
  /// resalta más tarde, para compensar el retraso de los audífonos
  /// Bluetooth.
  final int desfaseMs;

  /// Tono, de −6 a +6 semitonos; 0 es el original.
  final int semitonos;

  /// Copia de la configuración con los valores indicados.
  ConfiguracionKaraoke copiar({int? vozGuia, int? desfaseMs, int? semitonos}) =>
      ConfiguracionKaraoke(
        vozGuia: vozGuia ?? this.vozGuia,
        desfaseMs: desfaseMs ?? this.desfaseMs,
        semitonos: semitonos ?? this.semitonos,
      );
}
