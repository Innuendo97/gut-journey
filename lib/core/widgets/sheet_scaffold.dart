import 'package:flutter/material.dart';

/// Shows a quick-add sheet with the app's standard shape and keyboard
/// handling. Returns whatever the sheet pops with.
Future<T?> showQuickAddSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: builder,
  );
}

/// Body layout every quick-add sheet shares: title, content, actions —
/// scrollable and padded above the keyboard.
class SheetScaffold extends StatelessWidget {
  const SheetScaffold({
    required this.title,
    required this.children,
    this.actions,
    super.key,
  });

  final String title;
  final List<Widget> children;

  /// Bottom action row; typically a save button. Omit for sheets that act
  /// instantly (e.g. medications).
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              ...children,
              if (actions != null) ...[
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    for (final (i, action) in actions!.indexed) ...[
                      if (i > 0) const SizedBox(width: 8),
                      action,
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
