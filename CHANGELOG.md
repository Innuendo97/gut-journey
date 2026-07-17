# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Amounts in grams with dynamic per-100g calculation**: meal foods are
  now logged with an explicit amount ("120 g of pasta") and calories are
  computed live from each food's per-100g values — while typing, per row
  and as an estimated meal total, with a compact macro line (protein,
  carbs, fat, fiber). The grams field prefills with the last amount used
  for that food, or its typical serving weight, so the quick flow still
  needs zero typing.
- The nutrition editor now works on the per-100g base plus a typical
  serving weight, with a live serving preview; foods holding only the old
  per-serving values get a one-tap conversion.
- Timeline meal entries spell amounts out ("Rice 150 g, Salmon 120 g").

### Changed

- Registry imports store the asset's per-100g values directly (no more
  rounding through a serving), and foods imported before this version are
  upgraded automatically on first launch. Library subtitles show
  kcal/100g.
- The ×½/×1/×2 serving cycle on picked foods is gone, replaced by the
  gram rows. Meals logged before this version keep their serving
  multipliers and their calorie totals unchanged, forever.

## [0.4.0] - 2026-07-17

### Added

- **Bundled food registry**: ~600 foods — Mediterranean and Southern-Italian
  cuisine in depth, plus Italian and international staples — with average
  per-100g values from standard nutrition tables and typical serving sizes.
  Registry matches appear as book-icon suggestions while logging a meal and
  in the new "Add food" sheet of the library; picking one imports it with
  its estimated values (which stay fully editable — they are averages, not
  advice). An automated test enforces the registry's structural accuracy
  (schema, uniqueness, plausibility, energy consistency).
- Saving a meal with a brand-new food now offers, via snackbar, to add its
  nutrition values right away — without slowing the quick-entry flow.
- Swiping a diary entry away now asks for confirmation first; undo stays
  available after deletion.

## [0.3.0] - 2026-07-17

### Added

- **Nutrition estimates** (diet as part of the therapy conversation): give
  any food in your library an estimated kcal-per-serving value (plus
  optional protein/carbs/fat/fibre and a typical-serving note). The Today
  screen shows the day's estimated energy, Statistics gains a kcal-per-day
  chart, and an optional daily goal (off by default) can be set in
  Settings. No bundled nutrition database: the values are yours, the
  totals are estimates — targets belong to your doctor or dietitian.
- Serving multiplier in the meal sheet: tap a picked food chip to cycle
  one serving into ×2, ×½ and back. One tap per food stays the fast path.
- Schema migration v2 → v3 (serving quantity on meal items); existing
  diaries and backups upgrade in place.

### Fixed

- Editing a meal from the sheet no longer silently drops the portion
  descriptions stored on its items.

## [0.2.0] - 2026-07-17

### Added

- **Observed patterns**: the Statistics tab now surfaces meal ↔ symptom
  associations observed in the diary. For each food, the app compares how
  often a symptom followed meals with it (within a selectable 4/8/24h
  window) against meals without it, always showing the raw counts. Patterns
  are observations to discuss with your doctor — never causes or advice.
- **Low FODMAP reintroduction** (More tab): track the reintroduction plan
  agreed with your clinician — test one FODMAP group at a time
  (test → washout → outcome as observed in the diary), see which groups are
  still to test, and tag your food library with its FODMAP groups.
- First real schema migration (v1 → v2) with step-migration scaffolding and
  migration tests: existing diaries upgrade in place, no data loss.

## [0.1.2] - 2026-07-17

### Added

- **PDF report for your doctor**: from Statistics or Settings, export a
  report over 7/30/90 days or a custom period — summary sections (symptoms,
  Bristol distribution, weight, water, sleep, activity, medication
  adherence) plus an optional day-by-day diary — and share or save it.

## [0.1.1] - 2026-07-17

### Added

- **Backup & restore** in Settings: export the whole database as a backup
  file, export all data as JSON, and restore a previously exported backup
  (validated, migrated to the current schema, and applied atomically).
- **App identity**: launcher icon (adaptive + monochrome), splash screen
  (light/dark, Android 12+), the brand mark on onboarding, and the launcher
  name "Gut Journey".
- A visible **Delete button (with undo)** when editing an entry — swipe to
  delete still works everywhere.
- History calendar markers are now **colored by tracker category**
  (nutrition, gut signals, therapy, body & lifestyle).

### Fixed

- Meal-type labels no longer truncate in Italian ("Colazione", "Spuntino"…):
  the selector is now a row of wrapping icon chips.
- Sleep quality in the timeline reads "Quality 3/5" instead of a star string
  that some fonts render as boxes.

## [0.1.0] - 2026-07-15

First MVP release — a complete local-first diary.

### Added

- **Diary logging** from one-tap bottom sheets: meals with a personal food
  library (autocomplete, favorites, inline creation), symptoms with intensity
  (seeded presets + custom types), bowel movements on the Bristol scale with
  optional flags, weight pre-filled with the last value, medications with
  one-tap scheduled doses and as-needed intakes, water (+250 ml), sleep and
  physical activity.
- **Today screen** with day navigation, water/medication summary strip and a
  chronological timeline (tap to edit, swipe to delete with undo).
- **History** month calendar with per-day tracker markers and full editing of
  past days.
- **Statistics** over 7/30/90 days: symptom intensity and frequency, Bristol
  distribution, weight trend, water vs goal, sleep, activity and medication
  adherence — all live on the local database.
- **Food library** and **medication** management screens.
- **Settings**: language (system/English/Italian), daily water goal, symptom
  type management, medical disclaimer and open source licenses.
- **Onboarding** gate with explicit medical-disclaimer acceptance.
- English and Italian localization; Material 3 light and dark themes.
- Local-first storage on SQLite (drift) with UUID keys, UTC timestamps and
  write-time day bucketing; schema snapshot exported for future migrations.
