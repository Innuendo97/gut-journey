import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gut_journey/core/db/app_database.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase(driftDatabase(name: 'gut_journey'));
  ref.onDispose(db.close);
  return db;
});
