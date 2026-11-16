import 'package:flutter/material.dart';

import '../servicios/cancion.dart';
import '../servicios/cliente_api.dart';
import 'pantalla_inicio_sesion.dart';

/// Lista de las canciones procesadas del usuario (Pb-8).
class PantallaCanciones extends StatefulWidget {
  /// Crea la pantalla «Mis canciones».
  const PantallaCanciones({required this.cliente, super.key});

  /// Cliente de la API.
  final ClienteApi cliente;

  @override
  State<PantallaCanciones> createState() => _PantallaCancionesState();
}

class _PantallaCancionesState extends State<PantallaCanciones> {
  final List<Cancion> _canciones = <Cancion>[];

  Future<void> _cerrarSesion() async {
    await widget.cliente.cerrarSesion();
    if (!mounted) return;
    await Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => PantallaInicioSesion(cliente: widget.cliente),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis canciones'),
        backgroundColor: tema.colorScheme.surfaceContainerHighest,
        actions: <Widget>[
          IconButton(
            key: const Key('botonCerrarSesion'),
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: _cerrarSesion,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          for (final Cancion cancion in _canciones)
            TarjetaCancion(cancion: cancion),
          const SizedBox(height: 24),
          Text(
            'Solo las canciones terminadas se pueden abrir',
            textAlign: TextAlign.center,
            style: TextStyle(color: tema.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de una canción, según el prototipo de «Mis canciones».
class TarjetaCancion extends StatelessWidget {
  /// Crea la tarjeta de la [cancion]; [alTocar] solo se usa si se puede
  /// abrir.
  const TarjetaCancion({required this.cancion, this.alTocar, super.key});

  /// Canción que se muestra.
  final Cancion cancion;

  /// Acción al tocar una canción terminada.
  final VoidCallback? alTocar;

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    final bool conBarra =
        cancion.estado == EstadoCancion.procesando ||
        cancion.estado == EstadoCancion.enCola;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: tema.colorScheme.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: cancion.sePuedeAbrir ? alTocar : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: tema.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tema.colorScheme.outlineVariant),
                ),
                child: Icon(
                  Icons.music_note,
                  color: tema.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      cancion.titulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tema.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      cancion.detalle,
                      style: TextStyle(
                        color: cancion.estado == EstadoCancion.error
                            ? tema.colorScheme.error
                            : tema.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (conBarra) ...<Widget>[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: cancion.progreso / 100,
                          minHeight: 10,
                          backgroundColor:
                              tema.colorScheme.surfaceContainerHighest,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (cancion.sePuedeAbrir)
                Icon(
                  Icons.chevron_right,
                  color: tema.colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
