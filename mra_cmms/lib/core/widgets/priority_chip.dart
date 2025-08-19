import 'package:flutter/material.dart';

class PriorityChip extends StatelessWidget {
  final String? priority; // expects: low, medium, high
  const PriorityChip(this.priority, {super.key});

  (Color bg, Color fg) _colors(ColorScheme cs) {
    final p = (priority ?? '').toLowerCase().trim();
    switch (p) {
      case 'high':
        return (cs.errorContainer, cs.onErrorContainer);
      case 'medium':
        return (cs.primaryContainer, cs.onPrimaryContainer);
      case 'low':
        return (cs.secondaryContainer, cs.onSecondaryContainer);
      default:
        return (cs.surfaceContainerHighest, cs.onSurfaceVariant);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final (bg, fg) = _colors(cs);
    final label = (priority == null || priority!.isEmpty)
        ? '—'
        : priority![0].toUpperCase() + priority!.substring(1).toLowerCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: (tt.labelMedium ?? const TextStyle()).copyWith(color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}
