import 'dart:async';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../datos/almacen_grabaciones.dart';
import '../datos/configuracion_karaoke.dart';
import '../datos/grabacion.dart';
import '../servicios/cancion.dart';
import '../servicios/cliente_api.dart';
import '../servicios/grabador_voz.dart';
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

/// Estado de la grabación de la interpretación (Pb-13).
enum EstadoGrabacion {
  /// No se está grabando.
  ninguna,

  /// Se graba la voz mientras suena el instrumental.
  grabando,

  /// Terminó la grabación: se puede escuchar, guardar o descartar.
  terminada,
}

/// Modo Karaoke en el celular (Pb-10), con el cambio de tono (Pb-11) y la
/// grabación de la interpretación (Pb-13), según el prototipo de Pb-10.
class PantallaKaraoke extends StatefulWidget {
  /// Crea el Modo Karaoke de la [cancion].
  const PantallaKaraoke({
    required this.cliente,
    required this.cancion,
    this.crearReproductor,
    this.crearGrabador,
    this.carpetaGrabaciones,
    this.almacenGrabaciones,
    super.key,
  });

  /// Cliente de la API.
  final ClienteApi cliente;

  /// Canción terminada de tipo karaoke.
  final Cancion cancion;

  /// Crea el reproductor del instrumental y la voz guía; en las pruebas se
  /// reemplaza por uno simulado.
  final ReproductorPistas Function()? crearReproductor;

  /// Crea el grabador del micrófono; en las pruebas se reemplaza.
  final GrabadorVoz Function()? crearGrabador;

  /// Carpeta de las grabaciones; por defecto, la de documentos de la
  /// aplicación.
  final Future<Directory> Function()? carpetaGrabaciones;

  /// Grabaciones guardadas en el celular; en las pruebas se reemplaza.
  final AlmacenGrabaciones? almacenGrabaciones;

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
  bool _cambiandoTono = false;
  late final GrabadorVoz _grabador =
      widget.crearGrabador?.call() ?? GrabadorDispositivo();
  EstadoGrabacion _grabacion = EstadoGrabacion.ninguna;
  Duration _tiempoGrabado = Duration.zero;
  String? _rutaVoz;
  late final AlmacenGrabaciones _almacen =
      widget.almacenGrabaciones ?? AlmacenGrabaciones();

  /// Pistas que suenan (instrumental y voz guía), en el tono elegido.
  List<Future<String>> _rutasPistas = <Future<String>>[];

  /// Cronómetro desde que empieza la grabación; con la posición del audio
  /// indica cuándo empezó a sonar la canción en la grabación.
  final Stopwatch _cronometro = Stopwatch();
  final List<int> _iniciosCancion = <int>[];

  bool get _grabando => _grabacion == EstadoGrabacion.grabando;

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
      // La letra y las dos pistas se piden a la vez, y cada pista se carga
      // en el reproductor en cuanto termina de descargarse
      final Future<Letra> pedirLetra = widget.cliente.obtenerLetra(id);
      _rutasPistas = _pedirPistas(configuracion.semitonos);
      final Future<void> cargarPistas = _reproductor.cargar(
        _rutasPistas,
        configuracion: configuracion,
      );
      final Letra letra = await pedirLetra;
      await cargarPistas;
      _reproductor.letra = letra;
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

  /// grabar(): pide el permiso del micrófono y, si se concede, graba la voz
  /// mientras suena la canción desde el inicio (secuencia de Pb-13).
  Future<void> _grabar() async {
    if (!await _grabador.pedirPermisoMicrofono()) {
      if (mounted) await _explicarPermiso();
      return;
    }
    if (_sonando) await _alternar();
    await _descartar();
    final Directory documentos =
        await (widget.carpetaGrabaciones ?? getApplicationDocumentsDirectory)();
    final Directory carpeta = Directory('${documentos.path}/grabaciones');
    await carpeta.create(recursive: true);
    final String ruta =
        '${carpeta.path}/voz_${DateTime.now().millisecondsSinceEpoch}.wav';
    await _reproductor.buscar(Duration.zero);
    await _grabador.iniciar(ruta);
    _cronometro
      ..reset()
      ..start();
    _iniciosCancion.clear();
    setState(() {
      _grabacion = EstadoGrabacion.grabando;
      _tiempoGrabado = Duration.zero;
      _rutaVoz = ruta;
    });
    await _alternar();
  }

  /// detener(): termina la grabación y pausa la canción.
  Future<void> _detener() async {
    if (!_grabando) return;
    final String? ruta = await _grabador.detener();
    if (_sonando) await _alternar();
    if (ruta != null) {
      // La voz se canta al oír la canción: se recorta hasta el momento en que
      // empezó a sonar, con la corrección medida del celular y el retraso de
      // los audífonos, que es el ajuste de sincronía elegido (negativo con
      // audífonos Bluetooth)
      await alinearVoz(
        ruta,
        _inicioCancion() +
            correccionGrabacion -
            Duration(milliseconds: _desfaseMs),
      );
    }
    if (!mounted) return;
    setState(() {
      _grabacion = ruta == null
          ? EstadoGrabacion.ninguna
          : EstadoGrabacion.terminada;
      _rutaVoz = ruta;
    });
  }

