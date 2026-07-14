import 'package:freezed_annotation/freezed_annotation.dart';

part 'symptom_type.freezed.dart';
part 'symptom_type.g.dart';

/// A kind of symptom the user can log: a seeded preset (localized in the UI
/// via [presetKey]) or a custom type they created ([customName]).
@freezed
abstract class SymptomType with _$SymptomType {
  const factory SymptomType({
    required String id,
    String? presetKey,
    String? customName,
    @Default(false) bool isArchived,
  }) = _SymptomType;

  const SymptomType._();

  factory SymptomType.fromJson(Map<String, dynamic> json) =>
      _$SymptomTypeFromJson(json);

  bool get isPreset => presetKey != null;
}
