import 'package:aparcamalaga/app/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('La aplicación se inicia correctamente', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: App(),
      ),
    );

    // Just pump a few frames to ensure the app initializes
    await tester.pump();

    // The app should build without errors
    expect(tester.takeException(), isNull);
  });
}
