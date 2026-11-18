import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'configuracion.dart';
import 'servicios/cliente_api.dart';
import 'servicios/notificaciones_firebase.dart';
import 'servicios/servicio_notificaciones.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await cargarConfiguracion();
  // En iOS no hay notificaciones push: requieren la cuenta de pago de Apple
  final bool conNotificaciones = defaultTargetPlatform != TargetPlatform.iOS;
  MensajeriaPush mensajeria = const SinNotificaciones();
  MostradorNotificaciones mostrador = const SinNotificaciones();
  if (conNotificaciones) {
    // Lee android/app/google-services.json
    await Firebase.initializeApp();
    mensajeria = MensajeriaFirebase();
    mostrador = MostradorLocal();
  }
  final ClienteApi cliente = ClienteApi();
  runApp(
    KaraokeApp(
      cliente: cliente,
      notificaciones: ServicioNotificaciones(
        cliente: cliente,
        mensajeria: mensajeria,
        mostrador: mostrador,
      ),
    ),
  );
}
