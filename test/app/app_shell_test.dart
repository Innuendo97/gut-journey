import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  testApp('renders the four navigation tabs', (tester, harness) async {
    expect(find.text('Today'), findsWidgets);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Stats'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);
  });

  testApp('switches branch when a destination is tapped', (
    tester,
    harness,
  ) async {
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    // AppBar title + navigation label are both visible on the History tab.
    expect(find.text('History'), findsNWidgets(2));
  });
}
