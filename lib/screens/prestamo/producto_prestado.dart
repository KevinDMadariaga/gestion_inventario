import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gestion_inventario/screens/prestamo/prestamos_activos_page.dart';
import 'package:intl/intl.dart';
import 'package:gestion_inventario/services/mongo_service.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;

class GestionPrestamosPage extends StatefulWidget {
  const GestionPrestamosPage({super.key});

  @override
  State<GestionPrestamosPage> createState() => _GestionPrestamosPageState();
}

class _GestionPrestamosPageState extends State<GestionPrestamosPage> {
  // Branding (colores y gradientes)
  static const brandA = Color(0xFF6A11CB);
  static const brandB = Color(0xFF2575FC);
  static const bgSoft = Color(0xFFF7F8FC);

  LinearGradient get _g => const LinearGradient(
    colors: [brandA, brandB],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // --------- NUEVO PRÉSTAMO ----------
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  final _buscarCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  void _dismissKB() => FocusScope.of(context).unfocus();

  final _mon = NumberFormat.currency(locale: 'es_CO', symbol: r'$');

  List<Map<String, dynamic>> _resultados = [];
  final List<Map<String, dynamic>> _seleccionados = [];
  Timer? _debounce;
  bool _guardando = false;
  bool _mostrarBusqueda = true;

  // --------- LISTA PRÉSTAMOS ACTIVOS ----------
  Future<List<Map<String, dynamic>>>? _futureActivos;
  final Set<String> _loadingIds = {};
  final _fmtFecha = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _buscarCtrl.addListener(_onBuscarChanged);
    _futureActivos = _cargarPrestamosActivos();
  }

