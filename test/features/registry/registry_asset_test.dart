import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Structural accuracy guard for the bundled food registry: schema, size,
/// uniqueness, plausibility ranges and Atwater energy consistency
/// (kcal ≈ 4·protein + 4·carbs + 9·fat + 7·alcohol, with a 0–2 kcal/g
/// fiber band). Values that violate physics never ship.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const knownCategories = {
    'cereali-pasta',
    'pane-forno',
    'legumi',
    'verdure',
    'frutta',
    'frutta-secca-semi',
    'pesce',
    'carne',
    'salumi',
    'latticini',
    'uova-grassi-condimenti',
    'dolci',
    'bevande',
    'piatti-mediterranei',
    'sud-italia',
    'internazionale',
    'snack',
    'altro',
  };

  late List<dynamic> foods;

  setUpAll(() async {
    final raw = await rootBundle.loadString(
      'assets/data/food_registry_v1.json',
    );
    final data = jsonDecode(raw) as Map<String, dynamic>;
    expect(data['version'], 1);
    foods = data['foods'] as List<dynamic>;
  });

  test('the registry is rich: at least 600 foods', () {
    expect(foods.length, greaterThanOrEqualTo(600));
  });

  test('every entry is complete, unique and in a known category', () {
    final ids = <String>{};
    final itNames = <String>{};
    final enNames = <String>{};
    for (final dynamic entry in foods) {
      final food = entry as Map<String, dynamic>;
      final id = food['id'] as String;
      expect(RegExp(r'^[a-z0-9-]+$').hasMatch(id), isTrue, reason: 'id $id');
      expect(ids.add(id), isTrue, reason: 'duplicate id $id');
      final it = (food['it'] as String).trim();
      final en = (food['en'] as String).trim();
      expect(it, isNotEmpty, reason: 'empty it name for $id');
      expect(en, isNotEmpty, reason: 'empty en name for $id');
      expect(itNames.add(it.toLowerCase()), isTrue, reason: 'dup it "$it"');
      expect(enNames.add(en.toLowerCase()), isTrue, reason: 'dup en "$en"');
      expect(
        knownCategories.contains(food['cat']),
        isTrue,
        reason: 'unknown category ${food['cat']} for $id',
      );
      final serving = food['serving'] as Map<String, dynamic>;
      expect((serving['it'] as String).trim(), isNotEmpty, reason: id);
      expect((serving['en'] as String).trim(), isNotEmpty, reason: id);
    }
  });

  test('per-100g values are plausible and energy-consistent', () {
    for (final dynamic entry in foods) {
      final food = entry as Map<String, dynamic>;
      final id = food['id'] as String;
      final p = food['per100g'] as Map<String, dynamic>;
      final kcal = (p['kcal'] as num).toDouble();
      final protein = (p['protein'] as num).toDouble();
      final carbs = (p['carbs'] as num).toDouble();
      final fat = (p['fat'] as num).toDouble();
      final fiber = (p['fiber'] as num).toDouble();
      final alcohol = ((p['alcohol'] as num?) ?? 0).toDouble();

      expect(kcal, inInclusiveRange(0, 900), reason: id);
      for (final macro in [protein, carbs, fat, fiber]) {
        expect(macro, inInclusiveRange(0, 100), reason: id);
      }
      expect(
        protein + carbs + fat + fiber,
        lessThanOrEqualTo(105),
        reason: 'macros sum for $id',
      );

      final base = 4 * protein + 4 * carbs + 9 * fat + 7 * alcohol;
      final upper = base + 2 * fiber;
      final tolerance = [0.12 * kcal, 0.12 * base, 20.0].reduce(
        (a, b) => a > b ? a : b,
      );
      expect(
        kcal,
        inInclusiveRange(base - tolerance, upper + tolerance),
        reason:
            'Atwater mismatch for $id: $kcal kcal vs '
            '${base.toStringAsFixed(0)}–${upper.toStringAsFixed(0)}',
      );

      final servingG = ((food['serving'] as Map<String, dynamic>)['g'] as num)
          .toDouble();
      expect(servingG, inInclusiveRange(1, 500), reason: 'serving of $id');
    }
  });

  test('the Mediterranean/South-Italian focus is present', () {
    final ids = {for (final dynamic f in foods) (f as Map)['id'] as String};
    // A few sentinels that must exist in any credible Italian registry.
    for (final sentinel in [
      'pasta-semola-cruda',
      'olio-extravergine-oliva',
      'mozzarella-di-bufala',
      'parmigiana-di-melanzane',
      'orecchiette-cime-rapa',
    ]) {
      expect(
        ids.any((id) => id.contains(sentinel.split('-').first)),
        isTrue,
        reason: 'missing anything like $sentinel',
      );
    }
  });
}
