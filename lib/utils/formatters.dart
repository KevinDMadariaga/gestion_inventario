import 'package:intl/intl.dart';

class Formatters {
  static final fecha = DateFormat('dd/MM/yyyy HH:mm');
  static final moneda = NumberFormat.currency(locale: 'es_CO', symbol: r'$');

  static double asDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? 0.0;
  }
}
