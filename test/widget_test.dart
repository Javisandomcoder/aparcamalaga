import 'package:aparcamalaga/app/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Muestra el mapa de plazas PMR', (tester) async {
    await tester.pumpWidget(const App());

    expect(find.text('Plazas PMR en Málaga'), findsOneWidget);
  });
}
