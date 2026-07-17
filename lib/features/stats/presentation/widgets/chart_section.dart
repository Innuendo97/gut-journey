import 'package:flutter/material.dart';
import 'package:gut_journey/l10n/generated/app_localizations.dart';

/// Card wrapper every stats-style section shares: title, optional
/// annotation, and an empty state when there's nothing to draw yet.
class ChartSection extends StatelessWidget {
  const ChartSection({
    required this.title,
    required this.isEmpty,
    required this.child,
    this.annotation,
    this.height,
    super.key,
  });

  final String title;
  final String? annotation;
  final bool isEmpty;
  final double? height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleSmall),
            if (annotation != null && !isEmpty) ...[
              const SizedBox(height: 2),
              Text(
                annotation!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (isEmpty)
              Text(
                AppLocalizations.of(context).statsEmptySection,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else if (height != null)
              SizedBox(height: height, child: child)
            else
              child,
          ],
        ),
      ),
    );
  }
}
