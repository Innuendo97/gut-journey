import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Returns the current moment. Injected everywhere time is read so tests can
/// pin it — non-negotiable for a diary app.
typedef Clock = DateTime Function();

final clockProvider = Provider<Clock>((ref) => DateTime.now);
