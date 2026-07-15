// Renders the brand mark into the PNG assets consumed by
// flutter_launcher_icons and flutter_native_splash. NOT part of the regular
// suite (it writes files) — run manually after changing BrandMarkPainter:
//
//   flutter test tool/branding/render_brand_assets_test.dart
//   dart run flutter_launcher_icons
//   dart run flutter_native_splash:create
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gut_journey/app/branding/brand_mark.dart';
import 'package:gut_journey/app/theme/app_theme.dart';

Future<void> _writePng(
  WidgetTester tester,
  Widget child, {
  required String path,
  required double logicalSize,
  required double pixelRatio,
}) async {
  final key = GlobalKey();
  await tester.binding.setSurfaceSize(Size.square(logicalSize));
  tester.view.physicalSize = Size.square(logicalSize);
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    Center(
      child: RepaintBoundary(
        key: key,
        child: SizedBox.square(dimension: logicalSize, child: child),
      ),
    ),
  );
  // toImage/toByteData complete on the real event loop → runAsync.
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
  debugPrint('wrote $path');
}

/// The mark centered inside a fraction of the canvas — launcher foregrounds
/// must keep the outer third empty (the adaptive-icon safe zone).
Widget _mark({required Color color, required double fraction}) => Center(
  child: FractionallySizedBox(
    widthFactor: fraction,
    heightFactor: fraction,
    child: CustomPaint(painter: BrandMarkPainter(stroke: color)),
  ),
);

void main() {
  testWidgets('render brand PNG assets', (tester) async {
    // Opaque launcher icon (also the iOS source): brand gradient + mark.
    await _writePng(
      tester,
      DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF3E9480), Color(0xFF1F5F51)],
          ),
        ),
        child: _mark(color: Colors.white, fraction: 0.72),
      ),
      path: 'assets/branding/app_icon.png',
      logicalSize: 512,
      pixelRatio: 2,
    );

    // Adaptive foreground and monochrome: transparent, mark in the safe zone.
    for (final name in ['app_icon_foreground', 'app_icon_monochrome']) {
      await _writePng(
        tester,
        _mark(color: Colors.white, fraction: 0.62),
        path: 'assets/branding/$name.png',
        logicalSize: 512,
        pixelRatio: 2,
      );
    }

    // Splash logo: transparent, teal mark, sized for the Android 12 window.
    await _writePng(
      tester,
      _mark(color: seedColor, fraction: 0.62),
      path: 'assets/branding/splash_logo.png',
      logicalSize: 576,
      pixelRatio: 2,
    );

    // The splash background must match the app's first frame exactly.
    for (final brightness in Brightness.values) {
      final surface = ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: brightness,
      ).surface;
      debugPrint('$brightness surface: $surface');
    }

    await tester.binding.setSurfaceSize(null);
    tester.view.reset();
  });
}
