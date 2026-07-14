import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/core/widgets/sheet_scaffold.dart';
import 'package:gut_journey/features/sleep/data/sleep_repository.dart';
import 'package:gut_journey/features/sleep/domain/sleep_entry.dart';
import 'package:gut_journey/l10n/generated/app_localizations.dart';

class SleepQuickAddSheet extends ConsumerStatefulWidget {
  const SleepQuickAddSheet({required this.day, this.existing, super.key});

  final LocalDay day;
  final SleepEntry? existing;

  static Future<void> show(
    BuildContext context, {
    required LocalDay day,
    SleepEntry? existing,
  }) => showQuickAddSheet(
    context: context,
    builder: (_) => SleepQuickAddSheet(day: day, existing: existing),
  );

  @override
  ConsumerState<SleepQuickAddSheet> createState() => _SleepQuickAddSheetState();
}

class _SleepQuickAddSheetState extends ConsumerState<SleepQuickAddSheet> {
  late int _durationMinutes;
  int? _quality;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _durationMinutes = widget.existing?.durationMinutes ?? 8 * 60;
    _quality = widget.existing?.quality;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await ref
        .read(sleepRepositoryProvider)
        .upsertForDay(
          day: widget.day,
          durationMinutes: _durationMinutes,
          quality: _quality,
          notes: widget.existing?.notes,
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hours = _durationMinutes ~/ 60;
    final minutes = _durationMinutes % 60;

    return SheetScaffold(
      title: l10n.sleepSheetTitle,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(l10n.save),
        ),
      ],
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.sleepDurationLabel,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(
              l10n.sleepHoursMinutes(hours, minutes),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ],
        ),
        Slider(
          value: _durationMinutes.toDouble(),
          max: 14 * 60,
          divisions: 14 * 4, // 15-minute steps
          onChanged: (value) =>
              setState(() => _durationMinutes = value.round()),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.sleepQualityLabel,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (var star = 1; star <= 5; star++)
              IconButton(
                icon: Icon(
                  (_quality ?? 0) >= star ? Icons.star : Icons.star_border,
                ),
                color: Theme.of(context).colorScheme.primary,
                onPressed: () => setState(
                  () => _quality = _quality == star ? null : star,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
