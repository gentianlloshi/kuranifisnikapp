import 'package:flutter/material.dart';
import '../theme/theme.dart';

/// Reusable header / toolbar for modal bottom sheets.
/// Provides consistent spacing, typography and optional actions.
class SheetHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? leadingIcon;
  final List<Widget>? actions;
  final VoidCallback? onClose;
  final EdgeInsets? padding;
  final bool divider;

  const SheetHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leadingIcon,
    this.actions,
    this.onClose,
    this.padding,
    this.divider = true,
  });

  @override
  Widget build(BuildContext context) {
    final pad = padding ?? EdgeInsets.only(top: context.spaceSm, bottom: context.spaceSm, left: 0, right: 0);
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: pad,
          child: Row(
            crossAxisAlignment: subtitle != null ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              if (leadingIcon != null) ...[
                Icon(leadingIcon, color: scheme.primary),
                SizedBox(width: context.spaceSm),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    if (subtitle != null) ...[
                      SizedBox(height: context.spaceXs),
                      Text(subtitle!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.75))),
                    ],
                  ],
                ),
              ),
              if (actions != null) ...actions!,
              if (onClose != null) ...[
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Mbyll',
                  onPressed: onClose,
                ),
              ],
            ],
          ),
        ),
        if (divider)
          Divider(
            height: 1,
            thickness: 0.6,
            color: Theme.of(context).dividerColor.withOpacity(0.6),
          ),
      ],
    );
  }
}
