import 'package:flutter/material.dart';

import 'pantallas/pantalla_inicio_sesion.dart';

/// Aplicación móvil del karaoke, con el patrón visual de Material Design.
class KaraokeApp extends StatelessWidget {
  /// Crea la aplicación.
  const KaraokeApp({super.key});

  /// Azul de los botones y enlaces de los prototipos.
  static const Color colorPrincipal = Color(0xFF0077C8);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Karaoke',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: colorPrincipal,
          primary: colorPrincipal,
        ),
        appBarTheme: const AppBarTheme(
          titleTextStyle: TextStyle(
            color: Colors.black87,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      home: const PantallaInicioSesion(),
    );
  }
}
