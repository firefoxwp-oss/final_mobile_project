// Prueba de la aplicación completa contra el servidor real (Sp-23).
//
// Se ejecuta en el celular de pruebas (o en otro dispositivo) con:
//   flutter test integration_test --dart-define=PRUEBA_EMAIL=...
//     --dart-define=PRUEBA_CLAVE=...
// La URL del servidor se toma del .env de la aplicación. La cuenta debe tener
// al menos una canción terminada.
import 'package:final_mobile_project/app.dart';
import 'package:final_mobile_project/configuracion.dart';
import 'package:final_mobile_project/servicios/cliente_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const String _correo = String.fromEnvironment('PRUEBA_EMAIL');
const String _clave = String.fromEnvironment('PRUEBA_CLAVE');

Future<void> _esperar(WidgetTester tester, Finder buscado) async {
  for (int i = 0; i < 100 && buscado.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  expect(buscado, findsWidgets);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(cargarConfiguracion);

  testWidgets('inicio de sesión, lista, detalle y cierre de sesión', (
    tester,
  ) async {
    final ClienteApi cliente = ClienteApi();
    await cliente.cerrarSesion();
    await tester.pumpWidget(KaraokeApp(cliente: cliente));
    await _esperar(tester, find.text('Iniciar sesión'));

    // Pb-7: credenciales incorrectas
    await tester.enterText(find.byKey(const Key('campoCorreo')), _correo);
    await tester.enterText(find.byKey(const Key('campoClave')), 'incorrecta');
    await tester.tap(find.byKey(const Key('botonIngresar')));
    await _esperar(tester, find.text('Correo o contraseña incorrectos'));

    // Pb-7: credenciales correctas llevan a «Mis canciones». El campo se
    // vacia antes, porque en web la escritura simulada se agrega al texto
    await tester.enterText(find.byKey(const Key('campoClave')), '');
    await tester.pump();
    await tester.enterText(find.byKey(const Key('campoClave')), _clave);
    await tester.tap(find.byKey(const Key('botonIngresar')));
    await _esperar(tester, find.textContaining('Terminada'));
    expect(find.text('Mis canciones'), findsOneWidget);

    // Pb-8: actualizar al deslizar
    await tester.fling(
      find.textContaining('Terminada').first,
      const Offset(0, 400),
      1000,
    );
    await tester.pumpAndSettle();
    await _esperar(tester, find.textContaining('Terminada'));

    // Pb-8: abrir el detalle de una canción terminada
    await tester.tap(find.textContaining('Terminada').first);
    await tester.pumpAndSettle();
    expect(find.text('Archivo original'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Pb-7: al reiniciar la app, la sesión sigue activa
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(KaraokeApp(cliente: ClienteApi()));
    await _esperar(tester, find.text('Mis canciones'));

    // Cerrar sesión vuelve al inicio
    await tester.tap(find.byKey(const Key('botonCerrarSesion')));
    await tester.pumpAndSettle();
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });
}
