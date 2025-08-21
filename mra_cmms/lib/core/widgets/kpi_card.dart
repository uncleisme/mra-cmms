import 'package:flutter/material.dart';

class KpiCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color? color;
  final VoidCallback? onTap;
  final IconData? illustrationIcon;
  final double? trendPercent; // positive for up, negative for down

  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color,
    this.onTap,
    this.illustrationIcon,
    this.trendPercent,
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
    Color? onTextColor; // used for label/value when solid custom color
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
      // Custom color: use SOLID background and compute contrasting foreground
      cardBg = color!;
      final lum = cardBg.computeLuminance();
      final fg = lum < 0.5 ? Colors.white : Colors.black;
      iconFg = fg;
      onTextColor = fg;
    }

    // Chip background: when solid custom, use subtle onText overlay; else use existing tint
    final bool isSolidCustom = color != null && !isPrimary && !isTertiary && !isError;
    final chipBg = isSolidCustom
        ? (onTextColor ?? iconFg).withValues(alpha: isDark ? 0.18 : 0.14)
        : (color ?? iconFg).withAlpha(isDark ? 82 : 51);

    return Card(
      color: cardBg,
      elevation: 0,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        overlayColor: WidgetStatePropertyAll(scheme.onSurface.withValues(alpha: isDark ? 0.10 : 0.06)),
        child: Stack(
          children: [
            if (illustrationIcon != null)
              Positioned(
                right: -4,
                bottom: -4,
                child: Icon(
                  illustrationIcon,
                  size: 84,
                  color: (isSolidCustom ? (onTextColor ?? iconFg) : (color ?? Theme.of(context).colorScheme.onSurface))
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
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: onTextColor ?? scheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$value',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: onTextColor,
                              ),
                        ),
                        if (trendPercent != null) ...[
                          const SizedBox(height: 2),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                trendPercent! >= 0 ? Icons.trending_up : Icons.trending_down,
                                size: 16,
                                color: trendPercent! >= 0 ? Colors.green : scheme.error,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${trendPercent! >= 0 ? '+' : ''}${trendPercent!.toStringAsFixed(1)}%',
                                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                        ],
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

