import 'package:flutter/material.dart';

/// Clase que contiene todos los colores personalizados de la aplicación
class AppColors {
  // Constructor privado para evitar instanciación
  AppColors._();

  // Colores primarios
  static const Color primary = Color(0xFFEC407A); // Rosa
  static const Color primaryLight = Color(0xFFF8BBD0);
  static const Color primaryDark = Color(0xFFAD1457);

  // Colores de acento
  static const Color accent = Color(0xFF0EA5E9); // Azul
  static const Color accentLight = Color(0xFF38BDF8);
  static const Color accentDark = Color(0xFF0284C7);

  // Colores de estados
  static const Color success = Color(0xFF22C55E); // Verde
  static const Color successLight = Color(0xFF4ADE80);
  static const Color successDark = Color(0xFF16A34A);

  static const Color error = Color(0xFFEF4444); // Rojo
  static const Color errorLight = Color(0xFFF87171);
  static const Color errorDark = Color(0xFFDC2626);

  static const Color warning = Color(0xFFF59E0B); // Naranja/Amarillo
  static const Color warningLight = Color(0xFFFBBF24);
  static const Color warningDark = Color(0xFFD97706);

  static const Color info = Color(0xFF6366F1); // Índigo/Morado
  static const Color infoLight = Color(0xFF818CF8);
  static const Color infoDark = Color(0xFF4F46E5);

  // Colores de fondo
  static const Color background = Color(0xFFF4F5F7);
  static const Color backgroundLight = Color(0xFFFFFFFF);
  static const Color backgroundDark = Color(0xFFE5E7EB);

  // Colores de texto
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color textLight = Color(0xFFFFFFFF);

  // Colores de bordes y divisores
  static const Color border = Color(0xFFE5E7EB);
  static const Color divider = Color(0xFFD1D5DB);

  // Colores adicionales del menú
  static const Color menuVentas = Color(0xFF0EA5E9);
  static const Color menuApartados = Color(0xFFF59E0B);
  static const Color menuInventario = Color(0xFF6366F1);
  static const Color menuPrestamos = Color(0xFF22C55E);
  static const Color menuCambios = Color(0xFF8B5CF6);
  static const Color menuConfig = Color(0xFF9CA3AF);

  // Gradientes predefinidos
  static const LinearGradient gradientPrimary = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient gradientSuccess = LinearGradient(
    colors: [success, successLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient gradientAccent = LinearGradient(
    colors: [accent, accentLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient gradientWarning = LinearGradient(
    colors: [warning, warningLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Método helper para obtener color con opacidad
  static Color withOpacity(Color color, double opacity) {
    return color.withOpacity(opacity);
  }

  // Método helper para obtener una sombra personalizada
  static List<BoxShadow> getShadow({
    Color color = Colors.black,
    double opacity = 0.1,
    double blurRadius = 10,
    Offset offset = const Offset(0, 4),
  }) {
    return [
      BoxShadow(
        color: color.withOpacity(opacity),
        blurRadius: blurRadius,
        offset: offset,
      ),
    ];
  }
}
