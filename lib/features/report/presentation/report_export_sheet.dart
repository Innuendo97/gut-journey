import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gut_journey/core/domain/date_range.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/core/providers/clock_provider.dart';
import 'package:gut_journey/core/widgets/sheet_scaffold.dart';
import 'package:gut_journey/features/backup/data/backup_files.dart';
import 'package:gut_journey/features/report/data/report_data_repository.dart';
import 'package:gut_journey/features/report/data/report_fonts.dart';
import 'package:gut_journey/features/report/data/report_pdf_builder.dart';
import 'package:gut_journey/features/report/data/report_sharer.dart';
import 'package:gut_journey/features/settings/data/settings_repository.dart';
import 'package:gut_journey/features/stats/presentation/stats_providers.dart';
import 'package:gut_journey/l10n/generated/app_localizations.dart';
import 'package:intl/intl.dart';

/// Opens the PDF report sheet. [initialDays] preselects a quick period
/// (7/30/90) — the Stats screen passes its current selection.
Future<void> showReportExportSheet(
  BuildContext context, {
  int initialDays = 30,
}) {
  return showQuickAddSheet(
    context: context,
    builder: (context) => ReportExportSheet(initialDays: initialDays),
  );
}

class ReportExportSheet extends ConsumerStatefulWidget {
  const ReportExportSheet({this.initialDays = 30, super.key});

  final int initialDays;

  @override
  ConsumerState<ReportExportSheet> createState() => _ReportExportSheetState();
}

class _ReportExportSheetState extends ConsumerState<ReportExportSheet> {
  int? _quickDays;
  DateRange? _customRange;
  bool _includeDiary = false;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _quickDays = widget.initialDays;
  }

  DateRange _resolveRange() {
    if (_customRange case final custom?) return custom;
    final today = LocalDay.fromDateTime(ref.read(clockProvider)());
    return DateRange.lastDays(_quickDays ?? 30, endingOn: today);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final rangeFormat = DateFormat.yMMMd(locale);

    return SheetScaffold(
      title: l10n.reportSheetTitle,
      actions: [
        OutlinedButton(
          onPressed: _generating
              ? null
              : () => unawaited(_export(share: false)),
          child: Text(l10n.save),
        ),
        FilledButton(
          onPressed: _generating ? null : () => unawaited(_export(share: true)),
          child: Text(l10n.reportShareAction),
        ),
      ],
      children: [
        Text(
          l10n.reportPeriodLabel,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final days in StatsPeriodNotifier.options)
              ChoiceChip(
                label: Text(l10n.statsPeriodDays(days)),
                selected: _customRange == null && _quickDays == days,
                onSelected: (_) => setState(() {
                  _quickDays = days;
                  _customRange = null;
                }),
              ),
            ChoiceChip(
              label: Text(switch (_customRange) {
                final custom? => l10n.reportRangeValue(
                  rangeFormat.format(custom.start.toDateTime()),
                  rangeFormat.format(custom.end.toDateTime()),
                ),
                null => l10n.reportPeriodCustom,
              }),
              selected: _customRange != null,
              onSelected: (_) => unawaited(_pickCustomRange()),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.reportIncludeDiary),
          subtitle: Text(l10n.reportIncludeDiarySubtitle),
          value: _includeDiary,
          onChanged: (value) => setState(() => _includeDiary = value),
        ),
      ],
    );
  }

  Future<void> _pickCustomRange() async {
    final now = ref.read(clockProvider)();
    final current = _resolveRange();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: current.start.toDateTime(),
        end: current.end.toDateTime(),
      ),
    );
    if (picked == null) return;
    setState(() {
      _customRange = DateRange(
        LocalDay.fromDateTime(picked.start),
        LocalDay.fromDateTime(picked.end),
      );
    });
  }

  Future<void> _export({required bool share}) async {
    final l10n = AppLocalizations.of(context);
    final localeTag = Localizations.localeOf(context).toString();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final range = _resolveRange();

    setState(() => _generating = true);
    try {
      final data = await ref
          .read(reportDataRepositoryProvider)
          .collect(
            range: range,
            includeDailyLog: _includeDiary,
            waterGoalMl: ref.read(settingsProvider).waterGoalMl,
          );
      final bytes = await buildReportPdf(
        data: data,
        l10n: l10n,
        localeTag: localeTag,
        theme: await loadReportTheme(),
        generatedAt: ref.read(clockProvider)(),
      );
      final fileName = reportFileName(range);
      if (share) {
        await ref
            .read(reportSharerProvider)
            .share(
              fileName: fileName,
              bytes: bytes,
            );
      } else {
        final saved = await ref
            .read(backupFilesProvider)
            .saveAs(fileName: fileName, bytes: bytes);
        if (saved) {
          messenger.showSnackBar(SnackBar(content: Text(l10n.reportSaved)));
        }
      }
      navigator.pop();
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }
}
