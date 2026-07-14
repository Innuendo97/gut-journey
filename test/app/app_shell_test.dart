import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gut_journey/app/app.dart';

void main() {
  testWidgets('renders the four navigation tabs', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: GutJourneyApp()));
    await tester.pumpAndSettle();

    expect(find.text('Today'), findsWidgets);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Stats'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);
  });

  testWidgets('switches branch when a destination is tapped', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: GutJourneyApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    // AppBar title + navigation label are both visible on the History tab.
    expect(find.text('History'), findsNWidgets(2));
  });
}
