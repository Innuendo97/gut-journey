# Contributing to Gut Journey

Thanks for your interest! This document explains how to set up the project
and the conventions the codebase follows.

## Setup

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # drift + freezed codegen
flutter gen-l10n                                           # localization codegen
flutter run
```

Generated files (`*.g.dart`, `*.freezed.dart`, `lib/l10n/generated/`) are not
committed — re-run the commands above after pulling schema or model changes.
During development, `dart run build_runner watch` keeps codegen up to date.

## Quality bar

Before opening a PR make sure all of these pass locally (CI enforces them):

```sh
dart format .
flutter analyze
flutter test
```

- Lints come from `very_good_analysis`; don't suppress rules without a comment
  explaining why.
- Repository changes need tests against the in-memory database
  (see `test/helpers/`).
- Any schema change bumps `schemaVersion`, ships a step migration, and adds a
  migration test. No exceptions, even pre-1.0: local-first apps must never eat
  user data. After changing tables, in order:
  1. `dart run drift_dev schema dump lib/core/db/app_database.dart drift_schemas/`
     and commit the new snapshot (`drift_schemas/` holds one JSON per version).
  2. `dart run drift_dev schema steps drift_schemas/ lib/core/db/schema_versions.dart`
     to regenerate the step-migration helpers, then wire the new step into
     `onUpgrade: stepByStep(...)` in `app_database.dart`.
  3. `dart run drift_dev schema generate --data-classes --companions drift_schemas/ test/generated/`
     and add the scenario to `test/core/db/migration_test.dart` (end-state
     validation + old data survives).

  `lib/core/db/schema_versions.dart` and `test/generated/` come from the
  drift CLI, not build_runner: they ARE committed, as the one exception to
  the generated-files rule.
- No hardcoded user-facing strings in widgets — add them to
  `lib/l10n/app_en.arb` (template) and `app_it.arb`.

## Commit style

Use [Conventional Commits](https://www.conventionalcommits.org):
`feat:`, `fix:`, `refactor:`, `test:`, `docs:`, `chore:`.

## Project structure

Feature-first: each feature under `lib/features/<name>/` may contain
`domain/` (freezed models, pure logic), `data/` (repositories), and
`presentation/` (screens, sheets, providers). Shared infrastructure (the Drift
database, common widgets, value types) lives in `lib/core/`.

Deliberate non-abstractions: no repository interfaces (Riverpod overrides +
in-memory DB provide the test seams), no use-case classes, a single
`AppDatabase`. Please don't introduce them without an issue discussing why.

## Adding a translation

1. Copy `lib/l10n/app_en.arb` to `app_<locale>.arb` and translate the values.
2. Run `flutter gen-l10n` and fix anything reported in
   `untranslated_messages.json`.
3. Add the locale to the language picker in Settings.

## Medical wording

All user-facing copy must say "track / observe / discuss with your doctor" —
never "diagnose / treat / recommend". Symptom presets are descriptive
(e.g. bloating), never diagnostic labels.
