import 'package:flutter/material.dart';

import '../servicios/cliente_api.dart';
import 'pantalla_inicio_sesion.dart';

/// Lista de las canciones procesadas del usuario (Pb-8).
class PantallaCanciones extends StatelessWidget {
  /// Crea la pantalla «Mis canciones».
  const PantallaCanciones({required this.cliente, super.key});

  /// Cliente de la API.
  final ClienteApi cliente;

  Future<void> _cerrarSesion(BuildContext context) async {
    await cliente.cerrarSesion();
    if (!context.mounted) return;
    await Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => PantallaInicioSesion(cliente: cliente),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis canciones'),
        actions: <Widget>[
          IconButton(
            key: const Key('botonCerrarSesion'),
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () => _cerrarSesion(context),
          ),
        ],
      ),
      body: const Center(child: Text('Mis canciones')),
    );
  }
}
