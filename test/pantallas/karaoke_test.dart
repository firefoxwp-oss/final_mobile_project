import 'package:final_mobile_project/pantallas/pantalla_karaoke.dart';
import 'package:final_mobile_project/servicios/cancion.dart';
import 'package:final_mobile_project/servicios/cliente_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final Cancion _cancion = Cancion.desdeJson(<String, dynamic>{
  'id': 'abc',
  'source_filename': 'mi_cancion.mp4',
  'status': 'done',
  'progress': 100,
  'duration_seconds': 225,
  'video_type': 'karaoke',
});

Future<void> _abrir(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(400, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: PantallaKaraoke(
        cliente: ClienteApi(url: 'https://api.prueba'),
        cancion: _cancion,
      ),
    ),
  );
}

void main() {
  testWidgets('muestra los elementos del prototipo de Pb-10', (tester) async {
    await _abrir(tester);

    expect(find.text('Modo Karaoke'), findsOneWidget);
    expect(find.text('mi_cancion.mp4'), findsOneWidget);
    expect(find.byKey(const Key('panelLetra')), findsOneWidget);
    expect(find.byKey(const Key('botonReproducir')), findsOneWidget);
    expect(find.text('Voz guía'), findsOneWidget);
    expect(find.text('30 %'), findsOneWidget);
    expect(find.text('Tono'), findsOneWidget);
    expect(find.text('Original'), findsOneWidget);
    expect(find.text('Sincronía'), findsOneWidget);
    expect(find.text('0 ms'), findsOneWidget);
    expect(find.text('Grabar'), findsOneWidget);
  });

  testWidgets('el tono va de −6 a +6 semitonos', (tester) async {
    await _abrir(tester);
    final Finder subir = find.byTooltip('Subir Tono');
    final Finder bajar = find.byTooltip('Bajar Tono');

    for (int i = 0; i < 8; i++) {
      await tester.tap(subir);
      await tester.pump();
    }
    expect(find.text('+6'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.ancestor(of: subir, matching: find.byType(IconButton)),
          )
          .onPressed,
      isNull,
    );

    for (int i = 0; i < 14; i++) {
      await tester.tap(bajar);
      await tester.pump();
    }
    expect(find.text('−6'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.ancestor(of: bajar, matching: find.byType(IconButton)),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('la sincronía cambia en pasos de 50 ms', (tester) async {
    await _abrir(tester);

    await tester.tap(find.byTooltip('Subir Sincronía'));
    await tester.pump();
    expect(find.text('50 ms'), findsOneWidget);

    await tester.tap(find.byTooltip('Bajar Sincronía'));
    await tester.tap(find.byTooltip('Bajar Sincronía'));
    await tester.pump();
    expect(find.text('-50 ms'), findsOneWidget);
  });

  testWidgets('el panel resalta la parte ya cantada', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PanelLetra(
          anterior: 'y la noche nos volvió a encontrar',
          cantado: 'cantando bajo ',
          pendiente: 'la luz de la ciudad',
          siguiente: 'hasta que el sol vuelva a salir',
        ),
      ),
    );

    final RichText linea = tester.widget<RichText>(
      find.descendant(
        of: find.byKey(const Key('lineaActual')),
        matching: find.byType(RichText),
      ),
    );
    TextSpan? cantado;
    linea.text.visitChildren((InlineSpan parte) {
      if (parte is TextSpan && parte.text == 'cantando bajo ') cantado = parte;
      return true;
    });
    expect(cantado, isNotNull);
    expect(cantado!.style?.color, PanelLetra.colorCantado);
  });

  test('formatoTiempo muestra minutos y segundos', () {
    expect(formatoTiempo(const Duration(minutes: 3, seconds: 45)), '3:45');
    expect(formatoTiempo(const Duration(seconds: 62)), '1:02');
  });
}
