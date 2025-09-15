import 'package:flutter/material.dart';

/// Widget genérico para opciones de menú.
/// Puede ser usado como tile compacto o como card horizontal.
class AppMenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? color;
  final LinearGradient? gradient;
  final VoidCallback onTap;
  final bool expanded; // true = estilo card horizontal, false = estilo tile compacto

  const AppMenuCard({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.color,
    this.gradient,
    required this.onTap,
    this.expanded = false,
  });

  @override
  Widget build(BuildContext context) {
    if (expanded) {
      // --- Estilo card horizontal (como en VentasMenuPage) ---
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            height: 130,
            child: Row(
              children: [
                _buildIconBox(),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.black.withOpacity(.70),
                            fontSize: 13.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, color: Colors.black.withOpacity(.5)),
              ],
            ),
          ),
        ),
      );
    } else {
      // --- Estilo tile compacto (como en Home) ---
      return Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.04),
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color ?? Colors.blue, size: 48),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
  }

  /// Construye el recuadro con ícono + gradiente (para estilo expanded).
  Widget _buildIconBox() {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        gradient: gradient ?? LinearGradient(colors: [color ?? Colors.blue, color ?? Colors.blueAccent]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 34),
    );
  }
}
