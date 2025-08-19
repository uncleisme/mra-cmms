import 'package:flutter/material.dart';

class StatusChip extends StatelessWidget {
  final String label;
  const StatusChip(this.label, {super.key});

  Color _bg(ColorScheme cs) {
    switch (label.toLowerCase()) {
      case 'done':
      case 'approved':
        return cs.primaryContainer;
      case 'active':
      case 'pending':
        return cs.tertiaryContainer;
      case 'rejected':
      case 'cancelled':
        return cs.errorContainer;
      default:
        return cs.secondaryContainer;
    }
  }

  Color _fg(ColorScheme cs) {
    switch (label.toLowerCase()) {
      case 'done':
      case 'approved':
        return cs.onPrimaryContainer;
      case 'active':
      case 'pending':
        return cs.onTertiaryContainer;
      case 'rejected':
      case 'cancelled':
        return cs.onErrorContainer;
      default:
        return cs.onSecondaryContainer;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _bg(cs),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: TextStyle(color: _fg(cs), fontWeight: FontWeight.w600)),
    );
  }
}
