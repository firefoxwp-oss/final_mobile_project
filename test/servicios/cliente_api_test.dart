import 'dart:convert';

import 'package:final_mobile_project/servicios/almacen_sesion.dart';
import 'package:final_mobile_project/servicios/cliente_api.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response _json(Object cuerpo, [int estado = 200]) =>
    http.Response(jsonEncode(cuerpo), estado);

const Map<String, String> _tokens = <String, String>{
  'access_token': 'acceso',
  'refresh_token': 'renovacion',
  'token_type': 'bearer',
};

ClienteApi _cliente(MockClientHandler servidor) =>
    ClienteApi(cliente: MockClient(servidor), url: 'https://api.prueba');

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues(<String, String>{}));

  test('inicia sesión y guarda los tokens', () async {
    final ClienteApi api = _cliente((http.Request peticion) async {
      expect(peticion.url.path, '/login');
      expect(jsonDecode(peticion.body), <String, String>{
        'email': 'ana@test.com',
        'password': 'clave123',
      });
      return _json(_tokens);
    });

    await api.iniciarSesion(' ana@test.com ', 'clave123');

    expect(await api.almacen.leerTokenAcceso(), 'acceso');
    expect(await api.almacen.leerTokenRenovacion(), 'renovacion');
  });

  test('credenciales incorrectas dan un mensaje comprensible', () async {
    final ClienteApi api = _cliente(
      (_) async => _json(<String, String>{'detail': 'x'}, 401),
    );

    await expectLater(
      api.iniciarSesion('ana@test.com', 'mala'),
      throwsA(
        isA<ErrorApi>().having(
          (ErrorApi e) => e.mensaje,
          'mensaje',
          'Correo o contraseña incorrectos',
        ),
      ),
    );
  });

  test('sin conexión da un mensaje comprensible', () async {
    final ClienteApi api = _cliente(
      (_) async => throw http.ClientException('sin red'),
    );

    await expectLater(
      api.iniciarSesion('ana@test.com', 'clave123'),
      throwsA(
        isA<ErrorApi>().having(
          (ErrorApi e) => e.mensaje,
          'mensaje',
          'No se pudo conectar con el servidor',
        ),
      ),
    );
  });

  test('sin tokens no hay sesión', () async {
    final ClienteApi api = _cliente((_) async => _json(_tokens));

    expect(await api.haySesion(), isFalse);
  });

  test('la sesión sigue activa con un token de renovación válido', () async {
    await AlmacenSesion().guardarTokens(acceso: 'viejo', renovacion: 'r1');
    final ClienteApi api = _cliente((http.Request peticion) async {
      expect(peticion.url.path, '/refresh');
      return _json(_tokens);
    });

    expect(await api.haySesion(), isTrue);
    expect(await api.almacen.leerTokenAcceso(), 'acceso');
  });

  test('si el token de renovación venció se borra la sesión', () async {
    await AlmacenSesion().guardarTokens(acceso: 'viejo', renovacion: 'r1');
    final ClienteApi api = _cliente(
      (_) async => _json(<String, String>{'detail': 'x'}, 401),
    );

    expect(await api.haySesion(), isFalse);
    expect(await api.almacen.leerTokenRenovacion(), isNull);
  });

  test('renueva el token y repite la petición una vez', () async {
    await AlmacenSesion().guardarTokens(acceso: 'vencido', renovacion: 'r1');
    final List<String> rutas = <String>[];
    final ClienteApi api = _cliente((http.Request peticion) async {
      rutas.add(peticion.url.path);
      if (peticion.url.path == '/refresh') return _json(_tokens);
      final bool vigente = peticion.headers['Authorization'] == 'Bearer acceso';
      return vigente
          ? _json(<String, String>{'name': 'Ana'})
          : _json(<String, String>{'detail': 'x'}, 401);
    });

    expect(await api.obtener('/me'), <String, String>{'name': 'Ana'});
    expect(rutas, <String>['/me', '/refresh', '/me']);
  });
}
