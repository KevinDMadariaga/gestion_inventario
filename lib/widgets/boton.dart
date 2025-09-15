import 'package:flutter/material.dart';

enum ActionButtonVariant { filled, outline }

class ActionButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color color;                // color principal (fondo en filled, borde/texto en outline)
  final Color? foregroundColor;     // color de texto/icono en filled
  final double height;
  final double borderRadius;
  final bool expand;                // true: ocupa todo el ancho
  final bool loading;
  final ActionButtonVariant variant;

  const ActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color = const Color(0xFF3B82F6),
    this.foregroundColor,
    this.height = 64,
    this.borderRadius = 16,
    this.expand = true,
    this.loading = false,
    this.variant = ActionButtonVariant.filled,
  });

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              valueColor: AlwaysStoppedAnimation<Color>(
                variant == ActionButtonVariant.filled
                    ? (foregroundColor ?? Colors.white)
                    : color,
              ),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 24),
                const SizedBox(width: 10),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          );

    final ButtonStyle style = switch (variant) {
      ActionButtonVariant.filled => ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: foregroundColor ?? Colors.white,
          minimumSize: Size(expand ? double.infinity : 0, height),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          elevation: 3,
          shadowColor: color.withOpacity(0.35),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
      ActionButtonVariant.outline => OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color, width: 1.5),
          minimumSize: Size(expand ? double.infinity : 0, height),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
    };

    final Widget button = switch (variant) {
      ActionButtonVariant.filled => ElevatedButton(
          onPressed: loading ? null : onPressed,
          style: style,
          child: child,
        ),
      ActionButtonVariant.outline => OutlinedButton(
          onPressed: loading ? null : onPressed,
          style: style,
          child: child,
        ),
    };

    return Semantics(
      button: true,
      enabled: onPressed != null && !loading,
      label: label,
      child: button,
    );
  }
}
