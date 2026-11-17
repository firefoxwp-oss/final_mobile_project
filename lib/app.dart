import 'dart:async';

import 'package:flutter/material.dart';

import 'pantallas/pantalla_canciones.dart';
import 'pantallas/pantalla_inicio_sesion.dart';
import 'servicios/cliente_api.dart';
import 'servicios/servicio_notificaciones.dart';

/// Aplicación móvil del karaoke, con el patrón visual de Material Design.
class KaraokeApp extends StatelessWidget {
  /// Crea la aplicación con el [cliente] de la API y, si están disponibles,
  /// las [notificaciones] de finalización.
  const KaraokeApp({required this.cliente, this.notificaciones, super.key});

  /// Azul de los botones y enlaces de los prototipos.
  static const Color colorPrincipal = Color(0xFF0077C8);

  /// Cliente de la API compartido por todas las pantallas.
  final ClienteApi cliente;

  /// Notificaciones de finalización; en las pruebas puede no haberlas.
  final ServicioNotificaciones? notificaciones;

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
      home: _Inicio(cliente: cliente, notificaciones: notificaciones),
    );
  }
}

/// Abre «Mis canciones» si la sesión sigue activa, o el inicio de sesión.
class _Inicio extends StatefulWidget {
  const _Inicio({required this.cliente, this.notificaciones});

  final ClienteApi cliente;
  final ServicioNotificaciones? notificaciones;

  @override
  State<_Inicio> createState() => _InicioState();
}

class _InicioState extends State<_Inicio> {
  late final Future<bool> _haySesion = _comprobarSesion();

  Future<bool> _comprobarSesion() async {
    final bool activa = await widget.cliente.haySesion();
    // Con la sesión activa se vuelve a registrar el celular (Pb-4)
    if (activa) unawaited(widget.notificaciones?.iniciarSesion());
    return activa;
  }

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
            ? PantallaCanciones(
                cliente: widget.cliente,
                notificaciones: widget.notificaciones,
              )
            : PantallaInicioSesion(
                cliente: widget.cliente,
                notificaciones: widget.notificaciones,
              );
      },
    );
  }
}
