import 'dart:io';

import 'package:final_mobile_project/datos/almacen_grabaciones.dart';
import 'package:final_mobile_project/datos/grabacion.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory carpeta;
  late AlmacenGrabaciones almacen;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    carpeta = await Directory.systemTemp.createTemp('grabaciones');
    almacen = AlmacenGrabaciones(
      fabrica: databaseFactoryFfi,
      rutaBase: inMemoryDatabasePath,
      carpeta: () async => carpeta,
    );
  });

  tearDown(() async {
    await almacen.cerrar();
    await carpeta.delete(recursive: true);
  });

  Future<Grabacion> grabacion(String titulo, DateTime fecha) async {
    final File voz = File('${carpeta.path}/voz_$titulo.wav');
    await voz.writeAsBytes(<int>[1, 2, 3]);
    return Grabacion(
      idCancion: 'abc',
      titulo: titulo,
      rutaVoz: voz.path,
      rutaInstrumental: '',
      semitonos: 2,
      vozGuia: 30,
      duracionSegundos: 225,
      fecha: fecha,
    );
  }

  Future<String> instrumental() async {
    final File pista = File('${carpeta.path}/cache_instrumental_2.m4a');
    await pista.writeAsBytes(<int>[9, 9, 9, 9]);
    return pista.path;
  }

  test('guarda la grabación con una copia del instrumental', () async {
    final String pista = await instrumental();

    final Grabacion guardada = await almacen.guardar(
      await grabacion('mi_cancion', DateTime(2026, 11, 16, 21, 15)),
      pista,
    );

    expect(guardada.id, isNotNull);
    expect(guardada.rutaInstrumental, isNot(pista));
    expect(guardada.rutaInstrumental, contains('grabaciones'));
    // La copia sigue aunque se borre la caché de las pistas
    await File(pista).delete();
    expect(await File(guardada.rutaInstrumental).readAsBytes(), <int>[
      9,
      9,
      9,
      9,
    ]);
  });

  test('lista las grabaciones de la más reciente a la más antigua', () async {
    final String pista = await instrumental();
    await almacen.guardar(
      await grabacion('antigua', DateTime(2026, 11)),
      pista,
    );
    await almacen.guardar(
      await grabacion('reciente', DateTime(2026, 11, 16)),
      pista,
    );

    final List<Grabacion> lista = await almacen.listar();

    expect(lista.map((Grabacion g) => g.titulo), <String>[
      'reciente',
      'antigua',
    ]);
    expect(lista.first.semitonos, 2);
    expect(lista.first.vozGuia, 30);
    expect(lista.first.duracionSegundos, 225);
    expect(lista.first.fecha, DateTime(2026, 11, 16));
  });

  test('eliminar borra la grabación y sus archivos', () async {
    final Grabacion guardada = await almacen.guardar(
      await grabacion('mi_cancion', DateTime(2026, 11, 16)),
      await instrumental(),
    );

    await almacen.eliminar(guardada);

    expect(await almacen.listar(), isEmpty);
    expect(File(guardada.rutaVoz).existsSync(), isFalse);
    expect(File(guardada.rutaInstrumental).existsSync(), isFalse);
  });

  test('la tabla rechaza un tono fuera del rango', () async {
    final Database base = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
    );
    await base.execute(AlmacenGrabaciones.crearTabla);

    await expectLater(
      base.insert('recordings', <String, Object?>{
        'job_id': 'abc',
        'title': 'x',
        'voice_path': 'v',
        'instrumental_path': 'i',
        'semitones': 7,
        'guide_volume': 30,
        'duration_seconds': 1,
        'created_at': '2026-11-16',
      }),
      throwsA(isA<DatabaseException>()),
    );
    await base.close();
  });
}
