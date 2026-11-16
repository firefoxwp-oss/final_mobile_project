import 'dart:async';

import 'package:flutter/material.dart';

import '../servicios/cancion.dart';
import '../servicios/cliente_api.dart';
import '../servicios/servicio_notificaciones.dart';
import 'pantalla_detalle_cancion.dart';
import 'pantalla_inicio_sesion.dart';
import 'pantalla_subida.dart';

/// Lista de las canciones procesadas del usuario (Pb-8).
class PantallaCanciones extends StatefulWidget {
  /// Crea la pantalla «Mis canciones».
  const PantallaCanciones({
    required this.cliente,
    this.notificaciones,
    super.key,
  });

  /// Cliente de la API.
  final ClienteApi cliente;

  /// Notificaciones de finalización, que se desactivan al cerrar sesión.
  final ServicioNotificaciones? notificaciones;

  @override
  State<PantallaCanciones> createState() => _PantallaCancionesState();
}

class _PantallaCancionesState extends State<PantallaCanciones> {
  List<Cancion>? _canciones;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_cargar());
    unawaited(widget.notificaciones?.alTocarNotificacion(_abrirNotificada));
  }

  @override
  void dispose() {
    widget.notificaciones?.quitarAlTocar(_abrirNotificada);
    super.dispose();
  }

  /// Consulta las canciones del usuario en el servidor.
  Future<void> _cargar() async {
    try {
      final List<Cancion> canciones = await widget.cliente.listarCanciones();
      if (!mounted) return;
      setState(() {
        _canciones = canciones;
        _error = null;
      });
    } on ErrorApi catch (e) {
      if (!mounted) return;
      if (e.sesionVencida) {
        await _irAlInicioDeSesion();
        return;
      }
      setState(() => _error = e.mensaje);
    } on Object {
      // Respuesta inesperada del servidor
      if (mounted) {
        setState(() => _error = 'No se pudieron cargar las canciones');
      }
    }
  }

  Future<void> _abrir(Cancion cancion) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          PantallaDetalleCancion(cliente: widget.cliente, cancion: cancion),
    ),
  );

  /// Al tocar la notificación, la canción aparece en la lista actualizada y,
  /// si terminó, se abre su detalle; si falló, su error queda a la vista
  /// (Pb-9).
  Future<void> _abrirNotificada(String id) async {
    await _cargar();
    try {
      final Cancion cancion = await widget.cliente.obtenerTrabajo(id);
      if (mounted && cancion.estado == EstadoCancion.terminada) {
        await _abrir(cancion);
      }
    } on ErrorApi {
      // La lista ya muestra el estado de la canción
    }
  }

  Future<void> _irAlInicioDeSesion() async {
    await Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => PantallaInicioSesion(
          cliente: widget.cliente,
          notificaciones: widget.notificaciones,
        ),
      ),
      (_) => false,
    );
  }

  /// Abre «Subir canción» y, al volver, actualiza la lista (Pb-9).
  Future<void> _subir() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PantallaSubida(cliente: widget.cliente),
      ),
    );
    await _cargar();
  }

  Future<void> _cerrarSesion() async {
    await widget.notificaciones?.cerrarSesion();
    await widget.cliente.cerrarSesion();
    if (!mounted) return;
    await _irAlInicioDeSesion();
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
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('botonSubir'),
        onPressed: _subir,
        icon: const Icon(Icons.upload),
        label: const Text('Subir canción'),
      ),
      body: _canciones == null && _error == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargar,
              child: ListView(
                // Permite deslizar para actualizar aunque la lista sea corta
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: <Widget>[
                  if (_error != null)
                    _Aviso(texto: _error!, color: tema.colorScheme.error),
                  if (_canciones?.isEmpty ?? false)
                    const _Aviso(
                      texto:
                          'Todavía no tienes canciones. Sube una con el botón '
                          '«Subir canción».',
                    ),
                  for (final Cancion cancion in _canciones ?? <Cancion>[])
                    TarjetaCancion(
                      cancion: cancion,
                      alTocar: () => _abrir(cancion),
                    ),
                  const SizedBox(height: 24),
                  Text(
                    'Solo las canciones terminadas se pueden abrir',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: tema.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 72),
                ],
              ),
            ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.texto, this.color});

  final String texto;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Text(
        texto,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 16, color: color),
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
