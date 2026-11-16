import 'package:final_mobile_project/pantallas/pantalla_subida.dart';
import 'package:final_mobile_project/servicios/cliente_api.dart';
import 'package:final_mobile_project/servicios/selector_video.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

VideoElegido _video(
  String nombre, {
  int megas = 48,
  Duration duracion = const Duration(minutes: 3, seconds: 52),
}) => VideoElegido(
  archivo: XFile('/videos/$nombre'),
  nombre: nombre,
  bytes: megas * 1024 * 1024,
  duracion: duracion,
);

/// Galería y cámara simuladas.
class _SelectorFalso implements SelectorVideo {
  _SelectorFalso(this.video);

  final VideoElegido video;

  @override
  Future<VideoElegido?> elegirDeGaleria() async => video;

  @override
  Future<VideoElegido?> grabarConCamara() async => video;
}

Future<void> _abrir(WidgetTester tester, VideoElegido video) =>
    tester.pumpWidget(
      MaterialApp(
        home: PantallaSubida(
          cliente: ClienteApi(),
          selector: _SelectorFalso(video),
        ),
      ),
    );

void main() {
  testWidgets('la pantalla de subida sigue el prototipo de Pb-9', (
    tester,
  ) async {
    await _abrir(tester, _video('mi_cancion.mp4'));

    expect(find.text('Subir canción'), findsOneWidget);
    expect(find.text('Galería'), findsOneWidget);
    expect(find.text('Cámara'), findsOneWidget);
    expect(find.text('Tipo de resultado'), findsOneWidget);
    expect(find.text('Karaoke'), findsOneWidget);
    expect(find.text('Instrumental'), findsOneWidget);
    expect(find.text('Subir'), findsOneWidget);
    expect(
      find.text('Luego podrás seguir su estado en «Mis canciones»'),
      findsOneWidget,
    );
  });

  testWidgets('el video elegido se muestra con su duración y tamaño', (
    tester,
  ) async {
    await _abrir(tester, _video('mi_cancion.mp4'));
    await tester.tap(find.byKey(const Key('botonGaleria')));
    await tester.pump();

    expect(find.text('mi_cancion.mp4'), findsOneWidget);
    expect(find.text('3:52 · 48 MB'), findsOneWidget);
    expect(find.byKey(const Key('mensajeErrorSubida')), findsNothing);
  });

  testWidgets('un archivo no válido se rechaza antes de subirlo', (
    tester,
  ) async {
    await _abrir(tester, _video('documento.pdf'));
    await tester.tap(find.byKey(const Key('botonCamara')));
    await tester.pump();

    expect(find.byKey(const Key('mensajeErrorSubida')), findsOneWidget);
  });

  group('validarVideo', () {
    test('acepta los formatos de la web, incluido el audio MP3', () {
      for (final String nombre in <String>['a.mp4', 'b.MOV', 'c.mp3']) {
        expect(validarVideo(_video(nombre)), isNull);
      }
    });

    test('rechaza un formato no admitido', () {
      expect(validarVideo(_video('foto.jpg')), startsWith('Formato'));
    });

    test('rechaza más de 1 GB', () {
      expect(
        validarVideo(_video('a.mp4', megas: 1025)),
        'El archivo pesa 1025 MB y el máximo es 1024 MB.',
      );
    });

    test('rechaza más de 60 minutos', () {
      expect(
        validarVideo(_video('a.mp4', duracion: const Duration(minutes: 61))),
        'El video dura 61 minutos y el máximo son 60.',
      );
    });
  });
}
