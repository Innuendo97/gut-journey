import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  testApp('the symptom sheet offers the fever and blood-pressure presets', (
    tester,
    harness,
  ) async {
    await tapQuickAdd(tester, 'Symptom');
    expect(find.text('Fever'), findsOneWidget);
    expect(find.text('Low blood pressure'), findsOneWidget);
    expect(find.text('High blood pressure'), findsOneWidget);
  });

  testApp('the new presets are localized in Italian', localeTag: 'it', (
    tester,
    harness,
  ) async {
    await tapQuickAdd(tester, 'Sintomo');
    expect(find.text('Febbre'), findsOneWidget);
    expect(find.text('Pressione bassa'), findsOneWidget);
    expect(find.text('Pressione alta'), findsOneWidget);
  });
}
