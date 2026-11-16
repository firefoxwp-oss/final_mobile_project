import 'package:flutter/material.dart';

/// Lista de las canciones procesadas del usuario (Pb-8).
class PantallaCanciones extends StatelessWidget {
  /// Crea la pantalla «Mis canciones».
  const PantallaCanciones({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis canciones')),
      body: const Center(child: Text('Mis canciones')),
    );
  }
}
