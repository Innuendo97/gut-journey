import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gut_journey/l10n/generated/app_localizations.dart';

/// The Delete button edit sheets pin to the start of their actions row
/// (via `SheetScaffold.destructiveAction`).
class DeleteEntryButton extends StatelessWidget {
  const DeleteEntryButton({required this.onPressed, super.key});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TextButton.icon(
      style: TextButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.error,
      ),
      onPressed: onPressed,
      icon: const Icon(Icons.delete_outline),
      label: Text(l10n.delete),
    );
  }
}

/// Deletes a diary entry and shows the shared "Entry deleted" snackbar with
/// an Undo action — the single delete UX for timeline swipes and the Delete
/// button in edit sheets.
///
/// [delete] and [restore] must capture their repository up front (not read
/// it through `ref`): Undo fires from the snackbar after the caller — a
/// dismissed row or a closed sheet — has been unmounted.
void deleteEntryWithUndo(
  BuildContext context, {
  required Future<void> Function() delete,
  required Future<void> Function() restore,
}) {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  unawaited(delete());
  // A new delete replaces the previous snackbar instead of queueing behind
  // it, so Undo always targets the entry that was just removed.
  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(l10n.entryDeleted),
        // Explicit so the auto-dismiss window survives any theme or
        // framework default change.
        // ignore: avoid_redundant_argument_values
        duration: const Duration(seconds: 4),
        // Snackbars with an action persist by default since Flutter 3.4x —
        // exactly the "delete toast never goes away" bug. Undo is a grace
        // window, not a required choice, so time out normally.
        persist: false,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        action: SnackBarAction(
          label: l10n.undo,
          onPressed: () => unawaited(restore()),
        ),
      ),
    );
}
