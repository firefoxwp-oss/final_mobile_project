import 'package:flutter/material.dart';

import '../datos/grabacion.dart';
import 'pantalla_karaoke.dart';

/// «Mis grabaciones»: interpretaciones guardadas en el celular (Pb-13),
/// según el prototipo de Pb-13.
class PantallaGrabaciones extends StatefulWidget {
  /// Crea la pantalla con las [grabaciones] guardadas.
  const PantallaGrabaciones({required this.grabaciones, super.key});

  /// Grabaciones guardadas, de la más reciente a la más antigua.
  final List<Grabacion> grabaciones;

  @override
  State<PantallaGrabaciones> createState() => _PantallaGrabacionesState();
}

class _PantallaGrabacionesState extends State<PantallaGrabaciones> {
  Grabacion? _actual;

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    final Grabacion? actual = _actual;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis grabaciones'),
        backgroundColor: tema.colorScheme.surfaceContainerHighest,
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: widget.grabaciones.isEmpty
                ? const Center(
                    key: Key('sinGrabaciones'),
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'Todavía no guardaste ninguna grabación. Graba una '
                        'canción desde el Modo Karaoke.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: widget.grabaciones.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (_, int i) => TarjetaGrabacion(
                      grabacion: widget.grabaciones[i],
                      alEscuchar: () =>
                          setState(() => _actual = widget.grabaciones[i]),
                    ),
                  ),
          ),
          if (actual != null) BarraGrabacion(grabacion: actual),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Las grabaciones se guardan solo en el celular',
              textAlign: TextAlign.center,
              style: TextStyle(color: tema.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

/// Texto «Hoy, 21:15» o «02/11» de la fecha de una grabación.
String formatoFecha(DateTime fecha, {DateTime? ahora}) {
  final DateTime hoy = ahora ?? DateTime.now();
  String dos(int n) => n.toString().padLeft(2, '0');
  final String hora = '${dos(fecha.hour)}:${dos(fecha.minute)}';
  final DateTime dia = DateTime(fecha.year, fecha.month, fecha.day);
  final int dias = DateTime(
    hoy.year,
    hoy.month,
    hoy.day,
  ).difference(dia).inDays;
  if (dias == 0) return 'Hoy, $hora';
  if (dias == 1) return 'Ayer, $hora';
  return '${dos(fecha.day)}/${dos(fecha.month)}';
}

/// Grabación de la lista, con su fecha, duración y tono.
class TarjetaGrabacion extends StatelessWidget {
  /// Crea la tarjeta de la [grabacion].
  const TarjetaGrabacion({
    required this.grabacion,
    this.alEscuchar,
    this.alEliminar,
    super.key,
  });

  /// Grabación que se muestra.
  final Grabacion grabacion;

  /// Acción al tocar la grabación.
  final VoidCallback? alEscuchar;

  /// Acción del botón de eliminar.
  final VoidCallback? alEliminar;

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    final String duracion = formatoTiempo(
      Duration(seconds: grabacion.duracionSegundos),
    );
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: tema.colorScheme.outline),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        onTap: alEscuchar,
        leading: CircleAvatar(
          backgroundColor: tema.colorScheme.surfaceContainerHighest,
          child: Icon(
            Icons.play_arrow,
            color: tema.colorScheme.onSurfaceVariant,
          ),
        ),
        title: Text(
          grabacion.titulo,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${formatoFecha(grabacion.fecha)} · $duracion\n${grabacion.tono}',
        ),
        isThreeLine: true,
        trailing: IconButton(
          tooltip: 'Eliminar grabación',
          onPressed: alEliminar,
          icon: const Icon(Icons.close),
        ),
      ),
    );
  }
}

/// Barra inferior con la grabación que se escucha.
class BarraGrabacion extends StatelessWidget {
  /// Crea la barra de la [grabacion].
  const BarraGrabacion({
    required this.grabacion,
    this.sonando = false,
    this.avance = 0,
    this.alAlternar,
    super.key,
  });

  /// Grabación que se escucha.
  final Grabacion grabacion;

  /// Indica si suena.
  final bool sonando;

  /// Avance de 0 a 1.
  final double avance;

  /// Acción del botón reproducir o pausar.
  final VoidCallback? alAlternar;

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    return Container(
      key: const Key('barraGrabacion'),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tema.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          IconButton.filled(
            tooltip: sonando ? 'Pausar' : 'Reproducir',
            onPressed: alAlternar,
            icon: Icon(sonando ? Icons.pause : Icons.play_arrow),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${grabacion.titulo} · ${grabacion.tono}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: avance, minHeight: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
