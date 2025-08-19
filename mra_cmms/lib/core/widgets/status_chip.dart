import 'package:flutter/material.dart';

class StatusChip extends StatelessWidget {
  final String label;
  const StatusChip(this.label, {super.key});

  Color _bg(ColorScheme cs) {
    switch (label.toLowerCase()) {
      case 'done':
      case 'approved':
      case 'completed':
      case 'closed':
        return cs.primaryContainer;
      case 'active':
      case 'pending':
      case 'in_progress':
      case 'in progress':
      case 'open':
      case 'new':
      case 'assigned':
      case 'review':
        return cs.tertiaryContainer;
      case 'rejected':
      case 'cancelled':
      case 'canceled':
      case 'failed':
      case 'error':
      case 'overdue':
        return cs.errorContainer;
      default:
        return cs.secondaryContainer;
    }
  }

  Color _fg(ColorScheme cs) {
    switch (label.toLowerCase()) {
      case 'done':
      case 'approved':
      case 'completed':
      case 'closed':
        return cs.onPrimaryContainer;
      case 'active':
      case 'pending':
      case 'in_progress':
      case 'in progress':
      case 'open':
      case 'new':
      case 'assigned':
      case 'review':
        return cs.onTertiaryContainer;
      case 'rejected':
      case 'cancelled':
      case 'canceled':
      case 'failed':
      case 'error':
      case 'overdue':
        return cs.onErrorContainer;
      default:
        return cs.onSecondaryContainer;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _bg(cs),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: (tt.labelMedium ?? const TextStyle()).copyWith(color: _fg(cs), fontWeight: FontWeight.w600),
      ),
    );
  }
}
