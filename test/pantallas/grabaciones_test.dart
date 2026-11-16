import 'package:final_mobile_project/datos/grabacion.dart';
import 'package:final_mobile_project/pantallas/pantalla_grabaciones.dart';
import 'package:final_mobile_project/pantallas/pantalla_karaoke.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Grabacion _grabacion(String titulo, int semitonos, DateTime fecha) => Grabacion(
  idCancion: 'abc',
  titulo: titulo,
  rutaVoz: 'voz.m4a',
  rutaInstrumental: 'instrumental.m4a',
  semitonos: semitonos,
  vozGuia: 30,
  duracionSegundos: 225,
  fecha: fecha,
);

void main() {
  testWidgets('muestra las grabaciones del prototipo de Pb-13', (tester) async {
    final DateTime ahora = DateTime.now();
    await tester.pumpWidget(
      MaterialApp(
        home: PantallaGrabaciones(
          grabaciones: <Grabacion>[
            _grabacion('mi_cancion', 2, ahora),
            _grabacion('40 y 20', 0, ahora.subtract(const Duration(days: 1))),
          ],
        ),
      ),
    );

    expect(find.text('Mis grabaciones'), findsOneWidget);
    expect(find.text('mi_cancion'), findsOneWidget);
    expect(find.textContaining('Tono +2'), findsOneWidget);
    expect(find.textContaining('Tono original'), findsOneWidget);
    expect(find.textContaining('3:45'), findsNWidgets(2));
    expect(
      find.text('Las grabaciones se guardan solo en el celular'),
      findsOneWidget,
    );

    await tester.tap(find.text('mi_cancion'));
    await tester.pump();
    expect(find.byKey(const Key('barraGrabacion')), findsOneWidget);
    expect(find.text('mi_cancion · Tono +2'), findsOneWidget);
  });

  testWidgets('sin grabaciones explica cómo grabar', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: PantallaGrabaciones(grabaciones: <Grabacion>[])),
    );

    expect(find.byKey(const Key('sinGrabaciones')), findsOneWidget);
  });

  testWidgets('el aviso y la tarjeta de la grabación', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: <Widget>[
              AvisoGrabacion(tiempo: Duration(seconds: 42), tono: 'Tono +2'),
              ResultadoGrabacion(
                titulo: 'mi_cancion',
                duracion: Duration(minutes: 3, seconds: 45),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Grabando · 0:42'), findsOneWidget);
    expect(find.text('Tono +2'), findsOneWidget);
    expect(find.text('Grabación terminada'), findsOneWidget);
    expect(find.text('mi_cancion · 3:45'), findsOneWidget);
    for (final String boton in <String>['Escuchar', 'Descartar', 'Guardar']) {
      expect(find.text(boton), findsOneWidget);
    }
  });

  test('la fecha dice hoy, ayer o el día', () {
    final DateTime ahora = DateTime(2026, 11, 16, 22);
    expect(
      formatoFecha(DateTime(2026, 11, 16, 21, 15), ahora: ahora),
      'Hoy, 21:15',
    );
    expect(
      formatoFecha(DateTime(2026, 11, 15, 19, 40), ahora: ahora),
      'Ayer, 19:40',
    );
    expect(formatoFecha(DateTime(2026, 11, 2, 10), ahora: ahora), '02/11');
  });

  test('el tono de la grabación', () {
    expect(_grabacion('a', -1, DateTime(2026)).tono, 'Tono −1');
    expect(_grabacion('a', 0, DateTime(2026)).tono, 'Tono original');
  });
}
