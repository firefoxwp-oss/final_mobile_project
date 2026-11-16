import 'package:flutter/material.dart';

import '../servicios/cliente_api.dart';
import '../servicios/selector_video.dart';

/// Subida de un video desde el celular y su progreso (Pb-9).
class PantallaSubida extends StatefulWidget {
  /// Crea la pantalla «Subir canción»; [selector] permite reemplazar la
  /// galería y la cámara en las pruebas.
  const PantallaSubida({required this.cliente, this.selector, super.key});

  /// Cliente de la API.
  final ClienteApi cliente;

  /// Origen del video; por defecto, los archivos y la cámara del celular.
  final SelectorVideo? selector;

  @override
  State<PantallaSubida> createState() => _PantallaSubidaState();
}

class _PantallaSubidaState extends State<PantallaSubida> {
  VideoElegido? _video;
  String _tipo = 'karaoke';
  double? _avance;
  String? _error;

  late final SelectorVideo _selector =
      widget.selector ?? SelectorVideoDispositivo();

  /// elegirVideo(galería o cámara) y validar(archivo), según la secuencia
  /// de Pb-9: un archivo no válido se rechaza antes de subirlo.
  Future<void> _elegir(Future<VideoElegido?> Function() origen) async {
    final VideoElegido? video;
    try {
      video = await origen();
    } on Object {
      if (mounted) setState(() => _error = 'No se pudo abrir el archivo.');
      return;
    }
    if (video == null || !mounted) return;
    final VideoElegido elegido = video;
    setState(() {
      _video = elegido;
      _error = validarVideo(elegido);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    final VideoElegido? video = _video;
    final double? avance = _avance;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subir canción'),
        backgroundColor: tema.colorScheme.surfaceContainerHighest,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('botonGaleria'),
                  onPressed: () => _elegir(_selector.elegirDeGaleria),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Galería'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('botonCamara'),
                  onPressed: () => _elegir(_selector.grabarConCamara),
                  icon: const Icon(Icons.videocam_outlined),
                  label: const Text('Cámara'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (video != null) _TarjetaVideo(video: video),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                key: const Key('mensajeErrorSubida'),
                style: TextStyle(color: tema.colorScheme.error),
              ),
            ),
          const SizedBox(height: 24),
          Text(
            'Tipo de resultado',
            style: tema.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          RadioGroup<String>(
            groupValue: _tipo,
            onChanged: (String? valor) =>
                setState(() => _tipo = valor ?? 'karaoke'),
            child: const Column(
              children: <Widget>[
                RadioListTile<String>(
                  title: Text('Karaoke'),
                  value: 'karaoke',
                  contentPadding: EdgeInsets.zero,
                ),
                RadioListTile<String>(
                  title: Text('Instrumental'),
                  value: 'instrumental',
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('botonSubirVideo'),
            onPressed: null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: const Text('Subir'),
          ),
          if (avance != null) ...<Widget>[
            const SizedBox(height: 24),
            Text(
              'Subiendo… ${(avance * 100).round()} %',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: avance, minHeight: 8),
          ],
          const SizedBox(height: 32),
          Text(
            'Luego podrás seguir su estado en «Mis canciones»',
            textAlign: TextAlign.center,
            style: TextStyle(color: tema.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta del video elegido, según el prototipo de Pb-9.
class _TarjetaVideo extends StatelessWidget {
  const _TarjetaVideo({required this.video});

  final VideoElegido video;

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: tema.colorScheme.outline),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: tema.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.play_arrow,
            color: tema.colorScheme.onSurfaceVariant,
          ),
        ),
        title: Text(
          video.nombre,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(video.detalle),
      ),
    );
  }
}
