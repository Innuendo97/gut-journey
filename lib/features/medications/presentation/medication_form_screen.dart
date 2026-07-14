import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/core/providers/clock_provider.dart';
import 'package:gut_journey/features/medications/data/medication_repository.dart';
import 'package:gut_journey/features/medications/domain/medication.dart';
import 'package:gut_journey/features/medications/domain/medication_enums.dart';
import 'package:gut_journey/l10n/generated/app_localizations.dart';

/// Create ([existing] == null) or edit a medication and its schedule.
class MedicationFormScreen extends ConsumerStatefulWidget {
  const MedicationFormScreen({this.existing, super.key});

  final Medication? existing;

  @override
  ConsumerState<MedicationFormScreen> createState() =>
      _MedicationFormScreenState();
}

class _MedicationFormScreenState extends ConsumerState<MedicationFormScreen> {
  late final TextEditingController _name;
  late final TextEditingController _dosage;
  late ScheduleType _scheduleType;
  late List<String> _times;
  var _saving = false;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _name = TextEditingController(text: existing?.name ?? '');
    _dosage = TextEditingController(text: existing?.dosage ?? '');
    _scheduleType = existing?.scheduleType ?? ScheduleType.daily;
    _times = [
      ...existing?.scheduledTimes ?? const ['08:00'],
    ];
  }

  @override
  void dispose() {
    _name.dispose();
    _dosage.dispose();
    super.dispose();
  }

  Future<void> _addTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
    );
    if (picked != null) {
      final formatted =
          '${picked.hour.toString().padLeft(2, '0')}:'
          '${picked.minute.toString().padLeft(2, '0')}';
      setState(() {
        if (!_times.contains(formatted)) {
          _times = [..._times, formatted]..sort();
        }
      });
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(
        () => _nameError = AppLocalizations.of(context).medicationNameRequired,
      );
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(medicationRepositoryProvider);
    final dosage = _dosage.text.trim().isEmpty ? null : _dosage.text.trim();
    final times = _scheduleType == ScheduleType.daily
        ? _times
        : const <String>[];
    final existing = widget.existing;
    if (existing == null) {
      await repo.createMedication(
        name: name,
        dosage: dosage,
        scheduleType: _scheduleType,
        scheduledTimes: times,
        startDay: LocalDay.fromDateTime(ref.read(clockProvider)()),
      );
    } else {
      await repo.updateMedication(
        existing.copyWith(
          name: name,
          dosage: dosage,
          scheduleType: _scheduleType,
          scheduledTimes: times,
        ),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final existing = widget.existing;
    if (existing == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteMedication),
        content: Text(l10n.deleteMedicationWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if ((confirmed ?? false) && mounted) {
      await ref
          .read(medicationRepositoryProvider)
          .deleteMedication(existing.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isEdit = widget.existing != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? l10n.editMedication : l10n.addMedication),
        actions: [
          if (isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.deleteMedication,
              onPressed: () => unawaited(_delete()),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            decoration: InputDecoration(
              labelText: l10n.medicationNameLabel,
              errorText: _nameError,
            ),
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) {
              if (_nameError != null) setState(() => _nameError = null);
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _dosage,
            decoration: InputDecoration(labelText: l10n.dosageLabel),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.scheduleLabel,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          SegmentedButton<ScheduleType>(
            segments: [
              ButtonSegment(
                value: ScheduleType.daily,
                label: Text(l10n.scheduleDaily),
              ),
              ButtonSegment(
                value: ScheduleType.asNeeded,
                label: Text(l10n.scheduleAsNeeded),
              ),
            ],
            selected: {_scheduleType},
            showSelectedIcon: false,
            onSelectionChanged: (selection) =>
                setState(() => _scheduleType = selection.first),
          ),
          if (_scheduleType == ScheduleType.daily) ...[
            const SizedBox(height: 16),
            Text(
              l10n.scheduledTimesLabel,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final time in _times)
                  InputChip(
                    label: Text(time),
                    onDeleted: _times.length > 1
                        ? () => setState(
                            () => _times = [..._times]..remove(time),
                          )
                        : null,
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add),
                  label: Text(l10n.addTime),
                  onPressed: () => unawaited(_addTime()),
                ),
              ],
            ),
          ],
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }
}
