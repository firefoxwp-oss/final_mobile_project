import 'package:final_mobile_project/configuracion.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sin .env cargado se usan los valores por defecto', () {
    dotenv.clean();
    expect(urlApi, 'http://10.0.2.2:8000');
    expect(urlWeb, 'http://localhost:5173');
  });

  test('las URL se leen del .env', () {
    dotenv.loadFromString(
      envString:
          'API_URL=https://api.ejemplo.com\nWEB_URL=https://web.ejemplo.com',
    );
    expect(urlApi, 'https://api.ejemplo.com');
    expect(urlWeb, 'https://web.ejemplo.com');
  });

  test('una variable vacía usa el valor por defecto', () {
    dotenv.loadFromString(envString: 'API_URL=\nWEB_URL=');
    expect(urlApi, 'http://10.0.2.2:8000');
    expect(urlWeb, 'http://localhost:5173');
  });
}
