import 'package:flutter/material.dart';

class KpiCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color? color;
  final VoidCallback? onTap;

  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Card background: use scheme container if no custom color; otherwise blend a tint of the custom color with surface
    final cardBg = color == null
        ? scheme.primaryContainer
        : Color.alphaBlend(color!.withOpacity(isDark ? 0.20 : 0.12), scheme.surface);
    // Chip background: a bit stronger than the card background for visual hierarchy
    final chipBg = color == null
        ? (isDark ? scheme.primary.withOpacity(0.30) : scheme.primary.withOpacity(0.18))
        : (isDark ? color!.withOpacity(0.32) : color!.withOpacity(0.20));
    // Foreground for icon inside chip
    final fg = color ?? scheme.onPrimaryContainer;
    return Card(
      color: cardBg,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(color: chipBg, shape: BoxShape.circle),
                padding: const EdgeInsets.all(8),
                child: Icon(icon, color: fg, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: Theme.of(context).textTheme.labelMedium),
                    const SizedBox(height: 2),
                    Text('$value', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

