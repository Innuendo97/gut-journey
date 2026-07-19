import 'package:flutter/material.dart';
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
  testApp('History opens on today with day stepping in the header', (
    tester,
    harness,
  ) async {
    await usePhonePortraitSurface(tester);
    // Log something today from the Today tab first.
    await tapQuickAdd(tester, 'Water');

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    // No always-on calendar anymore; the header carries the selection.
    expect(find.byType(TableCalendar<TrackerKind>), findsNothing);
    expect(find.text('Today'), findsNWidgets(2)); // header + nav tab
    expect(find.text('250 ml'), findsOneWidget);

    // On today, the forward chevron is disabled.
    final forward = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.chevron_right),
    );
    expect(forward.onPressed, isNull);

    // Two steps back land on Sunday the 12th (FixedClock: 2026-07-14).
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    expect(find.text('Yesterday'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    expect(find.text('Sunday, July 12'), findsOneWidget);
    expect(find.text('Nothing logged yet'), findsOneWidget);
  });

  testApp('the calendar sheet shows markers and picks a day', (
    tester,
    harness,
  ) async {
    await usePhonePortraitSurface(tester);
    // FixedClock pins today to 2026-07-14.
    const markerKey = ValueKey('history-markers-2026-07-14');
    await tapQuickAdd(tester, 'Water');

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Open calendar'));
    await tester.pumpAndSettle();
    expect(find.byType(TableCalendar<TrackerKind>), findsOneWidget);
    expect(find.byKey(markerKey), findsOneWidget);

    // Picking a day closes the sheet and shows that day below.
    await tester.tap(find.text('13')); // July 13th, unique in the grid
    await tester.pumpAndSettle();
    expect(find.byType(TableCalendar<TrackerKind>), findsNothing);
    expect(find.text('Yesterday'), findsOneWidget); // July 13 header
    expect(find.text('Nothing logged yet'), findsOneWidget);
  });

  testApp('a past day selected from the sheet can be back-filled', (
    tester,
    harness,
  ) async {
    await usePhonePortraitSurface(tester);
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Open calendar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('13')); // July 13th, unique in the grid
    await tester.pumpAndSettle();

    expect(find.text('Nothing logged yet'), findsOneWidget);
    // The quick-add bar is available for back-filling.
    await tapQuickAdd(tester, 'Water');
    expect(find.text('250 ml'), findsOneWidget);

    // The entry landed on the 13th, not on today.
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    expect(find.text('Today'), findsNWidgets(2)); // header + nav tab
    expect(find.text('250 ml'), findsNothing);
  });
}
