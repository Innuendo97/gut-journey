# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
