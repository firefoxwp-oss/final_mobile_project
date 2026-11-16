import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../configuracion.dart';

/// Expresión simple para validar el formato del correo electrónico.
final RegExp _formatoCorreo = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Pantalla de inicio de sesión con la cuenta del sistema (Pb-7).
///
/// Sigue el prototipo del documento: logo, campos de correo y contraseña,
/// botón «Ingresar» y enlace para registrarse en la web.
class PantallaInicioSesion extends StatefulWidget {
  /// Crea la pantalla de inicio de sesión.
  const PantallaInicioSesion({super.key});

  @override
  State<PantallaInicioSesion> createState() => _PantallaInicioSesionState();
}

class _PantallaInicioSesionState extends State<PantallaInicioSesion> {
  final GlobalKey<FormState> _formulario = GlobalKey<FormState>();
  final TextEditingController _correo = TextEditingController();
  final TextEditingController _clave = TextEditingController();

  @override
  void dispose() {
    _correo.dispose();
    _clave.dispose();
    super.dispose();
  }

  void _ingresar() {
    _formulario.currentState!.validate();
  }

  Future<void> _abrirRegistro() async {
    final bool abierto = await launchUrl(
      Uri.parse(urlWeb),
      mode: LaunchMode.externalApplication,
    );
    if (!abierto && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Regístrate en $urlWeb')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Karaoke'),
        backgroundColor: tema.colorScheme.surfaceContainerHighest,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Form(
              key: _formulario,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: tema.colorScheme.primaryContainer,
                    child: Icon(
                      Icons.mic,
                      size: 48,
                      color: tema.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Iniciar sesión',
                    textAlign: TextAlign.center,
                    style: tema.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    key: const Key('campoCorreo'),
                    controller: _correo,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const <String>[AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                      border: OutlineInputBorder(),
                    ),
                    validator: (String? valor) {
                      final String texto = valor?.trim() ?? '';
                      if (texto.isEmpty) return 'Ingresa tu correo';
                      if (!_formatoCorreo.hasMatch(texto)) {
                        return 'El correo no es válido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    key: const Key('campoClave'),
                    controller: _clave,
                    obscureText: true,
                    autofillHints: const <String>[AutofillHints.password],
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _ingresar(),
                    decoration: const InputDecoration(
                      labelText: 'Contraseña',
                      border: OutlineInputBorder(),
                    ),
                    validator: (String? valor) =>
                        (valor ?? '').isEmpty ? 'Ingresa tu contraseña' : null,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      key: const Key('botonIngresar'),
                      onPressed: _ingresar,
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Ingresar',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '¿No tienes cuenta?',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: tema.colorScheme.onSurfaceVariant),
                  ),
                  TextButton(
                    onPressed: _abrirRegistro,
                    child: const Text(
                      'Regístrate en la web',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