  /// Mediana de los momentos en que la canción estuvo en 0, medidos durante
  /// la grabación.
  Duration _inicioCancion() {
    if (_iniciosCancion.isEmpty) return Duration.zero;
    final List<int> ordenados = List<int>.of(_iniciosCancion)..sort();
    return Duration(microseconds: ordenados[ordenados.length ~/ 2]);
  }

  /// guardar(): guarda la grabación con una copia del instrumental que
  /// sonó, en el tono elegido (secuencia de Pb-13).
  Future<void> _guardarGrabacion() async {
    final String? voz = _rutaVoz;
    if (voz == null) return;
    await _detenerVistaPrevia();
    try {
      await _almacen.guardar(
        Grabacion(
          idCancion: widget.cancion.id,
          titulo: widget.cancion.titulo,
          rutaVoz: voz,
          rutaInstrumental: '',
          semitonos: _semitonos,
          vozGuia: _vozGuia,
          duracionSegundos: _tiempoGrabado.inSeconds,
          fecha: DateTime.now(),
        ),
        await _rutasPistas.first,
      );
    } on Object {
      if (mounted) _avisar('No se pudo guardar la grabación.');
      return;
    }
    // La voz ya pertenece a la grabación guardada: no se borra
    _rutaVoz = null;
    if (!mounted) return;
    setState(() => _grabacion = EstadoGrabacion.ninguna);
    _avisar('Grabación guardada en «Mis grabaciones»');
  }

