import 'package:flutter/material.dart';

import '../servicios/cancion.dart';
import '../servicios/cliente_api.dart';

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
    super.key,
  });

  /// Cliente de la API.
  final ClienteApi cliente;

  /// Canción terminada de tipo karaoke.
  final Cancion cancion;

  @override
  State<PantallaKaraoke> createState() => _PantallaKaraokeState();
}

class _PantallaKaraokeState extends State<PantallaKaraoke> {
  final bool _sonando = false;
  final Duration _posicion = Duration.zero;
  final Duration _duracion = Duration.zero;
  int _vozGuia = 30;
  int _semitonos = 0;
  int _desfaseMs = 0;

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
          const PanelLetra(),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              IconButton.filled(
                key: const Key('botonReproducir'),
                tooltip: _sonando ? 'Pausar' : 'Reproducir',
                onPressed: null,
                icon: Icon(_sonando ? Icons.pause : Icons.play_arrow),
              ),
              const SizedBox(width: 8),
              Text(formatoTiempo(_posicion)),
              Expanded(
                child: Slider(
                  key: const Key('barraPosicion'),
                  value: _posicion.inMilliseconds.toDouble().clamp(0, total),
                  max: total == 0 ? 1 : total,
                  onChanged: null,
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
                  onChanged: (double valor) =>
                      setState(() => _vozGuia = valor.round()),
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
                ? () => setState(() => _desfaseMs -= pasoSincronia)
                : null,
            alSubir: _desfaseMs < sincroniaMaxima
                ? () => setState(() => _desfaseMs += pasoSincronia)
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
