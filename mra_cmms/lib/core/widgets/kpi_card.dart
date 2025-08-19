import 'package:flutter/material.dart';

class KpiCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color? color;
  final VoidCallback? onTap;
  final IconData? illustrationIcon;

  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color,
    this.onTap,
    this.illustrationIcon,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Use ColorScheme container roles when the provided color matches a role.
    final bool isPrimary = color == scheme.primary;
    final bool isTertiary = color == scheme.tertiary;
    final bool isError = color == scheme.error;

    Color cardBg;
    Color iconFg;
    if (color == null || isPrimary) {
      cardBg = scheme.primaryContainer;
      iconFg = scheme.onPrimaryContainer;
    } else if (isTertiary) {
      cardBg = scheme.tertiaryContainer;
      iconFg = scheme.onTertiaryContainer;
    } else if (isError) {
      cardBg = scheme.errorContainer;
      iconFg = scheme.onErrorContainer;
    } else {
      // Fallback: blend a tint of the custom color with surface
      cardBg = Color.alphaBlend(color!.withAlpha(isDark ? 48 : 30), scheme.surface);
      iconFg = color!;
    }

    // Chip background: stronger tint for hierarchy
    final chipBg = (color ?? iconFg).withAlpha(isDark ? 82 : 51);

    return Card(
      color: cardBg,
      elevation: 1, // subtle elevation as per M3
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        overlayColor: WidgetStatePropertyAll(scheme.onSurface.withValues(alpha: isDark ? 0.10 : 0.06)),
        child: Stack(
          children: [
            // Background illustration icon
            Positioned(
              right: -4,
              bottom: -4,
              child: Icon(
                illustrationIcon ?? icon,
                size: 84,
                color: (color ?? Theme.of(context).colorScheme.onSurface)
                    .withValues(alpha: isDark ? 0.10 : 0.08),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16), // M3 default card padding
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(color: chipBg, shape: BoxShape.circle),
                    padding: const EdgeInsets.all(8),
                    child: Icon(icon, color: iconFg, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$value',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

