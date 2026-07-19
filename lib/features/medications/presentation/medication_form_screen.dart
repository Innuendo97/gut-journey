import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/core/providers/clock_provider.dart';
import 'package:gut_journey/features/medications/data/medication_repository.dart';
import 'package:gut_journey/features/medications/domain/medication.dart';
import 'package:gut_journey/features/medications/domain/medication_enums.dart';
import 'package:gut_journey/l10n/generated/app_localizations.dart';
import 'package:intl/intl.dart';

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
  late LocalDay _startDay;
  LocalDay? _endDay;
  var _saving = false;
  String? _nameError;
  String? _dateError;

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
    _startDay =
        existing?.startDay ?? LocalDay.fromDateTime(ref.read(clockProvider)());
    _endDay = existing?.endDay;
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

  Future<void> _pickStartDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDay.toDateTime(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _startDay = LocalDay.fromDateTime(picked);
        _dateError = null;
      });
    }
  }

  Future<void> _pickEndDay() async {
    final start = _startDay.toDateTime();
    final end = _endDay?.toDateTime();
    final picked = await showDatePicker(
      context: context,
      initialDate: end == null || end.isBefore(start) ? start : end,
      firstDate: start,
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _endDay = LocalDay.fromDateTime(picked);
        _dateError = null;
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
    final end = _endDay;
    if (end != null && end.isBefore(_startDay)) {
      setState(
        () => _dateError = AppLocalizations.of(
          context,
        ).medicationEndBeforeStartError,
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
        startDay: _startDay,
        endDay: _endDay,
      );
    } else {
      await repo.updateMedication(
        existing.copyWith(
          name: name,
          dosage: dosage,
          scheduleType: _scheduleType,
          scheduledTimes: times,
          startDay: _startDay,
          endDay: _endDay,
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

  String _formatDay(BuildContext context, LocalDay day) {
    final locale = Localizations.localeOf(context).toString();
    return DateFormat.yMMMd(locale).format(day.toDateTime());
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
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_outlined),
            title: Text(l10n.medicationStartDayLabel),
            subtitle: Text(_formatDay(context, _startDay)),
            onTap: () => unawaited(_pickStartDay()),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_busy_outlined),
            title: Text(l10n.medicationEndDayLabel),
            subtitle: Text(
              _endDay == null
                  ? l10n.medicationNoEndDay
                  : _formatDay(context, _endDay!),
            ),
            trailing: _endDay == null
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: l10n.medicationClearEndDay,
                    onPressed: () => setState(() {
                      _endDay = null;
                      _dateError = null;
                    }),
                  ),
            onTap: () => unawaited(_pickEndDay()),
          ),
          if (_dateError != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _dateError!,
                style: Theme.of(context).textTheme.bodySmall!.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          const SizedBox(height: 16),
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
