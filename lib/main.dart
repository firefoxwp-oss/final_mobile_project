import 'package:flutter/material.dart';

import 'app.dart';
import 'servicios/cliente_api.dart';

void main() {
  runApp(KaraokeApp(cliente: ClienteApi()));
}
