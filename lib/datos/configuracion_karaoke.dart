import 'package:shared_preferences/shared_preferences.dart';

/// Configuración del Modo Karaoke de una canción en el celular (Pb-10 y
/// Pb-11): nivel de la voz guía, ajuste de sincronía de la letra y tono.
///
/// El celular recuerda la voz guía y la sincronía para todas las canciones,
/// porque dependen de la persona y de sus audífonos, y el tono de cada
/// canción por separado.
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

  static const String _claveVozGuia = 'karaoke.voz_guia';
  static const String _claveDesfase = 'karaoke.desfase_ms';
  static String _claveTono(String cancion) => 'karaoke.tono.$cancion';

  /// Lee la configuración guardada para la [cancion]; la primera vez, la
  /// inicial.
  static Future<ConfiguracionKaraoke> leer(String cancion) async {
    final SharedPreferences preferencias =
        await SharedPreferences.getInstance();
    return ConfiguracionKaraoke(
      vozGuia: preferencias.getInt(_claveVozGuia) ?? 30,
      desfaseMs: preferencias.getInt(_claveDesfase) ?? 0,
      semitonos: preferencias.getInt(_claveTono(cancion)) ?? 0,
    );
  }

  /// Guarda la configuración; el tono, como el de la [cancion].
  Future<void> guardar(String cancion) async {
    final SharedPreferences preferencias =
        await SharedPreferences.getInstance();
    await preferencias.setInt(_claveVozGuia, vozGuia);
    await preferencias.setInt(_claveDesfase, desfaseMs);
    await preferencias.setInt(_claveTono(cancion), semitonos);
  }

  /// Copia de la configuración con los valores indicados.
  ConfiguracionKaraoke copiar({int? vozGuia, int? desfaseMs, int? semitonos}) =>
      ConfiguracionKaraoke(
        vozGuia: vozGuia ?? this.vozGuia,
        desfaseMs: desfaseMs ?? this.desfaseMs,
        semitonos: semitonos ?? this.semitonos,
      );
}
