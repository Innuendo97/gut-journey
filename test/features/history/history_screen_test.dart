import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gut_journey/features/diary/domain/tracker_kind.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../helpers/pump_app.dart';

/// The default 800x600 test surface is landscape: the month calendar leaves
/// no room for the day view below. Use a phone-portrait surface instead.
Future<void> usePhonePortraitSurface(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpAndSettle();
}

void main() {
  testApp('History shows the calendar and the selected day view', (
    tester,
    harness,
  ) async {
    await usePhonePortraitSurface(tester);
    // Log something today from the Today tab first.
    await tapQuickAdd(tester, 'Water');

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    expect(find.byType(TableCalendar<TrackerKind>), findsOneWidget);
    // Today is selected by default → the water entry is visible below.
    expect(find.text('250 ml'), findsOneWidget);
  });

  testApp("calendar markers appear and disappear with the day's entries", (
    tester,
    harness,
  ) async {
    await usePhonePortraitSurface(tester);
    // FixedClock pins today to 2026-07-14.
    const markerKey = ValueKey('history-markers-2026-07-14');
    await tapQuickAdd(tester, 'Water');

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.byKey(markerKey), findsOneWidget);

    // Swipe-delete from History's own day view: the dot row reacts too.
    await tester.drag(find.text('250 ml'), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(markerKey), findsNothing);
  });

  testApp('selecting a past day shows its (empty) diary for back-filling', (
    tester,
    harness,
  ) async {
    await usePhonePortraitSurface(tester);
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('13')); // July 13th, unique in the grid
    await tester.pumpAndSettle();

    expect(find.text('Nothing logged yet'), findsOneWidget);
    // The quick-add bar is available for back-filling.
    expect(find.text('Meal'), findsOneWidget);
  });
}
