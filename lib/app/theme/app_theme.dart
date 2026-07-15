import 'package:flutter/material.dart';

/// Seed for the whole palette: a calm teal-green, chosen to feel closer to
/// wellbeing than to a clinical tool.
const seedColor = Color(0xFF2E7D6B);

ThemeData buildAppTheme(Brightness brightness) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: brightness,
  );
  return ThemeData(
    colorScheme: colorScheme,
    visualDensity: VisualDensity.adaptivePlatformDensity,
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
    ),
  );
}
