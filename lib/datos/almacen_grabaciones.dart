import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'grabacion.dart';

/// Grabaciones guardadas en el celular (Pb-13): la voz, una copia del
/// instrumental en el tono usado y sus datos en la tabla `recordings` de
/// SQLite. Nada se envía al servidor.
class AlmacenGrabaciones {
  /// Crea el almacén; [fabrica], [rutaBase] y [carpeta] permiten
  /// reemplazarlos en las pruebas.
  AlmacenGrabaciones({
    DatabaseFactory? fabrica,
    String? rutaBase,
    Future<Directory> Function()? carpeta,
  }) : _fabrica = fabrica ?? databaseFactory,
       _rutaBase = rutaBase,
       _carpeta = carpeta ?? getApplicationDocumentsDirectory;

  final DatabaseFactory _fabrica;
  final String? _rutaBase;
  final Future<Directory> Function() _carpeta;
  Database? _base;

  /// Script de la tabla del diseño de datos del Sprint 3.
  static const String crearTabla = '''
CREATE TABLE recordings (
    id                 INTEGER PRIMARY KEY AUTOINCREMENT,
    job_id             TEXT    NOT NULL,
    title              TEXT    NOT NULL,
    voice_path         TEXT    NOT NULL,
    instrumental_path  TEXT    NOT NULL,
    semitones          INTEGER NOT NULL DEFAULT 0 CHECK (semitones BETWEEN -6 AND 6),
    guide_volume       INTEGER NOT NULL CHECK (guide_volume BETWEEN 0 AND 100),
    duration_seconds   INTEGER NOT NULL,
    created_at         TEXT    NOT NULL
)''';

  Future<Database> _abrir() async {
    final Database? abierta = _base;
    if (abierta != null) return abierta;
    final String ruta =
        _rutaBase ?? '${await _fabrica.getDatabasesPath()}/karaoke.db';
    return _base = await _fabrica.openDatabase(
      ruta,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (Database base, int _) => base.execute(crearTabla),
      ),
    );
  }

  /// Guarda la [grabacion] con una copia del [instrumental] que sonó: así se
  /// escucha sin conexión aunque se borre la caché de las pistas.
  Future<Grabacion> guardar(Grabacion grabacion, String instrumental) async {
    final Directory carpeta = Directory(
      '${(await _carpeta()).path}/grabaciones',
    );
    await carpeta.create(recursive: true);
    final String copia =
        '${carpeta.path}/instrumental_'
        '${grabacion.fecha.millisecondsSinceEpoch}.m4a';
    await File(instrumental).copy(copia);
    final Grabacion guardada = Grabacion(
      idCancion: grabacion.idCancion,
      titulo: grabacion.titulo,
      rutaVoz: grabacion.rutaVoz,
      rutaInstrumental: copia,
      semitonos: grabacion.semitonos,
      vozGuia: grabacion.vozGuia,
      duracionSegundos: grabacion.duracionSegundos,
      fecha: grabacion.fecha,
    );
    final int id = await (await _abrir()).insert('recordings', _fila(guardada));
    return _conId(guardada, id);
  }

  /// Grabaciones guardadas, de la más reciente a la más antigua.
  Future<List<Grabacion>> listar() async {
    final List<Map<String, Object?>> filas = await (await _abrir()).query(
      'recordings',
      orderBy: 'created_at DESC, id DESC',
    );
    return filas.map(_desdeFila).toList();
  }

  /// Elimina la [grabacion] y sus archivos.
  Future<void> eliminar(Grabacion grabacion) async {
    await (await _abrir()).delete(
      'recordings',
      where: 'id = ?',
      whereArgs: <Object?>[grabacion.id],
    );
    for (final String ruta in <String>[
      grabacion.rutaVoz,
      grabacion.rutaInstrumental,
    ]) {
      final File archivo = File(ruta);
      if (await archivo.exists()) await archivo.delete();
    }
  }

  /// Cierra la base de datos.
  Future<void> cerrar() async {
    await _base?.close();
    _base = null;
  }

  static Map<String, Object?> _fila(Grabacion g) => <String, Object?>{
    'job_id': g.idCancion,
    'title': g.titulo,
    'voice_path': g.rutaVoz,
    'instrumental_path': g.rutaInstrumental,
    'semitones': g.semitonos,
    'guide_volume': g.vozGuia,
    'duration_seconds': g.duracionSegundos,
    'created_at': g.fecha.toIso8601String(),
  };

  static Grabacion _desdeFila(Map<String, Object?> fila) => Grabacion(
    id: fila['id']! as int,
    idCancion: fila['job_id']! as String,
    titulo: fila['title']! as String,
    rutaVoz: fila['voice_path']! as String,
    rutaInstrumental: fila['instrumental_path']! as String,
    semitonos: fila['semitones']! as int,
    vozGuia: fila['guide_volume']! as int,
    duracionSegundos: fila['duration_seconds']! as int,
    fecha: DateTime.parse(fila['created_at']! as String),
  );

  static Grabacion _conId(Grabacion g, int id) => Grabacion(
    id: id,
    idCancion: g.idCancion,
    titulo: g.titulo,
    rutaVoz: g.rutaVoz,
    rutaInstrumental: g.rutaInstrumental,
    semitonos: g.semitonos,
    vozGuia: g.vozGuia,
    duracionSegundos: g.duracionSegundos,
    fecha: g.fecha,
  );
}
