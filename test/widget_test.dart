// This is a basic Flutter widget test.

import 'package:flutter_test/flutter_test.dart';
import 'package:tusflores_app/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const TusFloresApp());

    // Basic verification that app built successfully
    expect(find.byType(TusFloresApp), findsOneWidget);
  });
}
