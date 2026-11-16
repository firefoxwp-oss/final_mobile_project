import 'package:flutter/material.dart';

import 'app.dart';
import 'configuracion.dart';
import 'servicios/cliente_api.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await cargarConfiguracion();
  runApp(KaraokeApp(cliente: ClienteApi()));
}
