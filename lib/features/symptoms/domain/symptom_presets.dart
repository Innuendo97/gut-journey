/// Language-independent keys for the seeded symptom types. The UI localizes
/// them; the database never stores display names for presets.
///
/// Keys are descriptive (what the user feels), never diagnostic labels.
const symptomPresetKeys = [
  'bloating',
  'abdominal_pain',
  'nausea',
  'gas',
  'heartburn',
  'cramps',
  'constipation_feeling',
  'urgency',
  'fatigue',
  'headache',
];

/// Deterministic id for a seeded preset, stable across installs — handy for
/// tests and a future sync layer.
String symptomPresetId(String key) => 'preset-$key';
