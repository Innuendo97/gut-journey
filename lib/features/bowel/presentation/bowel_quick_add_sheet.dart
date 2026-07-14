import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/core/l10n/labels.dart';
import 'package:gut_journey/core/providers/clock_provider.dart';
import 'package:gut_journey/core/widgets/sheet_scaffold.dart';
import 'package:gut_journey/features/bowel/data/bowel_repository.dart';
import 'package:gut_journey/features/bowel/domain/bowel_movement.dart';
import 'package:gut_journey/l10n/generated/app_localizations.dart';

class BowelQuickAddSheet extends ConsumerStatefulWidget {
  const BowelQuickAddSheet({required this.day, this.existing, super.key});

  final LocalDay day;
  final BowelMovement? existing;

  static Future<void> show(
    BuildContext context, {
    required LocalDay day,
    BowelMovement? existing,
  }) => showQuickAddSheet(
    context: context,
    builder: (_) => BowelQuickAddSheet(day: day, existing: existing),
  );

  @override
  ConsumerState<BowelQuickAddSheet> createState() => _BowelQuickAddSheetState();
}

class _BowelQuickAddSheetState extends ConsumerState<BowelQuickAddSheet> {
  int? _bristol;
  late bool _urgency;
  late bool _blood;
  late bool _mucus;
  late bool _incomplete;
  int? _pain;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _bristol = existing?.bristolType;
    _urgency = existing?.urgency ?? false;
    _blood = existing?.blood ?? false;
    _mucus = existing?.mucus ?? false;
    _incomplete = existing?.incompleteEvacuation ?? false;
    _pain = existing?.pain;
  }

  Future<void> _save() async {
    final bristol = _bristol;
    if (bristol == null) return;
    setState(() => _saving = true);
    final repo = ref.read(bowelRepositoryProvider);
    final existing = widget.existing;
    if (existing == null) {
      final now = ref.read(clockProvider)();
      final occurredAt = LocalDay.fromDateTime(now) == widget.day
          ? now
          : widget.day.toDateTime().add(const Duration(hours: 12));
      await repo.add(
        bristolType: bristol,
        occurredAt: occurredAt,
        urgency: _urgency,
        pain: _pain,
        blood: _blood,
        mucus: _mucus,
        incompleteEvacuation: _incomplete,
      );
    } else {
      await repo.update(
        existing.copyWith(
          bristolType: bristol,
          urgency: _urgency,
          pain: _pain,
          blood: _blood,
          mucus: _mucus,
          incompleteEvacuation: _incomplete,
        ),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return SheetScaffold(
      title: widget.existing == null
          ? l10n.bowelSheetTitle
          : l10n.bowelSheetEditTitle,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _bristol == null || _saving ? null : _save,
          child: Text(l10n.save),
        ),
      ],
      children: [
        for (var type = 1; type <= 7; type++)
          Card(
            margin: const EdgeInsets.symmetric(vertical: 2),
            color: _bristol == type
                ? Theme.of(context).colorScheme.secondaryContainer
                : null,
            child: ListTile(
              leading: CircleAvatar(
                radius: 16,
                child: Text('$type'),
              ),
              title: Text(l10n.bristolDescription(type)),
              onTap: () => setState(() => _bristol = type),
            ),
          ),
        const SizedBox(height: 8),
        ExpansionTile(
          title: Text(l10n.moreOptions),
          tilePadding: EdgeInsets.zero,
          initiallyExpanded:
              _urgency || _blood || _mucus || _incomplete || _pain != null,
          children: [
            SwitchListTile(
              title: Text(l10n.urgencyLabel),
              value: _urgency,
              onChanged: (value) => setState(() => _urgency = value),
            ),
            SwitchListTile(
              title: Text(l10n.bloodLabel),
              value: _blood,
              onChanged: (value) => setState(() => _blood = value),
            ),
            SwitchListTile(
              title: Text(l10n.mucusLabel),
              value: _mucus,
              onChanged: (value) => setState(() => _mucus = value),
            ),
            SwitchListTile(
              title: Text(l10n.incompleteLabel),
              value: _incomplete,
              onChanged: (value) => setState(() => _incomplete = value),
            ),
            Row(
              children: [
                const SizedBox(width: 16),
                Text(l10n.painLabel),
                Expanded(
                  child: Slider(
                    value: (_pain ?? 0).toDouble(),
                    max: 10,
                    divisions: 10,
                    label: _pain == null ? '—' : '$_pain',
                    onChanged: (value) => setState(
                      () => _pain = value.round() == 0 ? null : value.round(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
