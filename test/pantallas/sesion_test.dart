import 'dart:convert';

import 'package:final_mobile_project/app.dart';
import 'package:final_mobile_project/servicios/almacen_sesion.dart';
import 'package:final_mobile_project/servicios/cliente_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Servidor simulado que acepta una sola cuenta.
ClienteApi _cliente() => ClienteApi(
  url: 'https://api.prueba',
  cliente: MockClient((http.Request peticion) async {
    if (peticion.url.path == '/jobs') return http.Response('[]', 200);
    if (peticion.url.path == '/login') {
      final Map<String, dynamic> datos =
          jsonDecode(peticion.body) as Map<String, dynamic>;
      final bool valida =
          datos['email'] == 'ana@test.com' && datos['password'] == 'clave123';
      if (!valida) return http.Response('{"detail":"x"}', 401);
    }
    return http.Response(
      '{"access_token":"a","refresh_token":"r","token_type":"bearer"}',
      200,
    );
  }),
);

Future<void> _ingresar(WidgetTester tester, String clave) async {
  await tester.enterText(find.byKey(const Key('campoCorreo')), 'ana@test.com');
  await tester.enterText(find.byKey(const Key('campoClave')), clave);
  await tester.tap(find.byKey(const Key('botonIngresar')));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues(<String, String>{}));

  testWidgets('sin sesión abre el inicio de sesión', (tester) async {
    await tester.pumpWidget(KaraokeApp(cliente: _cliente()));
    await tester.pumpAndSettle();

    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Regístrate en la web'), findsOneWidget);
  });

  testWidgets('valida los campos antes de ingresar', (tester) async {
    await tester.pumpWidget(KaraokeApp(cliente: _cliente()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('botonIngresar')));
    await tester.pump();
    expect(find.text('Ingresa tu correo'), findsOneWidget);
    expect(find.text('Ingresa tu contraseña'), findsOneWidget);
  });

  testWidgets('con credenciales correctas entra a Mis canciones', (
    tester,
  ) async {
    await tester.pumpWidget(KaraokeApp(cliente: _cliente()));
    await tester.pumpAndSettle();

    await _ingresar(tester, 'clave123');

    expect(find.text('Mis canciones'), findsWidgets);
    expect(await AlmacenSesion().leerTokenRenovacion(), 'r');
  });

  testWidgets('con credenciales incorrectas muestra un mensaje', (
    tester,
  ) async {
    await tester.pumpWidget(KaraokeApp(cliente: _cliente()));
    await tester.pumpAndSettle();

    await _ingresar(tester, 'incorrecta');

    expect(find.text('Correo o contraseña incorrectos'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });

  testWidgets('al volver a abrir la app la sesión sigue activa', (
    tester,
  ) async {
    await AlmacenSesion().guardarTokens(acceso: 'a', renovacion: 'r');

    await tester.pumpWidget(KaraokeApp(cliente: _cliente()));
    await tester.pumpAndSettle();

    expect(find.text('Mis canciones'), findsWidgets);
  });

  testWidgets('cerrar sesión vuelve al inicio y borra los tokens', (
    tester,
  ) async {
    await AlmacenSesion().guardarTokens(acceso: 'a', renovacion: 'r');
    await tester.pumpWidget(KaraokeApp(cliente: _cliente()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('botonCerrarSesion')));
    await tester.pumpAndSettle();

    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(await AlmacenSesion().leerTokenRenovacion(), isNull);
  });
}
