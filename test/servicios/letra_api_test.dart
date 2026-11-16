import 'dart:convert';
import 'dart:io';

import 'package:final_mobile_project/servicios/almacen_sesion.dart';
import 'package:final_mobile_project/servicios/cliente_api.dart';
import 'package:final_mobile_project/servicios/letra.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const Map<String, Object> _letra = <String, Object>{
  'lineas': <Object>[
    <String, Object>{
      'inicio': 1.0,
      'fin': 3.5,
      'palabras': <Object>[
        <String, Object>{'texto': 'cantando', 'inicio': 1.0, 'fin': 1.6},
        <String, Object>{'texto': 'bajo', 'inicio': 1.7, 'fin': 2.1},
      ],
    },
    <String, Object>{
      'inicio': 4.0,
      'fin': 6.25,
      'palabras': <Object>[
        <String, Object>{'texto': 'la', 'inicio': 4.0, 'fin': 4.2},
        <String, Object>{'texto': 'luz', 'inicio': 4.3, 'fin': 6.25},
      ],
    },
  ],
};

void main() {
  late Directory cache;
  final List<String> peticiones = <String>[];

  ClienteApi cliente({int estado = 200}) => ClienteApi(
    url: 'https://api.prueba',
    almacen: AlmacenSesion(),
    carpetaPistas: () async => cache,
    cliente: MockClient((http.Request p) async {
      peticiones.add(p.url.path);
      if (p.url.path.endsWith('/letra')) {
        return estado == 200
            ? http.Response(jsonEncode(_letra), 200)
            : http.Response.bytes(
                utf8.encode(
                  jsonEncode(<String, String>{
                    'detail': 'La canción no tiene letra',
                  }),
                ),
                estado,
              );
      }
      return http.Response.bytes(<int>[1, 2, 3, 4], 200);
    }),
  );

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{
      'token_acceso': 'acceso',
      'token_renovacion': 'renovacion',
    });
    cache = await Directory.systemTemp.createTemp('pistas');
    peticiones.clear();
  });

  tearDown(() => cache.delete(recursive: true));

  test('obtiene la letra con los tiempos de cada palabra', () async {
    final Letra letra = await cliente().obtenerLetra('abc');

    expect(peticiones, <String>['/jobs/abc/letra']);
    expect(letra.lineas, hasLength(2));
    expect(letra.lineas.first.texto, 'cantando bajo');
    expect(
      letra.lineas.last.palabras.last.fin,
      const Duration(seconds: 6, milliseconds: 250),
    );
  });

  test('la línea actual es la primera que todavía no termina', () {
    final Letra letra = Letra.desdeJson(_letra);

    expect(letra.indiceLinea(Duration.zero), 0);
    expect(letra.indiceLinea(const Duration(seconds: 3)), 0);
    expect(letra.indiceLinea(const Duration(seconds: 3, milliseconds: 600)), 1);
    expect(letra.indiceLinea(const Duration(seconds: 9)), 1);
  });

  test('una canción sin letra muestra el mensaje del servidor', () async {
    await expectLater(
      cliente(estado: 404).obtenerLetra('abc'),
      throwsA(
        isA<ErrorApi>().having(
          (ErrorApi e) => e.mensaje,
          'mensaje',
          'La canción no tiene letra',
        ),
      ),
    );
  });

  test('descarga cada pista comprimida una sola vez', () async {
    final ClienteApi api = cliente();

    final String instrumental = await api.obtenerPista('abc', 'instrumental');
    final String voz = await api.obtenerPista('abc', 'voz');
    final String otraVez = await api.obtenerPista('abc', 'instrumental');

    expect(peticiones, <String>[
      '/descargar/instrumental_comprimido/abc',
      '/descargar/voz_comprimida/abc',
    ]);
    expect(otraVez, instrumental);
    expect(await File(voz).readAsBytes(), <int>[1, 2, 3, 4]);
  });

  test('rechaza una pista que no existe', () {
    expect(() => cliente().obtenerPista('abc', 'bateria'), throwsArgumentError);
  });
}
