import 'package:flutter/material.dart';

/// Detalle de una canción terminada (Pb-8).
class PantallaDetalleCancion extends StatelessWidget {
  /// Crea el detalle de la canción con el [titulo] indicado.
  const PantallaDetalleCancion({required this.titulo, super.key});

  /// Nombre de la canción.
  final String titulo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: Center(child: Text(titulo)),
    );
  }
}
