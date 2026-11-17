import 'package:final_mobile_project/servicios/cancion.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _trabajo(Map<String, dynamic> campos) => <String, dynamic>{
  'id': 'j1',
  'source_filename': 'Mi canción.mp4',
  'status': 'done',
  'progress': 100,
  ...campos,
};

void main() {
  test('crea la canción a partir de un trabajo de la API', () {
    final Cancion cancion = Cancion.desdeJson(
      _trabajo(<String, dynamic>{
        'duration_seconds': 225,
        'video_type': 'karaoke',
        'separation_model': 'demucs',
      }),
    );

    expect(cancion.titulo, 'Mi canción');
    expect(cancion.estado, EstadoCancion.terminada);
    expect(cancion.duracion, '3:45');
    expect(cancion.modeloSeparacion, 'demucs');
  });

  test('cada estado tiene su línea de detalle', () {
    String detalle(Map<String, dynamic> campos) =>
        Cancion.desdeJson(_trabajo(campos)).detalle;

    expect(
      detalle(<String, dynamic>{'duration_seconds': 250}),
      'Terminada · 4:10',
    );
    expect(
      detalle(<String, dynamic>{'status': 'running', 'progress': 45}),
      'Procesando · 45 %',
    );
    expect(
      detalle(<String, dynamic>{
        'status': 'queued',
        'progress': 0,
        'queue_position': 2,
      }),
      'En cola · posición 2',
    );
    expect(detalle(<String, dynamic>{'status': 'cancelled'}), 'Cancelada');
    expect(
      detalle(<String, dynamic>{'status': 'error'}),
      'Error en el procesamiento',
    );
  });

  test('solo las canciones terminadas se pueden abrir', () {
    bool abre(String estado) => Cancion.desdeJson(
      _trabajo(<String, dynamic>{'status': estado}),
    ).sePuedeAbrir;

    expect(abre('done'), isTrue);
    for (final String estado in <String>[
      'queued',
      'running',
      'error',
      'cancelled',
    ]) {
      expect(abre(estado), isFalse, reason: estado);
    }
  });
}
