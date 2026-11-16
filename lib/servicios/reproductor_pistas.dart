import 'dart:async';

import 'package:just_audio/just_audio.dart';

import '../datos/configuracion_karaoke.dart';
import 'letra.dart';

/// Pista de audio que se reproduce junto con otras.
abstract interface class PistaAudio {
  /// Carga el archivo de la pista y devuelve su duración.
  Future<Duration?> cargar(String ruta);

  /// Empieza o continúa la reproducción.
  Future<void> reproducir();

  /// Pausa la reproducción.
  Future<void> pausar();

  /// Mueve la reproducción a [posicion].
  Future<void> buscar(Duration posicion);

  /// Espera a que la pista tenga el audio listo para sonar sin demora.
  Future<void> lista();

  /// Cambia el volumen, de 0 a 1.
  Future<void> volumen(double nivel);

  /// Cambia la velocidad sin cambiar el tono; 1 es la velocidad normal.
  Future<void> velocidad(double factor);

  /// Posición actual del audio.
  Duration get posicion;

  /// Libera el reproductor del sistema.
  Future<void> liberar();
}

/// Pista reproducida con el reproductor de audio de Android (ExoPlayer),
/// que admite el audio comprimido M4A del servidor.
class PistaDispositivo implements PistaAudio {
  final AudioPlayer _reproductor = AudioPlayer();

  @override
  Future<Duration?> cargar(String ruta) => _reproductor.setFilePath(ruta);

  @override
  Future<void> reproducir() async {
    // play() termina recién cuando la pista se pausa; no se espera
    unawaited(_reproductor.play());
  }

  @override
  Future<void> pausar() => _reproductor.pause();

  @override
  Future<void> buscar(Duration posicion) => _reproductor.seek(posicion);

  @override
  Future<void> lista() => _reproductor.processingStateStream
      .firstWhere((ProcessingState estado) => estado == ProcessingState.ready)
      .timeout(const Duration(seconds: 5));

  @override
  Future<void> volumen(double nivel) => _reproductor.setVolume(nivel);

  @override
  Future<void> velocidad(double factor) => _reproductor.setSpeed(factor);

  @override
  Duration get posicion => _reproductor.position;

  @override
  Future<void> liberar() => _reproductor.dispose();
}

/// Línea actual de la letra separada en lo ya cantado y lo que falta, con
/// la línea anterior y la siguiente.
class LetraResaltada {
  /// Crea la línea resaltada.
  const LetraResaltada({
    this.anterior = '',
    this.cantado = '',
    this.pendiente = '',
    this.siguiente = '',
  });

  /// Línea que ya se cantó.
  final String anterior;

  /// Palabras de la línea actual que ya empezaron a cantarse.
  final String cantado;

  /// Palabras de la línea actual que faltan.
  final String pendiente;

  /// Línea que sigue.
  final String siguiente;

  @override
  bool operator ==(Object other) =>
      other is LetraResaltada &&
      other.anterior == anterior &&
      other.cantado == cantado &&
      other.pendiente == pendiente &&
      other.siguiente == siguiente;

  @override
  int get hashCode => Object.hash(anterior, cantado, pendiente, siguiente);
}

/// Reproduce el instrumental y la voz guía a la vez, sincronizados (Pb-10).
///
/// La primera pista marca la posición de la canción. Cada reproductor del
/// sistema tarda distinto en empezar a sonar, por lo que una pista que se
/// separa más de [tolerancia] se acelera o se frena un poco hasta alcanzar
/// al instrumental, sin cortes ni saltos.
class ReproductorPistas {
  /// Crea el reproductor de las [pistas]; la primera es el instrumental.
  ReproductorPistas(this.pistas);

  /// Pistas que suenan juntas.
  final List<PistaAudio> pistas;

  /// Separación máxima entre pistas antes de corregirla: la mitad del
  /// desfase de 100 ms que se admite para la letra (RR-07).
  static const Duration tolerancia = Duration(milliseconds: 50);

  /// Separación a partir de la cual una pista se considera alineada.
  static const Duration alineada = Duration(milliseconds: 10);

  /// Separación que se corrige con un salto, porque ajustar la velocidad
  /// tardaría demasiado.
  static const Duration salto = Duration(seconds: 2);

  /// Tiempo en que se busca corregir cualquier separación.
  static const Duration correccion = Duration(seconds: 2);

  /// Límites del cambio de velocidad para corregir la separación; no altera
  /// el tono, porque Android lo conserva al cambiar la velocidad.
  static const double ajusteMinimo = 0.04;

  /// Límites del cambio de velocidad para corregir la separación.
  static const double ajusteMaximo = 0.2;

  /// Cambio de velocidad que corrige [diferencia] en [correccion].
  static double ajuste(Duration diferencia) =>
      (diferencia.inMicroseconds.abs() / correccion.inMicroseconds).clamp(
        ajusteMinimo,
        ajusteMaximo,
      );

  /// Duración de la canción, conocida al cargarla.
  Duration? duracion;

  /// Letra sincronizada de la canción.
  Letra letra = const Letra(<LineaLetra>[]);

  /// Voz guía, sincronía y tono de la canción.
  ConfiguracionKaraoke configuracion = const ConfiguracionKaraoke();

