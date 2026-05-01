import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iot_power_guard/core/features/splash/splash_screen.dart';

void main() {
  testWidgets('shows splash screen before navigating', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SplashScreen(
          delay: Duration.zero,
          nextBuilder: (_) => const Text('Login ready'),
        ),
      ),
    );

    expect(find.text('HETrack'), findsOneWidget);
    expect(find.text('Monitor & Control'), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('Login ready'), findsOneWidget);
  });
}
