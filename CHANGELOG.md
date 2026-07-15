# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Backup & restore** in Settings: export the whole database as a backup
  file, export all data as JSON, and restore a previously exported backup
  (validated, migrated to the current schema, and applied atomically).

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
