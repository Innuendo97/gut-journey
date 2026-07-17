import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gut_journey/core/domain/date_range.dart';
import 'package:gut_journey/features/correlations/data/correlations_repository.dart';
import 'package:gut_journey/features/correlations/domain/correlation_models.dart';

/// Family key for one analysis run. A record: structurally equal, and
/// [DateRange] is value-equal, so equal queries share one subscription.
typedef CorrelationsQuery = ({DateRange range, Duration window});

const correlationWindowOptions = [
  Duration(hours: 4),
  Duration(hours: 8),
  Duration(hours: 24),
];

const defaultCorrelationWindow = Duration(hours: 8);

/// The meal→symptom window selected on the correlations screen.
final correlationWindowProvider =
    NotifierProvider<CorrelationWindowNotifier, Duration>(
      CorrelationWindowNotifier.new,
    );

class CorrelationWindowNotifier extends Notifier<Duration> {
  @override
  Duration build() => defaultCorrelationWindow;

  Duration get window => state;
  set window(Duration value) => state = value;
}

final correlationsProvider = StreamProvider.autoDispose
    .family<CorrelationsResult, CorrelationsQuery>(
      (ref, query) => ref
          .watch(correlationsRepositoryProvider)
          .watchAssociations(range: query.range, window: query.window),
    );
