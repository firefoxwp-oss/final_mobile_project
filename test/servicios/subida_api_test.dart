import 'dart:convert';
import 'dart:typed_data';

import 'package:final_mobile_project/servicios/almacen_sesion.dart';
import 'package:final_mobile_project/servicios/cliente_api.dart';
import 'package:final_mobile_project/servicios/selector_video.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';

const Map<String, String> _tokens = <String, String>{
  'access_token': 'acceso',
  'refresh_token': 'renovacion',
  'token_type': 'bearer',
};

VideoElegido _video(int bytes) => VideoElegido(
  archivo: XFile.fromData(Uint8List(bytes), name: 'mi_cancion.mp4'),
  nombre: 'mi_cancion.mp4',
  bytes: bytes,
);

ClienteApi _cliente(Future<http.Response> Function(http.Request) subida) =>
    ClienteApi(
      cliente: MockClient((http.Request p) async {
        if (p.url.path == '/refresh') {
          return http.Response(jsonEncode(_tokens), 200);
        }
        return subida(p);
      }),
      almacen: AlmacenSesion(),
      url: 'https://api.prueba',
    );

void main() {
  setUp(
    () => FlutterSecureStorage.setMockInitialValues(<String, String>{
      'token_acceso': 'viejo',
      'token_renovacion': 'renovacion',
    }),
  );

  test('sube el video con su tipo y devuelve el trabajo en cola', () async {
    late http.Request enviada;
    final ClienteApi api = _cliente((http.Request p) async {
      enviada = p;
      return http.Response('{"job_id": "abc", "status": "queued"}', 202);
    });
    final List<double> avances = <double>[];

    final String id = await api.subirVideo(
      _video(300000),
      'instrumental',
      alProgreso: avances.add,
    );

    expect(id, 'abc');
    expect(enviada.url.path, '/procesar-video/');
    expect(enviada.headers['Authorization'], 'Bearer acceso');
    final String cuerpo = latin1.decode(enviada.bodyBytes);
    expect(cuerpo, contains('name="video_type"'));
    expect(cuerpo, contains('instrumental'));
    expect(cuerpo, contains('filename="mi_cancion.mp4"'));
    expect(avances.last, 1);
  });

  test('un archivo rechazado muestra el mensaje del servidor', () async {
    final ClienteApi api = _cliente(
      (_) async => http.Response(
        jsonEncode(<String, String>{'detail': 'Formato no permitido (.txt)'}),
        400,
      ),
    );

    await expectLater(
      api.subirVideo(_video(10), 'karaoke'),
      throwsA(
        isA<ErrorApi>().having(
          (ErrorApi e) => e.mensaje,
          'mensaje',
          'Formato no permitido (.txt)',
        ),
      ),
    );
  });
}
