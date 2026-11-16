import 'package:final_mobile_project/servicios/reproductor_pistas.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pista simulada: su posición se fija desde la prueba.
class _PistaFalsa implements PistaAudio {
  _PistaFalsa(this.posicion);

  @override
  Duration posicion;
  double nivel = 1;
  double factor = 1;
  bool sonando = false;
  final List<Duration> busquedas = <Duration>[];

  @override
  Future<Duration?> cargar(String ruta) async =>
      const Duration(minutes: 3, seconds: 45);

  @override
  Future<void> reproducir() async => sonando = true;

  @override
  Future<void> pausar() async => sonando = false;

  @override
  Future<void> buscar(Duration destino) async {
    busquedas.add(destino);
    posicion = destino;
  }

  @override
  Future<void> lista() async {}

  @override
  Future<void> volumen(double valor) async => nivel = valor;

  @override
  Future<void> velocidad(double valor) async => factor = valor;

  @override
  Future<void> liberar() async {}
}

void main() {
  test('carga las pistas y conoce la duración de la canción', () async {
    final ReproductorPistas reproductor = ReproductorPistas(<PistaAudio>[
      _PistaFalsa(Duration.zero),
      _PistaFalsa(Duration.zero),
    ]);

    await reproductor.cargar(<String>['instrumental.m4a', 'voz.m4a']);

    expect(reproductor.duracion, const Duration(minutes: 3, seconds: 45));
  });

  test('reproduce y pausa todas las pistas a la vez', () async {
    final _PistaFalsa instrumental = _PistaFalsa(Duration.zero);
    final _PistaFalsa voz = _PistaFalsa(Duration.zero);
    final ReproductorPistas reproductor = ReproductorPistas(<PistaAudio>[
      instrumental,
      voz,
    ]);

    await reproductor.reproducir();
    expect(instrumental.sonando && voz.sonando, isTrue);
    expect(reproductor.sonando, isTrue);

    await reproductor.pausar();
    expect(instrumental.sonando || voz.sonando, isFalse);
  });

  test('acelera la voz atrasada hasta alcanzar al instrumental', () async {
    final _PistaFalsa voz = _PistaFalsa(const Duration(milliseconds: 880));
    final ReproductorPistas reproductor = ReproductorPistas(<PistaAudio>[
      _PistaFalsa(const Duration(seconds: 1)),
      voz,
    ]);
    expect(reproductor.desfaseEntrePistas, const Duration(milliseconds: 120));

    await reproductor.sincronizar();
    // 120 ms se corrigen en 2 s: 6 % más rápido
    expect(voz.factor, closeTo(1.06, 0.0001));

    // Ya alineada, vuelve a la velocidad normal
    voz.posicion = const Duration(milliseconds: 995);
    await reproductor.sincronizar();
    expect(voz.factor, 1);
    expect(voz.busquedas, isEmpty);
  });

  test('frena la voz adelantada', () async {
    final _PistaFalsa voz = _PistaFalsa(const Duration(milliseconds: 1100));
    final ReproductorPistas reproductor = ReproductorPistas(<PistaAudio>[
      _PistaFalsa(const Duration(seconds: 1)),
      voz,
    ]);

    await reproductor.sincronizar();

    expect(voz.factor, closeTo(0.95, 0.0001));
  });

  test('el ajuste de velocidad tiene límites', () {
    expect(ReproductorPistas.ajuste(const Duration(milliseconds: 50)), 0.04);
    expect(ReproductorPistas.ajuste(const Duration(milliseconds: 400)), 0.2);
    expect(ReproductorPistas.ajuste(const Duration(milliseconds: 900)), 0.2);
  });

  test('una separación grande se corrige con un salto', () async {
    final _PistaFalsa voz = _PistaFalsa(const Duration(seconds: 5));
    final ReproductorPistas reproductor = ReproductorPistas(<PistaAudio>[
      _PistaFalsa(const Duration(seconds: 10)),
      voz,
    ]);

    await reproductor.sincronizar();

    expect(voz.busquedas, <Duration>[const Duration(seconds: 10)]);
    expect(reproductor.desfaseEntrePistas, Duration.zero);
  });

  test('no corrige la voz si la separación es tolerable', () async {
    final _PistaFalsa voz = _PistaFalsa(const Duration(milliseconds: 1045));
    final ReproductorPistas reproductor = ReproductorPistas(<PistaAudio>[
      _PistaFalsa(const Duration(seconds: 1)),
      voz,
    ]);

    await reproductor.sincronizar();

    expect(voz.factor, 1);
    expect(voz.busquedas, isEmpty);
  });

  test('al adelantar mientras suena, pausa y vuelve a empezar', () async {
    final _PistaFalsa instrumental = _PistaFalsa(Duration.zero);
    final _PistaFalsa voz = _PistaFalsa(Duration.zero);
    final ReproductorPistas reproductor = ReproductorPistas(<PistaAudio>[
      instrumental,
      voz,
    ]);
    await reproductor.reproducir();

    await reproductor.buscar(const Duration(seconds: 60));

    expect(instrumental.posicion, const Duration(seconds: 60));
    expect(voz.posicion, const Duration(seconds: 60));
    expect(instrumental.sonando && voz.sonando, isTrue);
  });

  test('cambia el volumen solo de la pista indicada', () async {
    final _PistaFalsa instrumental = _PistaFalsa(Duration.zero);
    final _PistaFalsa voz = _PistaFalsa(Duration.zero);
    final ReproductorPistas reproductor = ReproductorPistas(<PistaAudio>[
      instrumental,
      voz,
    ]);

    await reproductor.cambiarVolumen(1, 0.3);

    expect(voz.nivel, 0.3);
    expect(instrumental.nivel, 1);
  });
}
