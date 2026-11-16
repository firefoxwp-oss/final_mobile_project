// Prueba de las notificaciones de finalización en el celular (Pb-4, Sp-6).
//
// 1. En el celular o emulador (con Google Play Services):
//      flutter test integration_test/notificaciones_test.dart
//        --dart-define=PRUEBA_EMAIL=... --dart-define=PRUEBA_CLAVE=...
// 2. Cuando la prueba muestre «esperando la notificación», en el servidor:
//      python -m tests.notificar_prueba <correo>
// La prueba comprueba que la notificación llega con la aplicación abierta y
// que, al cerrar sesión, el celular se elimina del servidor.
import 'dart:async';

import 'package:final_mobile_project/app.dart';
import 'package:final_mobile_project/configuracion.dart';
import 'package:final_mobile_project/servicios/cliente_api.dart';
import 'package:final_mobile_project/servicios/notificaciones_firebase.dart';
import 'package:final_mobile_project/servicios/servicio_notificaciones.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const String _correo = String.fromEnvironment('PRUEBA_EMAIL');
const String _clave = String.fromEnvironment('PRUEBA_CLAVE');

Future<void> _esperar(
  WidgetTester tester,
  bool Function() listo,
  Duration limite,
) async {
  final DateTime fin = DateTime.now().add(limite);
  while (!listo() && DateTime.now().isBefore(fin)) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('la notificación de finalización llega al celular', (
    tester,
  ) async {
    await cargarConfiguracion();
    await Firebase.initializeApp();
    final ClienteApi cliente = ClienteApi();
    await cliente.cerrarSesion();
    final List<RemoteMessage> recibidas = <RemoteMessage>[];
    final StreamSubscription<RemoteMessage> suscripcion = FirebaseMessaging
        .onMessage
        .listen(recibidas.add);
    await tester.pumpWidget(
      KaraokeApp(
        cliente: cliente,
        notificaciones: ServicioNotificaciones(
          cliente: cliente,
          mensajeria: MensajeriaFirebase(),
          mostrador: MostradorLocal(),
        ),
      ),
    );

    await _esperar(
      tester,
      () => find.text('Iniciar sesión').evaluate().isNotEmpty,
      const Duration(seconds: 20),
    );
    await tester.enterText(find.byKey(const Key('campoCorreo')), _correo);
    await tester.enterText(find.byKey(const Key('campoClave')), _clave);
    await tester.tap(find.byKey(const Key('botonIngresar')));
    await _esperar(
      tester,
      () => find.text('Mis canciones').evaluate().isNotEmpty,
      const Duration(seconds: 30),
    );

    debugPrint('PRUEBA: esperando la notificación');
    await _esperar(
      tester,
      () => recibidas.isNotEmpty,
      const Duration(minutes: 3),
    );
    expect(recibidas, isNotEmpty);
    final RemoteMessage mensaje = recibidas.first;
    debugPrint(
      'PRUEBA: recibida a las ${DateTime.now().toUtc().toIso8601String()} '
      '«${mensaje.notification?.title}»',
    );
    expect(mensaje.notification?.title, 'Tu canción está lista');
    expect(mensaje.data['status'], 'done');

    await tester.tap(find.byKey(const Key('botonCerrarSesion')));
    await _esperar(
      tester,
      () => find.text('Iniciar sesión').evaluate().isNotEmpty,
      const Duration(seconds: 20),
    );
    await tester.pump(const Duration(seconds: 5));
    debugPrint('PRUEBA: sesión cerrada');
    await suscripcion.cancel();
  });
}
