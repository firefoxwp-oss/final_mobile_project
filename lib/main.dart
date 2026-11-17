import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'configuracion.dart';
import 'servicios/cliente_api.dart';
import 'servicios/notificaciones_firebase.dart';
import 'servicios/servicio_notificaciones.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await cargarConfiguracion();
  // Lee android/app/google-services.json
  await Firebase.initializeApp();
  final ClienteApi cliente = ClienteApi();
  runApp(
    KaraokeApp(
      cliente: cliente,
      notificaciones: ServicioNotificaciones(
        cliente: cliente,
        mensajeria: MensajeriaFirebase(),
        mostrador: MostradorLocal(),
      ),
    ),
  );
}
