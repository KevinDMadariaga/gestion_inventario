import 'package:flutter/material.dart';

enum ActionButtonStyle { primary, tonal, outline }

class ActionButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final ActionButtonStyle style;
  final double height;
  final double radius;

  /// Color sólido del botón cuando [style] == primary.
  final Color? color;
  /// Color del texto/ícono cuando [style] == primary.
  final Color? foregroundColor;

  const ActionButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.style = ActionButtonStyle.primary,
    this.height = 48,
    this.radius = 12,
    this.color,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null && !loading;

    // Colores por defecto desde el theme
    final Color primaryBg = color ?? Theme.of(context).colorScheme.primary;
    final Color primaryFg =
        foregroundColor ?? Theme.of(context).colorScheme.onPrimary;

    final Color tonalBg = Theme.of(context).colorScheme.secondaryContainer;
    final Color tonalFg = Theme.of(context).colorScheme.onSecondaryContainer;
    final Color outlineFg = Theme.of(context).colorScheme.primary;

    BoxDecoration deco;
    TextStyle textStyle;

    switch (style) {
      case ActionButtonStyle.primary:
        // 🔵 Un solo color (sin gradiente)
        deco = BoxDecoration(
          color: enabled ? primaryBg : primaryBg.withOpacity(0.5),
          borderRadius: BorderRadius.circular(radius),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        );
        textStyle = TextStyle(
          color: primaryFg,
          fontWeight: FontWeight.w700,
          letterSpacing: .2,
        );
        break;

      case ActionButtonStyle.tonal:
        deco = BoxDecoration(
          color: enabled ? tonalBg : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(radius),
        );
        textStyle = TextStyle(
          color: enabled ? tonalFg : Colors.grey.shade700,
          fontWeight: FontWeight.w700,
          letterSpacing: .2,
        );
        break;

      case ActionButtonStyle.outline:
        deco = BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: enabled ? outlineFg : Colors.grey.shade400,
            width: 1.4,
          ),
        );
        textStyle = TextStyle(
          color: enabled ? outlineFg : Colors.grey.shade600,
          fontWeight: FontWeight.w700,
          letterSpacing: .2,
        );
        break;
    }

    final spinnerColor =
        (style == ActionButtonStyle.primary) ? primaryFg : textStyle.color!;

    final Widget childContent = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (loading)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(spinnerColor),
            ),
          )
        else if (icon != null) ...[
          Icon(icon, size: 20, color: textStyle.color),
        ],
        if (icon != null || loading) const SizedBox(width: 8),
        Text(label, style: textStyle),
      ],
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(radius),
        child: Ink(
          height: height,
          decoration: deco,
          child: Center(child: childContent),
        ),
      ),
    );
  }
}
