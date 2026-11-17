import 'dart:io';
import 'dart:typed_data';

import 'package:final_mobile_project/servicios/grabador_voz.dart';
import 'package:flutter_test/flutter_test.dart';

/// WAV mono de 16 bits con las [muestras] dadas, a [frecuencia] Hz.
Uint8List wav(List<int> muestras, {int frecuencia = 1000}) {
  final ByteData datos = ByteData(44 + muestras.length * 2);
  void texto(int posicion, String valor) {
    for (int i = 0; i < 4; i++) {
      datos.setUint8(posicion + i, valor.codeUnitAt(i));
    }
  }

  texto(0, 'RIFF');
  datos.setUint32(4, 36 + muestras.length * 2, Endian.little);
  texto(8, 'WAVE');
  texto(12, 'fmt ');
  datos
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little)
    ..setUint16(22, 1, Endian.little)
    ..setUint32(24, frecuencia, Endian.little)
    ..setUint32(28, frecuencia * 2, Endian.little)
    ..setUint16(32, 2, Endian.little)
    ..setUint16(34, 16, Endian.little);
  texto(36, 'data');
  datos.setUint32(40, muestras.length * 2, Endian.little);
  for (int i = 0; i < muestras.length; i++) {
    datos.setInt16(44 + i * 2, muestras[i], Endian.little);
  }
  return datos.buffer.asUint8List();
}

List<int> muestras(Uint8List archivo) {
  final ByteData datos = ByteData.sublistView(archivo);
  expect(datos.getUint32(4, Endian.little), archivo.length - 8);
  expect(datos.getUint32(40, Endian.little), archivo.length - 44);
  return <int>[
    for (int i = 44; i < archivo.length; i += 2)
      datos.getInt16(i, Endian.little),
  ];
}

void main() {
  late Directory carpeta;

  setUp(() async => carpeta = await Directory.systemTemp.createTemp('voz'));
  tearDown(() => carpeta.delete(recursive: true));

  Future<File> archivo(List<int> datos) async {
    final File f = File('${carpeta.path}/voz.wav');
    await f.writeAsBytes(wav(datos));
    return f;
  }

  test('recorta el inicio de la voz hasta el comienzo de la canción', () async {
    final File voz = await archivo(<int>[for (int i = 0; i < 10; i++) i]);

    // A 1000 Hz, 3 ms son 3 muestras
    await alinearVoz(voz.path, const Duration(milliseconds: 3));

    expect(muestras(await voz.readAsBytes()), <int>[3, 4, 5, 6, 7, 8, 9]);
  });

  test('con un desfase negativo agrega silencio al inicio', () async {
    final File voz = await archivo(<int>[7, 8, 9]);

    await alinearVoz(voz.path, const Duration(milliseconds: -2));

    expect(muestras(await voz.readAsBytes()), <int>[0, 0, 7, 8, 9]);
  });

  test('un recorte mayor que la grabación la deja vacía', () async {
    final File voz = await archivo(<int>[1, 2]);

    await alinearVoz(voz.path, const Duration(seconds: 1));

    expect(muestras(await voz.readAsBytes()), isEmpty);
  });
}
