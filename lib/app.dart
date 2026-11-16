import 'package:flutter/material.dart';

import 'pantallas/pantalla_canciones.dart';
import 'pantallas/pantalla_inicio_sesion.dart';
import 'servicios/cliente_api.dart';

/// Aplicación móvil del karaoke, con el patrón visual de Material Design.
class KaraokeApp extends StatelessWidget {
  /// Crea la aplicación con el [cliente] de la API.
  const KaraokeApp({required this.cliente, super.key});

  /// Azul de los botones y enlaces de los prototipos.
  static const Color colorPrincipal = Color(0xFF0077C8);

  /// Cliente de la API compartido por todas las pantallas.
  final ClienteApi cliente;

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
      home: _Inicio(cliente: cliente),
    );
  }
}

/// Abre «Mis canciones» si la sesión sigue activa, o el inicio de sesión.
class _Inicio extends StatefulWidget {
  const _Inicio({required this.cliente});

  final ClienteApi cliente;

  @override
  State<_Inicio> createState() => _InicioState();
}

class _InicioState extends State<_Inicio> {
  late final Future<bool> _haySesion = widget.cliente.haySesion();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _haySesion,
      builder: (BuildContext context, AsyncSnapshot<bool> sesion) {
        if (!sesion.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return sesion.data!
            ? PantallaCanciones(cliente: widget.cliente)
            : PantallaInicioSesion(cliente: widget.cliente);
      },
    );
  }
}
