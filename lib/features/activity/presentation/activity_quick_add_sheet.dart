import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/core/l10n/labels.dart';
import 'package:gut_journey/core/providers/clock_provider.dart';
import 'package:gut_journey/core/widgets/delete_entry_with_undo.dart';
import 'package:gut_journey/core/widgets/sheet_scaffold.dart';
import 'package:gut_journey/features/activity/data/activity_repository.dart';
import 'package:gut_journey/features/activity/domain/activity_entry.dart';
import 'package:gut_journey/features/activity/domain/effort.dart';
import 'package:gut_journey/l10n/generated/app_localizations.dart';

final FutureProvider<List<String>> recentActivityNamesProvider =
    FutureProvider.autoDispose<List<String>>(
      (ref) => ref.watch(activityRepositoryProvider).recentNames(),
    );

class ActivityQuickAddSheet extends ConsumerStatefulWidget {
  const ActivityQuickAddSheet({required this.day, this.existing, super.key});

  final LocalDay day;
  final ActivityEntry? existing;

  static Future<void> show(
    BuildContext context, {
    required LocalDay day,
    ActivityEntry? existing,
  }) => showQuickAddSheet(
    context: context,
    builder: (_) => ActivityQuickAddSheet(day: day, existing: existing),
  );

  @override
  ConsumerState<ActivityQuickAddSheet> createState() =>
      _ActivityQuickAddSheetState();
}

class _ActivityQuickAddSheetState extends ConsumerState<ActivityQuickAddSheet> {
  late final TextEditingController _name;
  late final TextEditingController _duration;
  late Effort _effort;
  var _saving = false;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _name = TextEditingController(text: existing?.name ?? '');
    _duration = TextEditingController(
      text: (existing?.durationMinutes ?? 30).toString(),
    );
    _effort = existing?.effort ?? Effort.moderate;
  }

  @override
  void dispose() {
    _name.dispose();
    _duration.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(
        () => _nameError = AppLocalizations.of(context).activityNameRequired,
      );
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(activityRepositoryProvider);
    final duration = int.tryParse(_duration.text.trim()) ?? 30;
    final existing = widget.existing;
    if (existing == null) {
      final now = ref.read(clockProvider)();
      final occurredAt = LocalDay.fromDateTime(now) == widget.day
          ? now
          : widget.day.toDateTime().add(const Duration(hours: 18));
      await repo.add(
        name: name,
        durationMinutes: duration,
        effort: _effort,
        occurredAt: occurredAt,
      );
    } else {
      await repo.update(
        existing.copyWith(
          name: name,
          durationMinutes: duration,
          effort: _effort,
        ),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  void _delete() {
    final existing = widget.existing!;
    final repo = ref.read(activityRepositoryProvider);
    deleteEntryWithUndo(
      context,
      delete: () => repo.delete(existing.id),
      restore: () => repo.add(
        name: existing.name,
        durationMinutes: existing.durationMinutes,
        effort: existing.effort,
        occurredAt: existing.occurredAt,
        notes: existing.notes,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final recents = ref.watch(recentActivityNamesProvider).value ?? const [];

    return SheetScaffold(
      title: widget.existing == null
          ? l10n.activitySheetTitle
          : l10n.activitySheetEditTitle,
      destructiveAction: widget.existing == null
          ? null
          : DeleteEntryButton(onPressed: _saving ? null : _delete),
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
        TextField(
          controller: _name,
          decoration: InputDecoration(
            labelText: l10n.activityNameLabel,
            hintText: l10n.activityNameHint,
            errorText: _nameError,
          ),
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) {
            if (_nameError != null) setState(() => _nameError = null);
          },
        ),
        if (recents.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final name in recents)
                ActionChip(
                  label: Text(name),
                  onPressed: () => setState(() => _name.text = name),
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        TextField(
          controller: _duration,
          decoration: InputDecoration(labelText: l10n.activityDurationLabel),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        Text(l10n.effortLabel, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<Effort>(
          segments: [
            for (final effort in Effort.values)
              ButtonSegment(
                value: effort,
                label: Text(
                  l10n.effortName(effort),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          selected: {_effort},
          showSelectedIcon: false,
          onSelectionChanged: (selection) =>
              setState(() => _effort = selection.first),
        ),
      ],
    );
  }
}
