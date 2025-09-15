import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gestion_inventario/widgets/boton.dart';
import 'package:intl/intl.dart';
import 'package:gestion_inventario/services/mongo_service.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;

class RegistrarVentaPage extends StatefulWidget {
  const RegistrarVentaPage({super.key});

  @override
  State<RegistrarVentaPage> createState() => _RegistrarVentaPageState();
}

class _RegistrarVentaPageState extends State<RegistrarVentaPage> {
  void _closeKeyboard() => FocusScope.of(context).unfocus();
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _buscarCtrl = TextEditingController();
  final _descuentoCtrl = TextEditingController();
  final _pagaCtrl = TextEditingController();

  final _mon = NumberFormat.currency(locale: 'es_CO', symbol: r'$');

  // Resultados de búsqueda y selección
  List<Map<String, dynamic>> _resultados = [];
  final List<Map<String, dynamic>> _seleccionados = [];

  // Debounce para la búsqueda
  Timer? _debounce;

  // Estado de guardado
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    MongoService().connect(); // opcional
    _buscarCtrl.addListener(_onBuscarChanged);
  }

  @override
  void dispose() {
    _buscarCtrl.removeListener(_onBuscarChanged);
    _debounce?.cancel();
    _nombreCtrl.dispose();
    _telefonoCtrl.dispose();
    _buscarCtrl.dispose();
    _descuentoCtrl.dispose();
    _pagaCtrl.dispose();
    super.dispose();
  }

  // ---------- IMAGEN ----------
  Widget _buildProductImageFromDoc(
    Map<String, dynamic> doc, {
    double w = 44,
    double h = 44,
  }) {
    final String b64 = (doc['fotoBase64'] ?? '') as String;
    final String pathOrUrl = (doc['foto'] ?? '') as String;

    if (b64.isNotEmpty) {
      try {
        final bytes = base64Decode(b64);
        return Image.memory(bytes, width: w, height: h, fit: BoxFit.cover);
      } catch (_) {}
    }
    if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
      return Image.network(
        pathOrUrl,
        width: w,
        height: h,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _imgPlaceholder(w, h, broken: true),
      );
    }
    if (pathOrUrl.isNotEmpty) {
      final f = File(pathOrUrl);
      if (f.existsSync()) {
        return Image.file(f, width: w, height: h, fit: BoxFit.cover);
      }
    }
    return _imgPlaceholder(w, h);
  }

  Widget _imgPlaceholder(double w, double h, {bool broken = false}) {
    return Container(
      width: w,
      height: h,
      color: Colors.grey[300],
      child: Icon(broken ? Icons.broken_image : Icons.photo, size: w * 0.6),
    );
  }

  // ---------- Totales / helpers ----------
  double _asDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? 0.0;
  }

  double get _subtotal {
    return _seleccionados.fold<double>(0.0, (acc, p) {
      final v = _asDouble(p['precioVenta']);
      return acc + v;
    });
  }

  double get _descuento {
    final txt = _descuentoCtrl.text.trim().replaceAll(',', '.');
    final d = double.tryParse(txt) ?? 0.0;
    if (d < 0) return 0.0;
    if (d > _subtotal) return _subtotal;
    return d;
  }

  double get _total => (_subtotal - _descuento).clamp(0.0, double.infinity);

  double get _pagaCon {
    final t = _pagaCtrl.text.trim().replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(t) ?? 0.0;
  }

  double get _vueltos => (_pagaCon - _total).clamp(0.0, double.infinity);

  /// Ganancia estimada (aplicando el descuento de forma proporcional a cada línea)
  double get _gananciaEstimada {
    final sub = _subtotal;
    if (sub <= 0) return 0.0;
    final desc = _descuento;
    double totalGan = 0.0;

    for (final p in _seleccionados) {
      final pv = _asDouble(p['precioVenta']);
      final propor = pv / sub; // participación de la línea
      final descLinea = desc * propor; // descuento prorrateado
      final vendidoNeto = pv - descLinea; // lo realmente cobrado por esa prenda

      final costo = _asDouble(
        p['precioCompra'],
      ); // usa precioCompra del producto si está
      totalGan += (vendidoNeto - costo);
    }
    return totalGan;
  }

  // ---------- Búsqueda ----------
  void _onBuscarChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      await _buscarProductos(_buscarCtrl.text.trim());
    });
  }

  Future<void> _buscarProductos(String q) async {
    if (q.isEmpty) {
      setState(() => _resultados = []);
      return;
    }
    try {
      List<Map<String, dynamic>> r = [];
      try {
        r = await MongoService().getProductosByNombre(q);
      } catch (_) {
        final all = await MongoService().getData();
        r = all.where((p) {
          final n = (p['nombre'] ?? '').toString().toLowerCase();
          return n.contains(q.toLowerCase());
        }).toList();
      }

      // solo disponibles
      r = r.where((e) {
        final estado = (e['estado'] ?? 'disponible')
            .toString()
            .toLowerCase()
            .trim();
        return estado == 'disponible';
      }).toList();

      // evita duplicados ya seleccionados
      final selIds = _seleccionados.map((e) => '${e['_id']}').toSet();
      r = r.where((e) => !selIds.contains('${e['_id']}')).toList();

      setState(() => _resultados = r);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al buscar productos: $e')),
        );
      }
    }
  }

  // ---------- Acciones ----------
  void _agregarProducto(Map<String, dynamic> p) {
    _closeKeyboard();
    final isSold = (p['estado'] ?? '').toString().toLowerCase() == 'vendido';
    if (isSold) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No puedes agregar este producto: ya fue vendido.'),
        ),
      );
      return;
    }
    setState(() {
      _seleccionados.add(p);
      _resultados.removeWhere((e) => '${e['_id']}' == '${p['_id']}');
      _buscarCtrl.clear();
      _resultados.clear();
    });
  }

  void _eliminarProducto(Map<String, dynamic> p) {
    setState(() {
      _seleccionados.remove(p);
    });
  }

  String _oidHex(dynamic raw) {
    if (raw == null) return '';
    if (raw is Map && raw[r'$oid'] is String) return raw[r'$oid'] as String;
    final s = raw.toString();
    final m = RegExp(r'ObjectId\("([0-9a-fA-F]{24})"\)').firstMatch(s);
    return m != null ? m.group(1)! : s;
  }

  Future<void> _guardarVenta() async {
    final form = _formKey.currentState;
    if (form == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Formulario no encontrado (no está montado).'),
          ),
        );
      }
      return;
    }
    if (!form.validate()) return;
    form.save();
    FocusScope.of(context).unfocus();

    if (_seleccionados.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Agrega al menos un producto')),
        );
      }
      return;
    }

    setState(() => _guardando = true);

    try {
      // 1) Totales base
      final double sub = _subtotal;
      final double desc = _descuento;
      final double tot = (sub - desc).clamp(0.0, double.infinity);

      // 2) Preparar líneas con prorrateo del descuento y ganancia por línea
      final List<Map<String, dynamic>> productosLinea = [];
      double gananciaTotal = 0.0;

      for (final p in _seleccionados) {
        final pv = _asDouble(p['precioVenta']);
        final propor = sub <= 0 ? 0.0 : (pv / sub);
        final descLinea = desc * propor;
        final vendidoNeto = pv - descLinea;

        final costo = _asDouble(p['precioCompra']); // si no existe, 0.0
        final gananciaLinea = vendidoNeto - costo;
        gananciaTotal += gananciaLinea;

        String? fotoBase64 = (p['fotoBase64'] ?? '') as String?;
        if ((fotoBase64 == null || fotoBase64.isEmpty)) {
          final f = (p['foto'] ?? '') as String;
          if (f.isNotEmpty && !(f.startsWith('http') || f.startsWith('/'))) {
            try {
              base64Decode(f);
              fotoBase64 = f;
            } catch (_) {}
          }
        }

        productosLinea.add({
          'productoId': '${p['_id']}',
          'nombre': p['nombre'],
          'precioVendido': pv, // precio de lista
          'precioVendidoNeto':
              vendidoNeto, // precio después de prorratear descuento
          'precioCompra': costo, // guardamos costo
          'gananciaLinea': gananciaLinea, // guardamos ganancia de esta línea
          'fotoBase64': fotoBase64 ?? '',
          'foto': p['foto'] ?? '',
          'sku': p['sku'],
          'talla': p['talla'],
          'color': p['color'],
        });
      }

      // 3) Documento de venta con gananciaTotal
      final venta = {
        'cliente': {
          'nombre': _nombreCtrl.text.trim(),
          'telefono': _telefonoCtrl.text.trim(),
        },
        'productos': productosLinea,
        'subtotal': sub,
        'descuento': desc,
        'total': tot,
        'gananciaTotal': gananciaTotal, // 👈 se guarda la ganancia total
        'fechaVenta': DateTime.now().toIso8601String(),
        // 'tipoVenta': 'venta',  // opcional
      };

      // 4) Guardar venta
      await MongoService().saveVenta(venta);

      // 5) Marcar productos como vendidos
      final idsVendidos = _seleccionados
          .map((p) => _oidHex(p['_id']))
          .where((s) => s.isNotEmpty)
          .toList();

      if (idsVendidos.isNotEmpty) {
        try {
          await MongoService().marcarProductosVendidos(idsVendidos);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Venta guardada, pero no se pudo actualizar estados: $e',
                ),
              ),
            );
          }
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ Venta registrada')));

      _limpiarFormulario();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al guardar venta: $e')));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _limpiarFormulario() {
    setState(() {
      _formKey.currentState?.reset();
      _nombreCtrl.clear();
      _telefonoCtrl.clear();
      _buscarCtrl.clear();
      _descuentoCtrl.clear();
      _resultados.clear();
      _seleccionados.clear();
      _pagaCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    const Color brandColor = Color(0xFF16A34A); // green
    const Color brandAccent = Color(0xFF0EA5E9); // cyan

    return Form(
      key: _formKey,
      child: Scaffold(
        appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.point_of_sale, size: 24),
            SizedBox(width: 8),
            Text('Registrar Venta', style: TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        foregroundColor: Colors.white,
        backgroundColor: const Color.fromRGBO(244, 143, 177, 1),
      ),

        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: ListView(
                padding: const EdgeInsets.all(19),
                children: [
                  // ===== Datos del cliente =====
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    color: Colors.grey[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.person_outline),
                              SizedBox(width: 8),
                              Text(
                                'Datos del cliente',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _nombreCtrl,
                            decoration: InputDecoration(
                              labelText: 'Nombre del cliente',
                              prefixIcon: const Icon(Icons.badge_outlined),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Ingrese el nombre del cliente'
                                : null,
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _telefonoCtrl,
                            keyboardType:
                                TextInputType.number, // teclado numérico
                            inputFormatters: [
                              FilteringTextInputFormatter
                                  .digitsOnly, // solo dígitos (bloquea +, espacios, etc.)
                            ],
                            // opcional: límite de dígitos (ej. 10)
                            maxLength: 10,

                            decoration: InputDecoration(
                              labelText: 'Teléfono',
                              prefixIcon: const Icon(Icons.phone_outlined),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              counterText:
                                  '', // oculta el contador de caracteres si no lo quieres ver
                            ),
                            validator: (v) {
                              final s = (v ?? '').trim();
                              if (s.isEmpty) return 'Ingrese el teléfono';
                              if (!RegExp(r'^\d+$').hasMatch(s))
                                return 'Solo números';
                              if (s.length != 10)
                                return 'Debe tener 10 dígitos'; // ajusta si usas otra longitud
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),

                  // ===== Buscar producto =====
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    color: Colors.grey[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.search),
                              SizedBox(width: 8),
                              Text(
                                'Buscar producto',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _buscarCtrl,
                            decoration: InputDecoration(
                              labelText:
                                  'Buscar por nombre (solo “disponibles”)',
                              hintText: 'Ej: Camiseta blanca',
                              prefixIcon: const Icon(Icons.search),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          if (_resultados.isNotEmpty)
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _resultados.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final p = _resultados[index];
                                  final precio = _asDouble(p['precioVenta']);

                                  return ListTile(
                                    leading: _buildProductImageFromDoc(
                                      p,
                                      w: 48,
                                      h: 48,
                                    ),
                                    title: Text(
                                      p['nombre'] ?? '',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(_mon.format(precio)),
                                        if ((p['descripcion'] ?? '')
                                            .toString()
                                            .isNotEmpty)
                                          Text(
                                            p['descripcion'],
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                    trailing: IconButton.filledTonal(
                                      icon: const Icon(Icons.add),
                                      onPressed: () => _agregarProducto(p),
                                      tooltip: 'Agregar a la venta',
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ===== Productos seleccionados =====
                  if (_seleccionados.isNotEmpty)
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      color: Colors.grey[50],
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.shopping_bag_outlined),
                                SizedBox(width: 8),
                                Text(
                                  'Productos seleccionados',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _seleccionados.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final p = _seleccionados[index];
                                final precio = _asDouble(p['precioVenta']);

                                return ListTile(
                                  leading: Stack(
                                    alignment: Alignment.topRight,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: _buildProductImageFromDoc(
                                          p,
                                          w: 56,
                                          h: 56,
                                        ),
                                      ),
                                      Positioned(
                                        right: -6,
                                        top: -6,
                                        child: IconButton(
                                          icon: const Icon(
                                            Icons.close,
                                            size: 18,
                                          ),
                                          color: Colors.redAccent,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () => _eliminarProducto(p),
                                          tooltip: 'Eliminar',
                                        ),
                                      ),
                                    ],
                                  ),
                                  title: Text(p['nombre'] ?? ''),
                                  subtitle: Text(_mon.format(precio)),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_seleccionados.isNotEmpty) const SizedBox(height: 16),

                  // ===== Resumen =====
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    color: Colors.green[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.receipt_long_outlined),
                              SizedBox(width: 8),
                              Text(
                                'Resumen de venta',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _rowResumen('Subtotal', _mon.format(_subtotal)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _descuentoCtrl,
                            decoration: InputDecoration(
                              labelText: 'Descuento (monto)',
                              prefixIcon: const Icon(Icons.discount),
                              hintText: '0',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 8),
                          _rowResumen(
                            'Total',
                            _mon.format(_total),
                            isTotal: true,
                          ),
                          /*
                          const Divider(height: 18),
                          // 👇 NUEVO: Ganancia estimada
                          _rowResumen('Ganancia estimada', _mon.format(_gananciaEstimada),
                          isTotal: true), */
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ===== Acciones =====
                  Row(
                    children: [
                      Expanded(
                        child: ActionButton(
                          label: 'Limpiar',
                          icon: Icons.cleaning_services_outlined,
                          variant: ActionButtonVariant.outline,
                          color: const Color.fromRGBO(244, 143, 177, 1),
                          onPressed: _guardando ? null : _limpiarFormulario,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ActionButton(
                          label: 'Registrar',
                          icon: Icons.save_outlined,
                          color: const Color.fromRGBO(244, 143, 177, 1),
                          onPressed: _guardando ? null : _guardarVenta,
                          loading: _guardando,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _rowResumen(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isTotal ? Colors.green[800] : null,
          ),
        ),
      ],
    );
  }
}
