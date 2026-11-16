import 'package:final_mobile_project/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('la aplicación abre en el inicio de sesión', (tester) async {
    await tester.pumpWidget(const KaraokeApp());

    expect(find.text('Karaoke'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });
}
