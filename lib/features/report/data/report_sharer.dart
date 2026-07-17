import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gut_journey/core/domain/date_range.dart';
import 'package:printing/printing.dart';

/// Overridden in widget tests with a fake — the real one opens the
/// platform share sheet.
final reportSharerProvider = Provider<ReportSharer>(
  (ref) => const ReportSharer(),
);

/// Thin wrapper around the platform share sheet.
class ReportSharer {
  const ReportSharer();

  Future<void> share({
    required String fileName,
    required Uint8List bytes,
  }) async {
    // The result only reports whether the sheet was dismissed, and not
    // reliably across platforms — ignore it.
    await Printing.sharePdf(bytes: bytes, filename: fileName);
  }
}

String reportFileName(DateRange range) =>
    'gut-journey-report-${range.start.value}-${range.end.value}.pdf';
