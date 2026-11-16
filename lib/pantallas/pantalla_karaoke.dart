import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../datos/configuracion_karaoke.dart';
import '../servicios/cancion.dart';
import '../servicios/cliente_api.dart';
import '../servicios/letra.dart';
import '../servicios/reproductor_pistas.dart';

/// Rango del cambio de tono, en semitonos (RI-05).
const int tonoMinimo = -6;

/// Rango del cambio de tono, en semitonos (RI-05).
const int tonoMaximo = 6;

/// Paso del ajuste de sincronía de la letra, en milisegundos.
const int pasoSincronia = 50;

/// Ajuste máximo de la sincronía, hacia adelante o hacia atrás.
const int sincroniaMaxima = 500;

/// Modo Karaoke en el celular (Pb-10), con el cambio de tono (Pb-11) y la
/// grabación de la interpretación (Pb-13), según el prototipo de Pb-10.
class PantallaKaraoke extends StatefulWidget {
  /// Crea el Modo Karaoke de la [cancion].
  const PantallaKaraoke({
    required this.cliente,
    required this.cancion,
    this.crearReproductor,
    super.key,
  });

  /// Cliente de la API.
  final ClienteApi cliente;

  /// Canción terminada de tipo karaoke.
  final Cancion cancion;

  /// Crea el reproductor del instrumental y la voz guía; en las pruebas se
  /// reemplaza por uno simulado.
  final ReproductorPistas Function()? crearReproductor;

  @override
  State<PantallaKaraoke> createState() => _PantallaKaraokeState();
}

class _PantallaKaraokeState extends State<PantallaKaraoke> {
  /// Cada cuánto se actualiza la palabra resaltada.
  static const Duration _cuadro = Duration(milliseconds: 40);

  /// Cada cuánto se corrige la separación entre las pistas.
  static const int _cuadrosPorSincronia = 6;

  late final ReproductorPistas _reproductor =
      widget.crearReproductor?.call() ??
      ReproductorPistas(<PistaAudio>[PistaDispositivo(), PistaDispositivo()]);
  Timer? _reloj;
  int _cuadros = 0;
  bool _cargada = false;
  String? _error;
  Duration _posicion = Duration.zero;
  Duration _duracion = Duration.zero;
  Duration? _arrastre;
  LetraResaltada _letra = const LetraResaltada();
  int _vozGuia = 30;
  int _semitonos = 0;
  int _desfaseMs = 0;

  bool get _sonando => _reproductor.sonando;

  @override
  void initState() {
    super.initState();
    unawaited(_cargar());
  }

