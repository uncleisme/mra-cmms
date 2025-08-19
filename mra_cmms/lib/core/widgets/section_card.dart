import 'package:flutter/material.dart';

class SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final VoidCallback? onSeeAll;
  final EdgeInsetsGeometry padding;
  final bool filled;
  final IconData? leadingIcon;
  final int? count;
  final List<Widget>? actions;

  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.onSeeAll,
    this.padding = const EdgeInsets.all(12),
    this.filled = false,
    this.leadingIcon,
    this.count,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: filled ? scheme.secondaryContainer : null,
      elevation: filled ? 1 : null,
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (leadingIcon != null) ...[
                  Icon(leadingIcon, color: filled ? scheme.onSecondaryContainer : scheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: filled ? scheme.onSecondaryContainer : null,
                        ),
                  ),
                ),
                if (actions != null) ...[
                  ...actions!,
                  const SizedBox(width: 4),
                ],
                if (count != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Chip(
                      label: Text('$count'),
                      labelStyle: TextStyle(color: scheme.onPrimary),
                      backgroundColor: scheme.primary,
                      visualDensity: VisualDensity.compact,
                      side: BorderSide.none,
                    ),
                  ),
                if (onSeeAll != null)
                  TextButton.icon(
                    onPressed: onSeeAll,
                    icon: const Icon(Icons.chevron_right),
                    label: const Text('See all'),
                    style: TextButton.styleFrom(
                      foregroundColor: filled ? scheme.onSecondaryContainer : null,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}
