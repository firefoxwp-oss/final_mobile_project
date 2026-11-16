import 'package:final_mobile_project/datos/configuracion_karaoke.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('la primera vez la voz guía empieza en 30 %', () async {
    final ConfiguracionKaraoke configuracion = await ConfiguracionKaraoke.leer(
      'abc',
    );

    expect(configuracion.vozGuia, 30);
    expect(configuracion.desfaseMs, 0);
    expect(configuracion.semitonos, 0);
  });

  test(
    'recuerda la voz guía y la sincronía para todas las canciones',
    () async {
      await const ConfiguracionKaraoke(
        vozGuia: 70,
        desfaseMs: -150,
      ).guardar('abc');

      final ConfiguracionKaraoke otra = await ConfiguracionKaraoke.leer('xyz');

      expect(otra.vozGuia, 70);
      expect(otra.desfaseMs, -150);
    },
  );

  test('recuerda el tono de cada canción por separado', () async {
    await const ConfiguracionKaraoke(semitonos: 2).guardar('abc');

    expect((await ConfiguracionKaraoke.leer('abc')).semitonos, 2);
    expect((await ConfiguracionKaraoke.leer('xyz')).semitonos, 0);
  });
}
