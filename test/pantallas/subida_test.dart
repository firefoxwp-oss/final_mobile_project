import 'package:final_mobile_project/pantallas/pantalla_subida.dart';
import 'package:final_mobile_project/servicios/cliente_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('la pantalla de subida sigue el prototipo de Pb-9', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: PantallaSubida(cliente: ClienteApi())),
    );

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

  test('la tarjeta muestra la duración y el tamaño del video', () {
    const VideoElegido video = VideoElegido(
      ruta: '/videos/mi_cancion.mp4',
      nombre: 'mi_cancion.mp4',
      bytes: 48 * 1024 * 1024,
      duracion: Duration(minutes: 3, seconds: 52),
    );
    expect(video.detalle, '3:52 · 48 MB');
  });
}
