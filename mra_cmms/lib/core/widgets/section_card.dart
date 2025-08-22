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
  final Color? backgroundColor; // optional explicit background color
  final Color? foregroundColor; // optional explicit text/icon color
  final TextStyle? titleTextStyle; // optional style override for title

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
    this.backgroundColor,
    this.foregroundColor,
    this.titleTextStyle,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = backgroundColor ?? (filled ? scheme.secondaryContainer : scheme.surface);
    final fg = foregroundColor ?? (filled ? scheme.onSecondaryContainer : null);
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenW = MediaQuery.sizeOf(context).width;
        final isWide = screenW >= 900;
        final maxWidth = isWide ? 1000.0 : double.infinity;
        final horizontal = isWide ? 20.0 : 12.0;
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Card(
              margin: EdgeInsets.symmetric(horizontal: horizontal, vertical: 8),
              color: bg,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: padding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (leadingIcon != null) ...[
                          Icon(leadingIcon, color: fg ?? scheme.onSurfaceVariant),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            title,
                            style: (Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: fg,
                                    ) ?? const TextStyle()).merge(titleTextStyle),
                          ),
                        ),
                        if (actions != null) ...[
                          ...actions!,
                          const SizedBox(width: 4),
                        ],
                        if (count != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: (fg ?? scheme.primary).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '$count',
                                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                      color: fg ?? scheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                          ),
                        if (onSeeAll != null)
                          TextButton(
                            onPressed: onSeeAll,
                            style: TextButton.styleFrom(foregroundColor: fg),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Text('See all'),
                                SizedBox(width: 4),
                                Icon(Icons.chevron_right),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (foregroundColor != null)
                      IconTheme(
                        data: IconThemeData(color: foregroundColor),
                        child: DefaultTextStyle.merge(
                          style: TextStyle(color: foregroundColor),
                          child: child,
                        ),
                      )
                    else
                      child,
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