  @override
  void dispose() {
    _buscarCtrl.removeListener(_onBuscarChanged);
    _debounce?.cancel();
    _nombreCtrl.dispose();
    _telCtrl.dispose();
    _buscarCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ---------- Helpers de estilo ----------
  InputDecoration _input(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: brandA),
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: brandA, width: 1.6),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

Widget _gradientButton({
  required String label,
  required IconData icon,
  required VoidCallback? onPressed,
  bool busy = false,
}) {
  final radius = BorderRadius.circular(14);
  return Material(
    elevation: onPressed != null ? 2 : 0,
    color: Colors.transparent,
    borderRadius: radius,
    child: InkWell(
      borderRadius: radius,
      onTap: busy ? null : onPressed,
      child: Ink(
        decoration: BoxDecoration(
          gradient: onPressed != null
              ? LinearGradient(
                  colors: [
                    const Color.fromRGBO(244, 143, 177, 1), // Color neutro
                    const Color.fromRGBO(244, 143, 177, 1), // Color neutro
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: onPressed != null ? null : Colors.grey.shade300,
          borderRadius: radius,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (busy)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            else
              const SizedBox(),
            if (!busy) Icon(icon, color: Colors.white),
            if (!busy) const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  OutlinedButton _outlinedNavButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      icon: Icon(icon, color: brandA),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w700, color: brandA),
      ),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: brandA),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      onPressed: onPressed,
    );
  }

  // ---------- Helpers data ----------
  String _oidHex(dynamic raw) {
    if (raw == null) return '';
    if (raw is Map && raw[r'$oid'] is String) return raw[r'$oid'] as String;
    final s = raw.toString();
    final m = RegExp(r'ObjectId\("([0-9a-fA-F]{24})"\)').firstMatch(s);
    return m != null ? m.group(1)! : s;
  }

  Widget _placeholder(double w, double h, {bool broken = false}) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        broken ? Icons.broken_image : Icons.photo,
        size: w * 0.6,
        color: Colors.grey,
      ),
    );
  }

  Widget _buildImage(
    Map<String, dynamic> doc, {
    double w = 52,
    double h = 52,
    double radius = 12,
    BoxFit fit = BoxFit.cover,
  }) {
    final String b64 = (doc['fotoBase64'] ?? '') as String;
    final String f = (doc['foto'] ?? '') as String;

    Widget _img() {
      if (b64.isNotEmpty) {
        try {
          return Image.memory(
            base64Decode(b64),
            fit: fit,
            filterQuality: FilterQuality.medium,
          );
        } catch (_) {}
      }
      if (f.startsWith('http')) {
        return Image.network(
          f,
          fit: fit,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, __, ___) => _placeholder(w, h, broken: true),
        );
      }
      if (f.isNotEmpty && f.startsWith('/')) {
        final file = File(f);
        if (file.existsSync()) {
          return Image.file(
            file,
            fit: fit,
            filterQuality: FilterQuality.medium,
          );
        }
      }
      if (f.isNotEmpty) {
        try {
          return Image.memory(
            base64Decode(f),
            fit: fit,
            filterQuality: FilterQuality.medium,
          );
        } catch (_) {}
      }
      return _placeholder(w, h);
    }

    // Caja dura: nunca excede w x h
    return SizedBox(
      width: w,
      height: h,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: FittedBox(
          fit: fit,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(width: w, height: h, child: _img()),
        ),
      ),
    );
  }

  double get _subtotalSeleccionados {
    return _seleccionados.fold<double>(0.0, (acc, p) {
      final pv = p['precioVenta'];
      final v = (pv is num) ? pv.toDouble() : double.tryParse('$pv') ?? 0.0;
      return acc + v;
    });
  }

  // ---------- Buscar productos (solo disponibles) ----------
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

      // evitar repetidos
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

  void _agregarProducto(Map<String, dynamic> p) {
    final estado = (p['estado'] ?? 'disponible').toString().toLowerCase();
    if (estado != 'disponible') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solo se pueden prestar prendas disponibles'),
        ),
      );
      return;
    }
    setState(() {
      _seleccionados.add(p);
      _resultados.removeWhere((e) => '${e['_id']}' == '${p['_id']}');
      _buscarCtrl.clear();
      _resultados.clear();
      _mostrarBusqueda = false; // esconder card búsqueda
    });
    _dismissKB();
  }

  void _quitarSeleccion(Map<String, dynamic> p) {
    setState(() => _seleccionados.remove(p));
  }

  Future<void> _guardarPrestamo() async {
    if (!_formKey.currentState!.validate()) return;
    if (_seleccionados.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos una prenda')),
      );
      return;
    }

    setState(() => _guardando = true);

    try {
      // ---------- Armar documento ----------
      final prendas = _seleccionados.map((p) {
        final pv = (p['precioVenta'] is num)
            ? (p['precioVenta'] as num).toDouble()
            : double.tryParse('${p['precioVenta']}') ?? 0.0;

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

        return {
          'productoId': '${p['_id']}',
          'nombre': p['nombre'],
          'precioVenta': pv,
          'fotoBase64': fotoBase64 ?? '',
          'foto': p['foto'],
          'talla': p['talla'],
          'color': p['color'],
          'sku': p['sku'],
          'estadoLinea': 'prestado',
        };
      }).toList();

      final doc = {
        'cliente': {
          'nombre': _nombreCtrl.text.trim(),
          'telefono': _telCtrl.text.trim(),
        },
        'prendas': prendas,
        'subtotal': _subtotalSeleccionados,
        'fechaPrestamo': DateTime.now().toIso8601String(),
        'estado': 'activo',
      };

      // ---------- Fase 1: guardar préstamo ----------
      String idHex;
      try {
        idHex = await MongoService().savePrestamo(doc);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar el préstamo: $e')),
        );
        return; // no seguimos con fases posteriores
      }

      // ---------- Fase 2: marcar productos como prestados ----------
      bool estadosOk = true;
      try {
        final ids = _seleccionados
            .map((p) => _oidHex(p['_id']))
            .where((s) => s.isNotEmpty)
            .toList();
        await MongoService().marcarProductosPrestados(ids);
      } catch (e) {
        estadosOk = false;
      }

      // ---------- Mensaje final ----------
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            estadosOk
                ? '✅ Préstamo registrado'
                : '✅ Préstamo registrado, pero no se pudieron actualizar algunos estados.',
          ),
        ),
      );

      // ---------- Limpieza y refresh ----------
      _limpiarNuevoPrestamo();
      setState(() {
        _futureActivos = _cargarPrestamosActivos();
      });
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _limpiarNuevoPrestamo() {
    setState(() {
      _formKey.currentState?.reset();
      _nombreCtrl.clear();
      _telCtrl.clear();
      _buscarCtrl.clear();
      _resultados.clear();
      _seleccionados.clear();
      _mostrarBusqueda = false;
    });
    _dismissKB();
  }

  // ---------- Prestamos activos ----------
  Future<List<Map<String, dynamic>>> _cargarPrestamosActivos() async {
    return MongoService().getPrestamos(estado: 'activo');
  }

  Future<void> _refreshActivos() async {
    final future = _cargarPrestamosActivos();
    if (!mounted) return;
    setState(() {
      _futureActivos = future;
    });
    await future;
  }

  // Cambiar estado de una línea y del producto
  Future<void> _marcarLinea(
    Map<String, dynamic> prestamo,
    Map<String, dynamic> linea, {
    required String nuevoEstadoLinea, // 'devuelto' | 'vendido'
  }) async {
    final prestamoId = _oidHex(prestamo['_id']);
    final pid = '${linea['productoId']}';

    setState(() => _loadingIds.add('$prestamoId|$pid'));
    try {
      if (nuevoEstadoLinea == 'devuelto') {
        await MongoService().marcarProductosDisponibles([pid]);
      } else if (nuevoEstadoLinea == 'vendido') {
        await MongoService().marcarProductosVendidos([pid]);
      }

      final List prendas = (prestamo['prendas'] ?? []) as List;
      final nuevas = prendas.map((raw) {
        final m = (raw as Map).cast<String, dynamic>();
        if ('${m['productoId']}' == pid) {
          return {...m, 'estadoLinea': nuevoEstadoLinea};
        }
        return m;
      }).toList();

      final bool todasResueltas = nuevas.every((m) {
        final el = (m['estadoLinea'] ?? 'prestado').toString();
        return el == 'devuelto' || el == 'vendido';
      });

      await MongoService().actualizarPrestamo(
        prestamoId,
        prendas: nuevas,
        estado: todasResueltas ? 'cerrado' : 'activo',
      );

      await _refreshActivos();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error actualizando línea: $e')));
      }
    } finally {
      if (mounted) setState(() => _loadingIds.remove('$prestamoId|$pid'));
    }
  }

  // Registrar venta de TODAS las líneas marcadas como 'vendido' en ese préstamo
  Future<void> _registrarVentaDesdePrestamo(
    Map<String, dynamic> prestamo,
  ) async {
    final prestamoId = _oidHex(prestamo['_id']);
    final cliente = (prestamo['cliente'] ?? {}) as Map;
    final List prendas = (prestamo['prendas'] ?? []) as List;

    final vendidas = prendas
        .where(
          (e) =>
              (e as Map)['estadoLinea']?.toString().toLowerCase() == 'vendido',
        )
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();

    if (vendidas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Marca al menos una prenda como vendida')),
      );
      return;
    }

    final subtotal = vendidas.fold<double>(0.0, (acc, p) {
      final v = p['precioVenta'];
      final d = (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0.0;
      return acc + d;
    });

    final venta = {
      'cliente': {
        'nombre': '${cliente['nombre'] ?? ''}',
        'telefono': '${cliente['telefono'] ?? ''}',
      },
      'productos': vendidas
          .map(
            (p) => {
              'productoId': p['productoId'],
              'nombre': p['nombre'],
              'precioVendido': p['precioVenta'],
              'fotoBase64': p['fotoBase64'] ?? '',
              'foto': p['foto'] ?? '',
              'sku': p['sku'],
              'talla': p['talla'],
              'color': p['color'],
            },
          )
          .toList(),
      'subtotal': subtotal,
      'descuento': 0.0,
      'total': subtotal,
      'fechaVenta': DateTime.now().toIso8601String(),
      'origen': {'tipo': 'prestamo', 'prestamoId': prestamoId},
    };

    setState(() => _loadingIds.add('$prestamoId|venta'));
    try {
      await MongoService().saveVenta(venta);

      final nuevas = prendas
          .map((raw) => (raw as Map).cast<String, dynamic>())
          .toList();
      final todasResueltas = nuevas.every((m) {
        final el = (m['estadoLinea'] ?? 'prestado').toString();
        return el == 'devuelto' || el == 'vendido';
      });

      await MongoService().actualizarPrestamo(
        prestamoId,
        estado: todasResueltas ? 'cerrado' : 'activo',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ Venta registrada')));
      await _refreshActivos();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error registrando venta: $e')));
      }
    } finally {
      if (mounted) setState(() => _loadingIds.remove('$prestamoId|venta'));
    }
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: _dismissKB,
      child: Scaffold(
        backgroundColor: bgSoft,
        appBar: AppBar(
          elevation: 0,
          centerTitle: true,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.assignment_returned_outlined, size: 24),
              SizedBox(width: 8),
              Text('Prendas prestadas', style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          foregroundColor: Colors.white,
          backgroundColor: const Color.fromRGBO(244, 143, 177, 1)
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, c) {
              final nuevoPrestamo = _buildNuevoPrestamoCard(cs);

              // Esta pantalla solo crea préstamos; el manejo de activos va en otra.
              return ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  nuevoPrestamo,
                  const SizedBox(height: 12),
                  _outlinedNavButton(
                    icon: Icons.pending_actions_outlined,
                    label: 'Gestionar préstamos activos',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const PrestamosActivosPage(),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // --------- Widgets de página ---------
  Widget _buildNuevoPrestamoCard(ColorScheme cs) {
    return Card(
      elevation: 1.5,
      shadowColor: brandA.withOpacity(0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Título con cinta
              const SizedBox(height: 12),

              // Datos cliente
              TextFormField(
                controller: _nombreCtrl,
                decoration: _input('Nombre del cliente', Icons.person_outline),
                textInputAction: TextInputAction.next,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Ingrese el nombre'
                    : null,
              ),
              const SizedBox(height: 10),

              TextFormField(
                controller: _telCtrl,
                decoration: _input('Teléfono', Icons.phone_outlined),
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly, // 👈 solo números
                  LengthLimitingTextInputFormatter(10), // 👈 máximo 10 dígitos
                ],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _dismissKB(),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Ingrese el teléfono';
                  }
                  if (v.length != 10) {
                    // 👈 exactamente 10 dígitos
                    return 'El número debe tener 10 dígitos';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Búsqueda
              if (_mostrarBusqueda) ...[
                Row(
                  children: [
                    Icon(Icons.search, size: 20, color: brandA),
                    const SizedBox(width: 8),
                    const Text(
                      'Buscar prenda',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _buscarCtrl,
                  focusNode: _searchFocus,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _dismissKB(),
                  decoration: _input('Nombre…', Icons.search),
                ),
                const SizedBox(height: 10),
                if (_resultados.isNotEmpty)
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F6FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE0EAFF)),
                    ),
                    constraints: const BoxConstraints(maxHeight: 240),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _resultados.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final p = _resultados[i];
                        final pv = (p['precioVenta'] is num)
                            ? (p['precioVenta'] as num).toDouble()
                            : double.tryParse('${p['precioVenta']}') ?? 0.0;
                        return ListTile(
                          dense: true,
                          leading: _buildImage(p, w: 48, h: 48, radius: 10),
                          title: Text(
                            p['nombre'] ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(_mon.format(pv)),
                          trailing: IconButton.filled(
                            icon: const Icon(Icons.add),
                            onPressed: () => _agregarProducto(p),
                          ),
                        );
                      },
                    ),
                  ),
              ],

              const SizedBox(height: 14),

              // Seleccionados
              Card(
                elevation: 0,
                color: const Color(0xFFFAFBFF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.shopping_bag_outlined,
                            size: 20,
                            color: brandA,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Prendas seleccionadas',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const Spacer(),
                          if (!_mostrarBusqueda)
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _mostrarBusqueda = true;
                                  _buscarCtrl.clear();
                                  _resultados.clear();
                                });
                                Future.delayed(
                                  const Duration(milliseconds: 60),
                                  () {
                                    if (mounted)
                                      FocusScope.of(
                                        context,
                                      ).requestFocus(_searchFocus);
                                  },
                                );
                              },
                              icon: const Icon(Icons.add_circle_outline),
                              label: const Text('Agregar'),
                              style: TextButton.styleFrom(
                                foregroundColor: brandA,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (_seleccionados.isEmpty)
                        const Text(
                          'Aún no has agregado prendas',
                          style: TextStyle(color: Colors.black54),
                        )
                      else
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          constraints: const BoxConstraints(maxHeight: 320),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: _seleccionados.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 10),
                            itemBuilder: (_, i) {
                              final p = _seleccionados[i];
                              final pv = (p['precioVenta'] is num)
                                  ? (p['precioVenta'] as num).toDouble()
                                  : double.tryParse('${p['precioVenta']}') ??
                                        0.0;
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildImage(p, w: 100, h: 100, radius: 12),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            p['nombre'] ?? '',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            _mon.format(pv),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.close,
                                        color: Colors.redAccent,
                                      ),
                                      onPressed: () => _quitarSeleccion(p),
                                      tooltip: 'Quitar',
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 10),
                      const Divider(height: 1),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Subtotal',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            _mon.format(_subtotalSeleccionados),
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              _gradientButton(
                label: 'Guardar préstamo',
                icon: Icons.save_outlined,
                onPressed: _guardando ? null : _guardarPrestamo,
                busy: _guardando,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // (Se mantiene aquí por si la sigues usando en esta pantalla.)
  Widget _buildPrestamosActivosCard(ColorScheme cs) {
    final vh = MediaQuery.of(context).size.height;
    final double listHeight = (vh * 0.55).clamp(260.0, 640.0);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: const [
            // … tu contenido actual …
          ],
        ),
      ),
    );
  }

  Widget _rowInfo(String l, String v) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(l),
        Flexible(child: Text(v, textAlign: TextAlign.right)),
      ],
    );
  }
}
