# Regenerating the README screenshots

The screenshots are rendered headlessly by pumping the real app in a widget
test at phone size (1080×2400 @ 2.625), against an in-memory database filled
by the demo seeder (`lib/dev/demo_seed.dart`) and with the real Roboto /
Material Icons fonts loaded from the Flutter SDK cache — no emulator needed:

```sh
flutter test tool/screenshots/render_screenshots_test.dart
```

This rewrites `docs/screenshots/{today,history,stats}.png`. The dataset is
deterministic (no randomness, clock pinned in the tool), so reruns only
change pixels when the UI actually changed.

## On a device or emulator instead

The same demo dataset can be baked into a debug build and captured with adb,
which includes the system status bar (emulators need KVM on Linux):

```sh
flutter build apk --debug --dart-define=DEMO_SEED=true
adb install build/app/outputs/flutter-apk/app-debug.apk
adb shell am start -n dev.danielegalasso.gut_journey/.MainActivity
adb exec-out screencap -p > docs/screenshots/today.png
```

The seeder only runs when the database is empty, so uninstall first (or wipe
app data) to reseed.
