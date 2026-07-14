import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/pump_app.dart';

void main() {
  testApp('gates the diary behind the disclaimer on first launch', (
    tester,
    harness,
  ) async {
    expect(find.text('Welcome to Gut Journey'), findsOneWidget);
    expect(find.text('Nothing logged yet'), findsNothing);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Before you start'), findsOneWidget);

    await tester.tap(find.text('I understand and accept'));
    await tester.pumpAndSettle();

    // The diary opens and the acceptance is persisted.
    expect(find.text('Nothing logged yet'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarding_accepted'), isTrue);
  }, onboarded: false);

  testApp('skips onboarding once accepted', (tester, harness) async {
    expect(find.text('Welcome to Gut Journey'), findsNothing);
    expect(find.text('Nothing logged yet'), findsOneWidget);
  });
}
