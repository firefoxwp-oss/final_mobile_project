import 'package:flutter/material.dart';

/// Pantalla de inicio de sesión con la cuenta del sistema (Pb-7).
class PantallaInicioSesion extends StatelessWidget {
  /// Crea la pantalla de inicio de sesión.
  const PantallaInicioSesion({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Karaoke')),
      body: const Center(child: Text('Iniciar sesión')),
    );
  }
}