  /// abrir(cancion): obtiene la letra y las pistas y las carga en el
  /// reproductor (secuencia de Pb-10).
  Future<void> _cargar() async {
    final String id = widget.cancion.id;
    try {
      final ConfiguracionKaraoke configuracion =
          await ConfiguracionKaraoke.leer(id);
      if (mounted) {
        setState(() {
          _vozGuia = configuracion.vozGuia;
          _desfaseMs = configuracion.desfaseMs;
          _semitonos = configuracion.semitonos;
        });
      }
      final Letra letra = await widget.cliente.obtenerLetra(id);
      final List<String> rutas = await Future.wait(<Future<String>>[
        widget.cliente.obtenerPista(id, 'instrumental'),
        widget.cliente.obtenerPista(id, 'voz'),
      ]);
      await _reproductor.cargar(
        rutas,
        letra: letra,
        configuracion: configuracion,
      );
      if (!mounted) return;
      setState(() {
        _cargada = true;
        _duracion = _reproductor.duracion ?? Duration.zero;
        _letra = _reproductor.resaltarPalabra(Duration.zero);
      });
    } on ErrorApi catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } on Object {
      if (mounted) setState(() => _error = 'No se pudo cargar la canción.');
    }
  }

  Future<void> _alternar() async {
    if (_sonando) {
      _reloj?.cancel();
      await _reproductor.pausar();
      unawaited(_mantenerPantalla(encendida: false));
    } else {
      if (_posicion >= _duracion) await _reproductor.buscar(Duration.zero);
      await _reproductor.reproducir();
      _reloj = Timer.periodic(_cuadro, (_) => _actualizar());
      unawaited(_mantenerPantalla(encendida: true));
    }
    if (mounted) setState(() {});
  }

  /// La pantalla no se apaga mientras suena la canción; si el sistema no lo
  /// permite, la canción sigue sonando igual.
  Future<void> _mantenerPantalla({required bool encendida}) async {
    try {
      await WakelockPlus.toggle(enable: encendida);
    } on Object {
      return;
    }
  }

  /// resaltarPalabra(posicionAudio + desfase), mientras suena la canción.
  void _actualizar() {
    final Duration posicion = _reproductor.posicion;
    if (++_cuadros % _cuadrosPorSincronia == 0) {
      unawaited(_reproductor.sincronizar());
    }
    if (_duracion > Duration.zero && posicion >= _duracion) {
      unawaited(_alternar());
      return;
    }
    final LetraResaltada letra = _reproductor.resaltarPalabra(posicion);
    // La barra avanza cada 250 ms; la letra, en cuanto cambia una palabra
    if (letra != _letra ||
        posicion.inMilliseconds ~/ 250 != _posicion.inMilliseconds ~/ 250) {
      setState(() {
        _posicion = posicion;
        _letra = letra;
      });
    }
  }

  /// Recuerda la voz guía, la sincronía y el tono en el celular.
  Future<void> _guardar() =>
      _reproductor.configuracion.guardar(widget.cancion.id);

  /// Mueve la letra respecto del audio y la vuelve a resaltar enseguida.
  void _cambiarSincronia(int desfaseMs) {
    _reproductor.configuracion = _reproductor.configuracion.copiar(
      desfaseMs: desfaseMs,
    );
    setState(() {
      _desfaseMs = desfaseMs;
      _letra = _reproductor.resaltarPalabra(_reproductor.posicion);
    });
    unawaited(_guardar());
  }

  Future<void> _mover(double milisegundos) async {
    final Duration destino = Duration(milliseconds: milisegundos.round());
    setState(() => _arrastre = null);
    await _reproductor.buscar(destino);
    if (mounted) {
      setState(() {
        _posicion = destino;
        _letra = _reproductor.resaltarPalabra(destino);
      });
    }
  }

  @override
  void dispose() {
    _reloj?.cancel();
    unawaited(_mantenerPantalla(encendida: false));
    unawaited(_reproductor.liberar());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    final double total = _duracion.inMilliseconds.toDouble();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modo Karaoke'),
        backgroundColor: tema.colorScheme.surfaceContainerHighest,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          Text(
            widget.cancion.nombreArchivo,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: tema.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          if (_error != null)
            Container(
              key: const Key('errorKaraoke'),
              height: 200,
              alignment: Alignment.center,
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: tema.colorScheme.error),
              ),
            )
          else if (!_cargada)
            const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            )
          else
            PanelLetra(
              anterior: _letra.anterior,
              cantado: _letra.cantado,
              pendiente: _letra.pendiente,
              siguiente: _letra.siguiente,
            ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              IconButton.filled(
                key: const Key('botonReproducir'),
                tooltip: _sonando ? 'Pausar' : 'Reproducir',
                onPressed: _cargada ? _alternar : null,
                icon: Icon(_sonando ? Icons.pause : Icons.play_arrow),
              ),
              const SizedBox(width: 8),
              Text(formatoTiempo(_arrastre ?? _posicion)),
              Expanded(
                child: Slider(
                  key: const Key('barraPosicion'),
                  value: (_arrastre ?? _posicion).inMilliseconds
                      .toDouble()
                      .clamp(0, total),
                  max: total == 0 ? 1 : total,
                  onChanged: _cargada
                      ? (double valor) => setState(
                          () =>
                              _arrastre = Duration(milliseconds: valor.round()),
                        )
                      : null,
                  onChangeEnd: _cargada ? _mover : null,
                ),
              ),
              Text(formatoTiempo(_duracion)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              const SizedBox(
                width: 96,
                child: Text(
                  'Voz guía',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: Slider(
                  key: const Key('controlVozGuia'),
                  value: _vozGuia.toDouble(),
                  max: 100,
                  divisions: 20,
                  label: '$_vozGuia %',
                  onChanged: (double valor) {
                    setState(() => _vozGuia = valor.round());
                    unawaited(_reproductor.cambiarVolumenVoz(_vozGuia));
                  },
                  onChangeEnd: (_) => unawaited(_guardar()),
                ),
              ),
              SizedBox(width: 48, child: Text('$_vozGuia %')),
            ],
          ),
          ControlPaso(
            key: const Key('controlTono'),
            etiqueta: 'Tono',
            valor: _semitonos == 0
                ? 'Original'
                : (_semitonos > 0 ? '+$_semitonos' : '−${-_semitonos}'),
            alBajar: _semitonos > tonoMinimo
                ? () => setState(() => _semitonos--)
                : null,
            alSubir: _semitonos < tonoMaximo
                ? () => setState(() => _semitonos++)
                : null,
          ),
          ControlPaso(
            key: const Key('controlSincronia'),
            etiqueta: 'Sincronía',
            valor: '$_desfaseMs ms',
            alBajar: _desfaseMs > -sincroniaMaxima
                ? () => _cambiarSincronia(_desfaseMs - pasoSincronia)
                : null,
            alSubir: _desfaseMs < sincroniaMaxima
                ? () => _cambiarSincronia(_desfaseMs + pasoSincronia)
                : null,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            key: const Key('botonGrabar'),
            onPressed: null,
            style: FilledButton.styleFrom(
              backgroundColor: tema.colorScheme.error,
              minimumSize: const Size.fromHeight(52),
            ),
            icon: const Icon(Icons.fiber_manual_record),
            label: const Text('Grabar'),
          ),
          const SizedBox(height: 24),
          Text(
            'La palabra resaltada sigue la posición del audio',
            textAlign: TextAlign.center,
            style: TextStyle(color: tema.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Texto «m:ss» de una posición o duración.
String formatoTiempo(Duration tiempo) {
  final String segundos = (tiempo.inSeconds % 60).toString().padLeft(2, '0');
  return '${tiempo.inMinutes}:$segundos';
}

/// Panel oscuro con la línea anterior, la actual (la parte ya cantada,
/// resaltada) y la siguiente.
class PanelLetra extends StatelessWidget {
  /// Crea el panel; sin letra muestra un aviso.
  const PanelLetra({
    this.anterior = '',
    this.cantado = '',
    this.pendiente = '',
    this.siguiente = '',
    super.key,
  });

  /// Línea que ya se cantó.
  final String anterior;

  /// Parte de la línea actual que ya se cantó.
  final String cantado;

  /// Parte de la línea actual que falta cantar.
  final String pendiente;

  /// Línea que sigue.
  final String siguiente;

  /// Color de las palabras ya cantadas.
  static const Color colorCantado = Color(0xFF5AAAEB);

  @override
  Widget build(BuildContext context) {
    const TextStyle tenue = TextStyle(color: Color(0xFF969696), fontSize: 14);
    const TextStyle actual = TextStyle(
      color: Colors.white,
      fontSize: 22,
      fontWeight: FontWeight.bold,
    );
    return Container(
      key: const Key('panelLetra'),
      height: 200,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          Text(anterior, textAlign: TextAlign.center, style: tenue),
          Text.rich(
            key: const Key('lineaActual'),
            TextSpan(
              children: <TextSpan>[
                TextSpan(
                  text: cantado,
                  style: actual.copyWith(color: colorCantado),
                ),
                TextSpan(text: pendiente),
              ],
            ),
            textAlign: TextAlign.center,
            style: actual,
          ),
          Text(siguiente, textAlign: TextAlign.center, style: tenue),
        ],
      ),
    );
  }
}

/// Control con los botones − y + y el valor en el centro, como el del tono
/// y el de la sincronía del prototipo.
class ControlPaso extends StatelessWidget {
  /// Crea el control; un botón sin acción queda desactivado.
  const ControlPaso({
    required this.etiqueta,
    required this.valor,
    this.alBajar,
    this.alSubir,
    super.key,
  });

  /// Nombre del control.
  final String etiqueta;

  /// Valor actual, ya con su formato.
  final String valor;

  /// Acción del botón −.
  final VoidCallback? alBajar;

  /// Acción del botón +.
  final VoidCallback? alSubir;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              etiqueta,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          IconButton.outlined(
            tooltip: 'Bajar $etiqueta',
            onPressed: alBajar,
            icon: const Icon(Icons.remove),
          ),
          SizedBox(
            width: 80,
            child: Text(
              valor,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          IconButton.outlined(
            tooltip: 'Subir $etiqueta',
            onPressed: alSubir,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
