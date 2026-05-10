// Basic smoke test for IELTS Speaking 2026

import 'package:flutter_test/flutter_test.dart';
import 'package:ielts_speaking_2026/main.dart';

void main() {
  testWidgets('App should start without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const IELTSSpeakingApp());
    // Just verify the app renders without throwing
    expect(find.byType(IELTSSpeakingApp), findsOneWidget);
  });
}
