import 'package:flutter/material.dart';
import 'package:gut_journey/l10n/generated/app_localizations.dart';

/// One text field of a [TextInputDialog].
class TextInputField {
  const TextInputField({
    required this.label,
    this.initialValue = '',
    this.keyboardType,
    this.suffixText,
  });

  final String label;
  final String initialValue;
  final TextInputType? keyboardType;
  final String? suffixText;
}

/// A dialog with one or more text fields that owns its controllers, so they
/// outlive the dialog's exit animation. Returns the field values on save,
/// null on cancel.
class TextInputDialog extends StatefulWidget {
  const TextInputDialog({required this.title, required this.fields, super.key});

  final String title;
  final List<TextInputField> fields;

  static Future<List<String>?> show(
    BuildContext context, {
    required String title,
    required List<TextInputField> fields,
  }) => showDialog<List<String>>(
    context: context,
    builder: (context) => TextInputDialog(title: title, fields: fields),
  );

  @override
  State<TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<TextInputDialog> {
  late final List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = [
      for (final field in widget.fields)
        TextEditingController(text: field.initialValue),
    ];
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (index, field) in widget.fields.indexed) ...[
            if (index > 0) const SizedBox(height: 12),
            TextField(
              controller: _controllers[index],
              autofocus: index == 0,
              keyboardType: field.keyboardType,
              textCapitalization: field.keyboardType == TextInputType.number
                  ? TextCapitalization.none
                  : TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: field.label,
                suffixText: field.suffixText,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(
            context,
          ).pop([for (final controller in _controllers) controller.text]),
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
