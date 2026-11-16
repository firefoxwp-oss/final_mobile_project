import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

/// Tamaño máximo de un archivo: 1 GB, el mismo límite de la web y del
/// servidor (RF-05).
const int tamanoMaximo = 1024 * 1024 * 1024;

/// Duración máxima: 60 minutos (RF-05).
const Duration duracionMaxima = Duration(minutes: 60);

/// Formatos admitidos, los mismos que en la web.
const List<String> extensionesPermitidas = <String>[
  'mp4',
  'avi',
  'mkv',
  'mp3',
  'mov',
  'm4v',
  'webm',
];

/// Video (o audio) elegido para subir.
class VideoElegido {
  /// Crea el video elegido.
  const VideoElegido({
    required this.archivo,
    required this.nombre,
    required this.bytes,
    this.duracion,
  });

  /// Archivo en el celular.
  final XFile archivo;

  /// Nombre del archivo.
  final String nombre;

  /// Tamaño en bytes.
  final int bytes;

  /// Duración, si se pudo leer.
  final Duration? duracion;

  /// Texto «3:52 · 48 MB» de la tarjeta.
  String get detalle {
    final String tamano = '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';
    final Duration? d = duracion;
    if (d == null) return tamano;
    final String segundos = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '${d.inMinutes}:$segundos · $tamano';
  }
}

/// Valida el formato, el tamaño y la duración antes de subir (RF-05).
///
/// Devuelve el mensaje para el usuario, o `null` si el archivo es válido.
String? validarVideo(VideoElegido video) {
  final int punto = video.nombre.lastIndexOf('.');
  final String extension = punto == -1
      ? ''
      : video.nombre.substring(punto + 1).toLowerCase();
  if (!extensionesPermitidas.contains(extension)) {
    final String encontrado = extension.isEmpty
        ? 'sin extensión'
        : '.$extension';
    final String admitidos = extensionesPermitidas
        .map((String e) => '.$e')
        .join(', ');
    return 'Formato no admitido ($encontrado). Admitidos: $admitidos.';
  }
  if (video.bytes == 0) return 'El archivo está vacío.';
  if (video.bytes > tamanoMaximo) {
    return 'El archivo pesa ${video.bytes ~/ (1024 * 1024)} MB y el máximo '
        'es ${tamanoMaximo ~/ (1024 * 1024)} MB.';
  }
  final Duration? duracion = video.duracion;
  if (duracion != null && duracion > duracionMaxima) {
    return 'El video dura ${duracion.inMinutes} minutos y el máximo son '
        '${duracionMaxima.inMinutes}.';
  }
  return null;
}

/// Origen del video que se sube (Pb-9).
abstract interface class SelectorVideo {
  /// Elige un video o un audio guardado en el celular.
  Future<VideoElegido?> elegirDeGaleria();

  /// Graba un video con la cámara.
  Future<VideoElegido?> grabarConCamara();
}

/// Selector con el explorador de archivos y la cámara del celular.
class SelectorVideoDispositivo implements SelectorVideo {
  @override
  Future<VideoElegido?> elegirDeGaleria() async {
    final List<PlatformFile> archivos = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensionesPermitidas,
    );
    if (archivos.isEmpty) return null;
    final PlatformFile elegido = archivos.first;
    final XFile archivo = elegido.xFile;
    return VideoElegido(
      archivo: archivo,
      nombre: elegido.name,
      bytes: elegido.lengthSync() ?? await elegido.length() ?? 0,
      duracion: await _duracion(elegido.uri),
    );
  }

  @override
  Future<VideoElegido?> grabarConCamara() async {
    final XFile? archivo = await ImagePicker().pickVideo(
      source: ImageSource.camera,
      maxDuration: duracionMaxima,
    );
    if (archivo == null) return null;
    return VideoElegido(
      archivo: archivo,
      nombre: archivo.name,
      bytes: await archivo.length(),
      duracion: await _duracion(Uri.file(archivo.path)),
    );
  }

  /// Lee la duración con el reproductor del sistema; si no se puede leer,
  /// la validación queda a cargo del servidor.
  Future<Duration?> _duracion(Uri uri) async {
    final VideoPlayerController controlador = uri.scheme == 'file'
        ? VideoPlayerController.file(File(uri.toFilePath()))
        : VideoPlayerController.contentUri(uri);
    try {
      await controlador.initialize().timeout(const Duration(seconds: 10));
      return controlador.value.duration;
    } on Object {
      return null;
    } finally {
      await controlador.dispose();
    }
  }
}
