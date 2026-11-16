import 'package:final_mobile_project/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('la aplicación abre en el inicio de sesión', (tester) async {
    await tester.pumpWidget(const KaraokeApp());

    expect(find.text('Karaoke'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Correo electrónico'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
    expect(find.text('Ingresar'), findsOneWidget);
    expect(find.text('Regístrate en la web'), findsOneWidget);
  });

  testWidgets('valida los campos antes de ingresar', (tester) async {
    await tester.pumpWidget(const KaraokeApp());

    await tester.tap(find.byKey(const Key('botonIngresar')));
    await tester.pump();
    expect(find.text('Ingresa tu correo'), findsOneWidget);
    expect(find.text('Ingresa tu contraseña'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('campoCorreo')), 'sin-arroba');
    await tester.tap(find.byKey(const Key('botonIngresar')));
    await tester.pump();
    expect(find.text('El correo no es válido'), findsOneWidget);
  });
}
