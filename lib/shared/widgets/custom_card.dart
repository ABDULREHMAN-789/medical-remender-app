import 'package:flutter/material.dart';

class CustomCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? color;
  final BorderSide? borderSide;
  final double? height;

  const CustomCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.color,
    this.borderSide,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardTheme = theme.cardTheme;

    final isDark = theme.brightness == Brightness.dark;
    final shape = cardTheme.shape as RoundedRectangleBorder?;
    final border = borderSide ?? shape?.side ?? BorderSide.none;
    final borderRadius = shape?.borderRadius ?? BorderRadius.circular(20);

    Widget container = Container(
      height: height,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? theme.cardColor,
        borderRadius: borderRadius,
        border: border != BorderSide.none && border.style != BorderStyle.none
            ? Border.fromBorderSide(border)
            : null,
        boxShadow: isDark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x04000000),
                  blurRadius: 16,
                  offset: Offset(0, 4),
                )
              ],
      ),
      child: child,
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: borderRadius as BorderRadius,
        child: container,
      );
    }

    return container;
  }
}
