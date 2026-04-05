// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Widget test harness builds', (WidgetTester tester) async {
    // Keep a lightweight test that doesn't require Firebase/Supabase init.
    await tester.pumpWidget(const TestHarness());
    expect(find.byType(TestHarness), findsOneWidget);
  });
}

class TestHarness extends StatelessWidget {
  const TestHarness({super.key});

  @override
  Widget build(BuildContext context) {
    return const Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox.shrink(),
    );
  }
}