  bool _sonando = false;
  final Map<PistaAudio, double> _velocidades = <PistaAudio, double>{};

  /// Indica si la canción está sonando.
  bool get sonando => _sonando;

  /// Posición de la canción, la del instrumental.
  Duration get posicion => pistas.first.posicion;

  /// Mayor separación entre la primera pista y las demás.
  Duration get desfaseEntrePistas {
    final Duration referencia = posicion;
    Duration mayor = Duration.zero;
    for (final PistaAudio pista in pistas.skip(1)) {
      final Duration diferencia = (pista.posicion - referencia).abs();
      if (diferencia > mayor) mayor = diferencia;
    }
    return mayor;
  }

  /// Carga un archivo por pista, en el mismo orden de [pistas], con la
  /// [letra] y la [configuracion] de la canción.
  Future<void> cargar(
    List<String> rutas, {
    Letra? letra,
    ConfiguracionKaraoke? configuracion,
  }) async {
    final List<Duration?> duraciones = await Future.wait(<Future<Duration?>>[
      for (int i = 0; i < pistas.length; i++) pistas[i].cargar(rutas[i]),
    ]);
    duracion = duraciones.first;
    if (letra != null) this.letra = letra;
    if (configuracion != null) this.configuracion = configuracion;
    if (pistas.length > 1) await cambiarVolumenVoz(this.configuracion.vozGuia);
  }

  /// Separa la línea que se canta en la posición del audio, corrida por el
  /// ajuste de sincronía: las palabras que ya empezaron quedan resaltadas.
  LetraResaltada resaltarPalabra(Duration posicionAudio) {
    final List<LineaLetra> lineas = letra.lineas;
    if (lineas.isEmpty) return const LetraResaltada();
    final Duration momento =
        posicionAudio + Duration(milliseconds: configuracion.desfaseMs);
    final int indice = letra.indiceLinea(momento);
    final List<PalabraLetra> palabras = lineas[indice].palabras;
    final int cantadas = palabras
        .where((PalabraLetra palabra) => palabra.inicio <= momento)
        .length;
    String unir(Iterable<PalabraLetra> parte) =>
        parte.map((PalabraLetra palabra) => palabra.texto).join(' ');
    final String cantado = unir(palabras.take(cantadas));
    final String pendiente = unir(palabras.skip(cantadas));
    return LetraResaltada(
      anterior: indice > 0 ? lineas[indice - 1].texto : '',
      cantado: cantado.isNotEmpty && pendiente.isNotEmpty
          ? '$cantado '
          : cantado,
      pendiente: pendiente,
      siguiente: indice + 1 < lineas.length ? lineas[indice + 1].texto : '',
    );
  }

  /// Empieza o continúa todas las pistas a la vez, cuando todas tienen el
  /// audio listo; así ninguna empieza más tarde por estar cargando.
  Future<void> reproducir() async {
    await Future.wait(pistas.map((PistaAudio p) => p.lista()));
    await Future.wait(pistas.map((PistaAudio p) => p.reproducir()));
    _sonando = true;
  }

  /// Pausa todas las pistas.
  Future<void> pausar() async {
    _sonando = false;
    await Future.wait(pistas.map((PistaAudio p) => p.pausar()));
  }

  /// Mueve todas las pistas a [destino]; si la canción suena, la pausa
  /// mientras tanto para que las pistas vuelvan a empezar juntas.
  Future<void> buscar(Duration destino) async {
    final bool sonaba = _sonando;
    if (sonaba) await pausar();
    await Future.wait(pistas.map((PistaAudio p) => p.buscar(destino)));
    if (sonaba) await reproducir();
  }

  /// Cambia el volumen de la pista [indice], de 0 a 1.
  Future<void> cambiarVolumen(int indice, double nivel) =>
      pistas[indice].volumen(nivel);

  /// Cambia el volumen de la voz guía, de 0 a 100, sin cortar la canción.
  Future<void> cambiarVolumenVoz(int nivel) {
    configuracion = configuracion.copiar(vozGuia: nivel);
    return cambiarVolumen(1, nivel / 100);
  }

  /// Corrige la separación de cada pista respecto del instrumental; se
  /// llama varias veces por segundo mientras suena la canción.
  Future<void> sincronizar() async {
    if (desfaseEntrePistas > salto) {
      await buscar(posicion);
      return;
    }
    final Duration referencia = posicion;
    for (final PistaAudio pista in pistas.skip(1)) {
      final Duration diferencia = pista.posicion - referencia;
      final double actual = _velocidades[pista] ?? 1;
      double nueva = actual;
      if (diferencia.abs() > tolerancia) {
        final double cambio = ajuste(diferencia);
        nueva = diferencia.isNegative ? 1 + cambio : 1 - cambio;
      } else if (diferencia.abs() <= alineada) {
        nueva = 1;
      }
      if (nueva != actual) {
        _velocidades[pista] = nueva;
        await pista.velocidad(nueva);
      }
    }
  }

  /// Libera los reproductores del sistema.
  Future<void> liberar() async {
    _sonando = false;
    await Future.wait(pistas.map((PistaAudio p) => p.liberar()));
  }
}
