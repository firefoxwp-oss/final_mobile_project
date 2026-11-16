import 'dart:async';

import 'package:just_audio/just_audio.dart';

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

  /// Separación máxima entre pistas antes de corregirla; queda dentro del
  /// desfase de 100 ms que se admite para la letra (RR-07).
  static const Duration tolerancia = Duration(milliseconds: 40);

  /// Separación a partir de la cual una pista se considera alineada.
  static const Duration alineada = Duration(milliseconds: 10);

  /// Separación que se corrige con un salto, porque ajustar la velocidad
  /// tardaría demasiado.
  static const Duration salto = Duration(seconds: 2);

  /// Cambio de velocidad para corregir la separación; no altera el tono,
  /// porque Android lo conserva al cambiar la velocidad.
  static const double ajuste = 0.08;

  /// Duración de la canción, conocida al cargarla.
  Duration? duracion;

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

  /// Carga un archivo por pista, en el mismo orden de [pistas].
  Future<void> cargar(List<String> rutas) async {
    final List<Duration?> duraciones = await Future.wait(<Future<Duration?>>[
      for (int i = 0; i < pistas.length; i++) pistas[i].cargar(rutas[i]),
    ]);
    duracion = duraciones.first;
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
        nueva = diferencia.isNegative ? 1 + ajuste : 1 - ajuste;
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
