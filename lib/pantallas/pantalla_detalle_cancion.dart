import 'package:flutter/material.dart';

import '../servicios/cancion.dart';
import '../servicios/cliente_api.dart';
import 'pantalla_karaoke.dart';

/// Detalle de una canción terminada (Pb-8).
class PantallaDetalleCancion extends StatelessWidget {
  /// Crea el detalle de la [cancion].
  const PantallaDetalleCancion({
    required this.cliente,
    required this.cancion,
    super.key,
  });

  /// Cliente de la API, para el Modo Karaoke.
  final ClienteApi cliente;

  /// Canción terminada que se muestra.
  final Cancion cancion;

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    final String tipo = cancion.tipoVideo == 'karaoke'
        ? 'Karaoke'
        : 'Instrumental';
    final String? modelo = switch (cancion.modeloSeparacion) {
      'demucs' => 'Demucs v4',
      'spleeter' => 'Spleeter',
      _ => null,
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(cancion.titulo, overflow: TextOverflow.ellipsis),
        backgroundColor: tema.colorScheme.surfaceContainerHighest,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          Center(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: tema.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.music_note,
                size: 56,
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            cancion.titulo,
            textAlign: TextAlign.center,
            style: tema.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          _Dato(icono: Icons.movie_outlined, etiqueta: 'Tipo', valor: tipo),
          if (cancion.duracion != null)
            _Dato(
              icono: Icons.schedule,
              etiqueta: 'Duración',
              valor: cancion.duracion!,
            ),
          if (modelo != null)
            _Dato(
              icono: Icons.graphic_eq,
              etiqueta: 'Separación de la voz',
              valor: modelo,
            ),
          _Dato(
            icono: Icons.insert_drive_file_outlined,
            etiqueta: 'Archivo original',
            valor: cancion.nombreArchivo,
          ),
          // El Modo Karaoke se abre solo para las canciones de tipo karaoke
          if (cancion.tipoVideo == 'karaoke') ...<Widget>[
            const SizedBox(height: 24),
            FilledButton.icon(
              key: const Key('botonCantar'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      PantallaKaraoke(cliente: cliente, cancion: cancion),
                ),
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              icon: const Icon(Icons.mic),
              label: const Text('Cantar'),
            ),
          ],
        ],
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({
    required this.icono,
    required this.etiqueta,
    required this.valor,
  });

  final IconData icono;
  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icono),
      title: Text(etiqueta),
      subtitle: Text(valor),
    );
  }
}
