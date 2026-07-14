import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Random UUID v4 primary keys keep entries globally unique, which makes a
/// future multi-device sync layer possible without rekeying local data.
String newEntryId() => _uuid.v4();