  void _avisar(String mensaje) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(mensaje)));

  ReproductorPistas? _vistaPrevia;

  /// Escucha la grabación terminada antes de guardarla; otro toque la
  /// detiene.
  Future<void> _escucharGrabacion() async {
    final String? voz = _rutaVoz;
    if (voz == null) return;
    final ReproductorPistas? anterior = _vistaPrevia;
    if (anterior != null) {
      _vistaPrevia = null;
      await anterior.liberar();
      return;
    }
    if (_sonando) await _alternar();
    final ReproductorPistas vista =
        widget.crearReproductor?.call() ??
        ReproductorPistas(<PistaAudio>[PistaDispositivo(), PistaDispositivo()]);
    _vistaPrevia = vista;
    await vista.reproducirGrabacion(voz, await _rutasPistas.first);
  }

  Future<void> _detenerVistaPrevia() async {
    final ReproductorPistas? vista = _vistaPrevia;
    _vistaPrevia = null;
    await vista?.liberar();
  }

  /// Descarta la grabación terminada y borra su archivo.
  Future<void> _descartar() async {
    await _detenerVistaPrevia();
    final String? ruta = _rutaVoz;
    _rutaVoz = null;
    if (ruta != null && await File(ruta).exists()) await File(ruta).delete();
    if (mounted) setState(() => _grabacion = EstadoGrabacion.ninguna);
  }

  /// Sin el permiso del micrófono no se graba: se explica cómo concederlo.
  Future<void> _explicarPermiso() => showDialog<void>(
    context: context,
    builder: (BuildContext contexto) => AlertDialog(
      key: const Key('dialogoPermiso'),
      title: const Text('Se necesita el micrófono'),
      content: const Text(
        'Para grabar tu voz, permite el uso del micrófono en Ajustes → '
        'Aplicaciones → Karaoke → Permisos → Micrófono.',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(contexto).pop(),
          child: const Text('Entendido'),
        ),
      ],
    ),
  );

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
      unawaited(_grabando ? _detener() : _alternar());
      return;
    }
    if (_grabando) {
      _tiempoGrabado = posicion;
      // Momento de la grabación en que la canción estuvo en 0; al empezar,
      // la posición del reproductor todavía es una estimación
      if (posicion > const Duration(seconds: 1)) {
        _iniciosCancion.add((_cronometro.elapsed - posicion).inMicroseconds);
      }
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

  /// obtenerPista(job_id, pista, semitonos) del instrumental y la voz guía,
  /// a la vez; la canción se abre en el último tono elegido.
  List<Future<String>> _pedirPistas(int semitonos) => <Future<String>>[
    for (final String pista in pistasKaraoke.keys)
      widget.cliente.obtenerPista(
        widget.cancion.id,
        pista,
        semitonos: semitonos,
      ),
  ];

  /// cambiarTono(semitonos): pide las pistas en el tono nuevo y las cambia
  /// sin mover la canción de su posición (secuencia de Pb-10 y Pb-11).
  Future<void> _cambiarTono(int semitonos) async {
    final int anterior = _semitonos;
    setState(() {
      _semitonos = semitonos;
      _cambiandoTono = true;
    });
    try {
      final List<String> rutas = await Future.wait(_pedirPistas(semitonos));
      await _reproductor.cambiarPistas(rutas, _reproductor.posicion);
      _rutasPistas = <Future<String>>[
        for (final String ruta in rutas) Future<String>.value(ruta),
      ];
      _reproductor.configuracion = _reproductor.configuracion.copiar(
        semitonos: semitonos,
      );
      unawaited(_guardar());
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _semitonos = anterior);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is ErrorApi ? e.mensaje : 'No se pudo cambiar el tono.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _cambiandoTono = false);
    }
  }

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
    if (_grabando) unawaited(_grabador.detener());
    unawaited(_detenerVistaPrevia());
    unawaited(_grabador.liberar());
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
          if (_grabacion == EstadoGrabacion.grabando) ...<Widget>[
            AvisoGrabacion(tiempo: _tiempoGrabado, tono: textoTono(_semitonos)),
            const SizedBox(height: 12),
          ],
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
                onPressed: _cargada && !_grabando ? _alternar : null,
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
                  onChanged: _cargada && !_grabando
                      ? (double valor) => setState(
                          () =>
                              _arrastre = Duration(milliseconds: valor.round()),
                        )
                      : null,
                  onChangeEnd: _cargada && !_grabando ? _mover : null,
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
            alBajar:
                _cargada &&
                    !_cambiandoTono &&
                    !_grabando &&
                    _semitonos > tonoMinimo
                ? () => _cambiarTono(_semitonos - 1)
                : null,
            alSubir:
                _cargada &&
                    !_cambiandoTono &&
                    !_grabando &&
                    _semitonos < tonoMaximo
                ? () => _cambiarTono(_semitonos + 1)
                : null,
          ),
          if (_cambiandoTono)
            Text(
              'Preparando el tono…',
              key: const Key('preparandoTono'),
              textAlign: TextAlign.end,
              style: TextStyle(color: tema.colorScheme.onSurfaceVariant),
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
          if (_grabacion == EstadoGrabacion.grabando) ...<Widget>[
            Text(
              'Usa audífonos para que solo se grabe tu voz',
              textAlign: TextAlign.center,
              style: TextStyle(color: tema.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('botonDetener'),
              onPressed: _detener,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              icon: const Icon(Icons.stop),
              label: const Text('Detener'),
            ),
          ] else
            FilledButton.icon(
              key: const Key('botonGrabar'),
              onPressed: _cargada && !_cambiandoTono ? _grabar : null,
              style: FilledButton.styleFrom(
                backgroundColor: tema.colorScheme.error,
                minimumSize: const Size.fromHeight(52),
              ),
              icon: const Icon(Icons.fiber_manual_record),
              label: const Text('Grabar'),
            ),
          if (_grabacion == EstadoGrabacion.terminada) ...<Widget>[
            const SizedBox(height: 16),
            ResultadoGrabacion(
              titulo: widget.cancion.titulo,
              duracion: _tiempoGrabado,
              alEscuchar: _escucharGrabacion,
              alDescartar: _descartar,
              alGuardar: _guardarGrabacion,
            ),
          ],
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

/// Aviso rojo con el tiempo grabado y el tono, según el prototipo de Pb-13.
class AvisoGrabacion extends StatelessWidget {
  /// Crea el aviso.
  const AvisoGrabacion({required this.tiempo, required this.tono, super.key});

  /// Tiempo grabado hasta ahora.
  final Duration tiempo;

  /// Tono en que se graba.
  final String tono;

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    return Container(
      key: const Key('avisoGrabacion'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tema.colorScheme.errorContainer,
        border: Border.all(color: tema.colorScheme.error),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.fiber_manual_record, color: tema.colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Grabando · ${formatoTiempo(tiempo)}',
              style: TextStyle(
                color: tema.colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Text(tono),
        ],
      ),
    );
  }
}

/// Tarjeta de la grabación terminada: escucharla, descartarla o guardarla.
class ResultadoGrabacion extends StatelessWidget {
  /// Crea la tarjeta.
  const ResultadoGrabacion({
    required this.titulo,
    required this.duracion,
    this.alEscuchar,
    this.alDescartar,
    this.alGuardar,
    super.key,
  });

  /// Nombre de la canción grabada.
  final String titulo;

  /// Duración de la grabación.
  final Duration duracion;

  /// Acción del botón Escuchar.
  final VoidCallback? alEscuchar;

  /// Acción del botón Descartar.
  final VoidCallback? alDescartar;

  /// Acción del botón Guardar.
  final VoidCallback? alGuardar;

  /// Relleno corto: los tres botones caben en una línea en el celular.
  static const EdgeInsets _relleno = EdgeInsets.symmetric(horizontal: 4);

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    return Card(
      key: const Key('resultadoGrabacion'),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: tema.colorScheme.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Grabación terminada',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              '$titulo · ${formatoTiempo(duracion)}',
              style: TextStyle(color: tema.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(padding: _relleno),
                    onPressed: alEscuchar,
                    child: const Text('Escuchar'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(padding: _relleno),
                    onPressed: alDescartar,
                    child: const Text('Descartar'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(padding: _relleno),
                    onPressed: alGuardar,
                    child: const Text('Guardar'),
                  ),
                ),
              ],
            ),
          ],
        ),
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
