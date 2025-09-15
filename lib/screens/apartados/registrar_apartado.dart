import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ⬅️ para inputFormatters y ocultar teclado
import 'package:intl/intl.dart';
import 'package:gestion_inventario/services/mongo_service.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;

class CrearApartadoPage extends StatefulWidget {
  const CrearApartadoPage({super.key});

  @override
  State<CrearApartadoPage> createState() => _CrearApartadoPageState();
}

class _CrearApartadoPageState extends State<CrearApartadoPage> {
  // muestra/oculta el card de búsqueda
  bool _mostrarBusqueda = true;
  // para enfocar el TextField de búsqueda cuando se reabra
  final FocusNode _buscarFocus = FocusNode();
  void _closeKeyboard() => FocusScope.of(context).unfocus();
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _buscarCtrl = TextEditingController();
  final _abonoCtrl = TextEditingController();
  final _descuentoCtrl = TextEditingController();

  final _mon = NumberFormat.currency(locale: 'es_CO', symbol: r'$');

  List<Map<String, dynamic>> _resultados = [];
  final List<Map<String, dynamic>> _seleccionados = [];

  Timer? _debounce;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _buscarCtrl.addListener(_onBuscarChanged);
  }

  @override
  void dispose() {
    _buscarCtrl.removeListener(_onBuscarChanged);
    _debounce?.cancel();
    _nombreCtrl.dispose();
    _telefonoCtrl.dispose();
    _buscarCtrl.dispose();
    _abonoCtrl.dispose();
    _descuentoCtrl.dispose();
    super.dispose();
  }

  // ===== Identificador AP-{NOMBRE} =====
  String _identificadorDesdeNombre(String nombre) {
    String s = nombre.trim().toUpperCase();
    s = s
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U')
        .replaceAll('Ü', 'U')
        .replaceAll('Ñ', 'N');
    final first = s
        .split(RegExp(r'\s+'))
        .firstWhere((e) => e.isNotEmpty, orElse: () => 'CLIENTE');
    final clean = first.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    return 'AP-$clean';
  }

  Future<void> _mostrarIdentificadorCentral({
    required String identificador,
    required String nombre,
  }) async {
    _closeKeyboard();
    try {
      await SystemChannels.textInput.invokeMethod('TextInput.hide');
    } catch (_) {}
    if (!mounted) return;

    await showGeneralDialog(
      barrierDismissible: true,
      barrierLabel: 'ID',
      barrierColor: Colors.black54,
      context: context,
      pageBuilder: (_, __, ___) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 520),
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.15),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.local_mall_rounded,
                    size: 48,
                    color: Colors.black87,
                  ),
                  const SizedBox(height: 10),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      identificador,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 56,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      nombre.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Listo'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ---- Helpers de imagen (base64 -> URL -> ruta -> placeholder) ----
  Widget _buildImageFromDoc(
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
        errorBuilder: (_, __, ___) => _placeholder(w, h, broken: true),
      );
    }
    if (pathOrUrl.isNotEmpty && pathOrUrl.startsWith('/')) {
      final f = File(pathOrUrl);
      if (f.existsSync()) {
        return Image.file(f, width: w, height: h, fit: BoxFit.cover);
      }
    }
    if (pathOrUrl.isNotEmpty &&
        !pathOrUrl.startsWith('http') &&
        !pathOrUrl.startsWith('/')) {
      try {
        final bytes = base64Decode(pathOrUrl);
        return Image.memory(bytes, width: w, height: h, fit: BoxFit.cover);
      } catch (_) {}
    }
    return _placeholder(w, h);
  }

  Widget _placeholder(double w, double h, {bool broken = false}) {
    return Container(
      width: w,
      height: h,
      color: Colors.grey[300],
      child: Icon(broken ? Icons.broken_image : Icons.photo, size: w * 0.6),
    );
  }

  // ---- Totales ----
  double get _total {
    return _seleccionados.fold<double>(0.0, (acc, p) {
      final pv = p['precioVenta'];
      final v = (pv is num) ? pv.toDouble() : double.tryParse('$pv') ?? 0.0;
      return acc + v;
    });
  }

  double get _descuento {
    final d =
        double.tryParse(
          _descuentoCtrl.text.trim().replaceAll('.', '').replaceAll(',', '.'),
        ) ??
        0.0;
    if (d < 0) return 0.0;
    if (d > _total) return _total;
    return d;
  }

  double get _totalNeto => (_total - _descuento).clamp(0.0, double.infinity);

  double get _abono {
    final d =
        double.tryParse(_abonoCtrl.text.trim().replaceAll(',', '.')) ?? 0.0;
    final a = d < 0 ? 0.0 : d;
    return a > _totalNeto ? _totalNeto : a;
  }

  double get _falta => (_totalNeto - _abono).clamp(0.0, double.infinity);

  // ---- Búsqueda productos ----
  void _onBuscarChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _buscarProductos(_buscarCtrl.text.trim());
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

      // ⬇️ OCULTA vendidos y apartados
      r = r.where((e) {
        final estado = (e['estado'] ?? 'disponible')
            .toString()
            .toLowerCase()
            .trim();
        return estado != 'vendido' && estado != 'apartado';
      }).toList();

      // Quita los ya seleccionados
      final selIds = _seleccionados.map((e) => '${e['_id']}').toSet();
      r = r.where((e) => !selIds.contains('${e['_id']}')).toList();

      setState(() => _resultados = r);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al buscar: $e')));
      }
    }
  }

  void _addProducto(Map<String, dynamic> p) {
    final estado = (p['estado'] ?? 'disponible').toString().toLowerCase();
    if (estado == 'vendido' || estado == 'apartado') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No puedes agregar esta prenda: no está disponible.'),
        ),
      );
      return;
    }
    setState(() {
      _seleccionados.add(p);
      _resultados.removeWhere((e) => '${e['_id']}' == '${p['_id']}');
      _buscarCtrl.clear();
      _resultados.clear();
      _mostrarBusqueda = false; // oculta búsqueda
    });

    _closeKeyboard();
    FocusScope.of(context).unfocus();
  }

  void _removeProducto(Map<String, dynamic> p) {
    setState(() {
      _seleccionados.remove(p);
    });
  }

  // ---- Helpers de ids ----
  String _hexFromAnyId(dynamic raw) {
    if (raw == null) return '';
    if (raw is ObjectId) return raw.toHexString();
    if (raw is Map && raw[r'$oid'] is String) return raw[r'$oid'] as String;
    final s = raw.toString();
    final m = RegExp(r'ObjectId\("([0-9a-fA-F]{24})"\)').firstMatch(s);
    return m != null ? m.group(1)! : s;
  }

  // ---- Venta a partir de las prendas del apartado (snapshot para comprobante) ----
  List<Map<String, dynamic>> _ventaLineasDesdePrendas(
    List<Map<String, dynamic>> prendas,
  ) {
    return prendas.map((p) {
      final double pv = (p['precioVenta'] is num)
          ? (p['precioVenta'] as num).toDouble()
          : double.tryParse('${p['precioVenta']}') ?? 0.0;
      final double neto = (p['precioVentaNeto'] is num)
          ? (p['precioVentaNeto'] as num).toDouble()
          : pv;
      final double costo = (p['precioCompra'] is num)
          ? (p['precioCompra'] as num).toDouble()
          : double.tryParse('${p['precioCompra']}') ?? 0.0;

      final ganEsp = neto - costo;

      return {
        'productoId': p['productoId'],
        'nombre': p['nombre'],
        'precioVendido': pv, // lista
        'precioVendidoNeto': neto, // con descuento aplicado a la línea
        'descuentoLinea': (p['descuentoLinea'] ?? 0.0),
        'precioCompra': costo,
        'gananciaEsperadaLinea': ganEsp,
        'fotoBase64': p['fotoBase64'] ?? '',
        'foto': p['foto'] ?? '',
        'talla': p['talla'],
        'color': p['color'],
        'sku': p['sku'],
      };
    }).toList();
  }

  /// Guarda la venta del ABONO inicial del apartado:
  /// - tipoVenta: 'abono_apartado'
  /// - impactaGanancia: false
  /// - productos: []  (para no computar ganancia en el Resumen)
  Future<void> _registrarVentaDeApartado({
    required List<Map<String, dynamic>> prendasVentaSnapshot,
    required double subtotalNeto,
    required double descuentoTotal,
    required double gananciaEsperadaTotal,
    String? apartadoIdHex,
  }) async {
    final venta = {
      'cliente': {
        'nombre': _nombreCtrl.text.trim(),
        'telefono': _telefonoCtrl.text.trim(),
      },

      // 👇 SIN líneas: el abono no debe generar ganancia
      'productos': [],

      // flujo de dinero
      'total': _abono, // solo el abono inicial
      'saldoPendiente': _falta,
      'tipoVenta': 'abono_apartado',
      'impactaGanancia': false,
      'apartadoRef': apartadoIdHex,

      // (Opcional) snapshot informativo
      'productosSnapshot': prendasVentaSnapshot,
      'subtotal': subtotalNeto,
      'descuento': descuentoTotal,
      'gananciaEsperadaTotal': gananciaEsperadaTotal,

      'origen': {
        'tipo': 'apartado',
        'apartadoId': apartadoIdHex,
        'evento': 'creacion', // primera vez
        'montoAbono': _abono,
      },
      'fechaVenta': DateTime.now().toIso8601String(),
    };

    await MongoService().saveVenta(venta);

    // ❌ Ya no mostramos el comprobante con bottom sheet aquí para evitar abrir UI con inputs.
  }

  Future<void> _guardarApartado() async {
    if (_guardando) return;
    // cierra teclado y evita re-abrir
    _closeKeyboard();
    try {
      await SystemChannels.textInput.invokeMethod('TextInput.hide');
    } catch (_) {}

    if (!_formKey.currentState!.validate()) return;
    if (_seleccionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos una prenda')),
      );
      return;
    }
    if (_abono <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ingresa un abono inicial')));
      return;
    }

    setState(() => _guardando = true);
    try {
      // 1) Construir prendas del apartado (con prorrateo de descuento y ganancia esperada)
      final double subtotal = _total;
      final double descuentoTotal = _descuento;
      final double totalNeto = _totalNeto;

      double gananciaEsperadaTotal = 0.0;

      final prendas = _seleccionados.map((p) {
        final pv = (p['precioVenta'] is num)
            ? (p['precioVenta'] as num).toDouble()
            : double.tryParse('${p['precioVenta']}') ?? 0.0;

        // prorrateo del descuento
        final propor = subtotal <= 0 ? 0.0 : (pv / subtotal);
        final descLinea = descuentoTotal * propor;
        final neto = (pv - descLinea);

        // costo (si el producto lo trae)
        double costo = 0.0;
        final pcRaw = p['precioCompra'];
        if (pcRaw != null) {
          costo = (pcRaw is num)
              ? pcRaw.toDouble()
              : double.tryParse('$pcRaw') ?? 0.0;
        }

        final ganEsp = neto - costo;
        gananciaEsperadaTotal += ganEsp;

        String? fotoBase64 = (p['fotoBase64'] ?? '') as String?;
        if (fotoBase64 == null || fotoBase64.isEmpty) {
          final f = (p['foto'] ?? '') as String? ?? '';
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
          'precioVenta': pv, // lista
          'precioVentaNeto': neto, // con descuento
          'descuentoLinea': descLinea,
          'precioCompra': costo,
          'gananciaEsperadaLinea': ganEsp,
          'fotoBase64': fotoBase64 ?? '',
          'foto': p['foto'] ?? '',
          'talla': p['talla'],
          'color': p['color'],
          'sku': p['sku'],
        };
      }).toList();

      // 2) Crear _id del apartado y armar documento (incluye historial de abonos)
      final ObjectId apartadoOid = ObjectId();
      final nowIso = DateTime.now().toIso8601String();
      final String ident = _identificadorDesdeNombre(_nombreCtrl.text);

      final doc = {
        '_id': apartadoOid,
        'identificador': ident, // ⬅️ guardamos AP-{NOMBRE}
        'cliente': {
          'nombre': _nombreCtrl.text.trim(),
          'telefono': _telefonoCtrl.text.trim(),
        },
        'prendas': prendas,
        // Totales del compromiso
        'valorSubtotal': subtotal,
        'valorDescuento': descuentoTotal,
        'valorTotal': totalNeto,
        'gananciaEsperadaTotal': gananciaEsperadaTotal,

        // Estado de pagos
        'valorAbono': _abono, // acumulado de abonos
        'valorFalta': _falta, // totalNeto - valorAbono
        'abonos': [
          {'fecha': nowIso, 'monto': _abono},
        ],

        'fechaApartado': nowIso,
        'estado': 'activo',
      };

      // 3) Guardar apartado
      await MongoService().saveApartado(doc);

      // 4) Marcar productos como APARTADOS
      final idsApartar = _seleccionados
          .map<String>((p) => _hexFromAnyId(p['_id']))
          .where((s) => s.isNotEmpty)
          .toList();

      try {
        if (idsApartar.isNotEmpty) {
          await MongoService().marcarProductosApartados(idsApartar);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Apartado guardado, pero no se pudo cambiar el estado: $e',
              ),
            ),
          );
        }
        _closeKeyboard();
      }

      // 5) CREAR VENTA del ABONO del APARTADO (impactaGanancia=false)
      final lineasSnapshot = _ventaLineasDesdePrendas(prendas);
      await _registrarVentaDeApartado(
        prendasVentaSnapshot: lineasSnapshot,
        subtotalNeto: totalNeto,
        descuentoTotal: descuentoTotal,
        gananciaEsperadaTotal: gananciaEsperadaTotal,
        apartadoIdHex: apartadoOid.toHexString(),
      );

      // 6) Mostrar el identificador y nombre EN GRANDE en el centro
      await _mostrarIdentificadorCentral(
        identificador: ident,
        nombre: _nombreCtrl.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Apartado registrado y abono creado')),
        );
      }

      _limpiar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }

  void _limpiar() {
    setState(() {
      _formKey.currentState?.reset();
      _nombreCtrl.clear();
      _telefonoCtrl.clear();
      _buscarCtrl.clear();
      _abonoCtrl.clear();
      _descuentoCtrl.clear();
      _resultados.clear();
      _seleccionados.clear();
      _mostrarBusqueda = false; // ⬅️ no abrir ningún campo luego de guardar
    });
    _closeKeyboard();
    try {
      SystemChannels.textInput.invokeMethod('TextInput.hide');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    const Color brandColor = Color(0xFFFF7A18);
    const Color brandAccent = Color(0xFFFFC837);

    // ---------- UI helpers ----------
    Widget _tituloCard(IconData icono, String texto) => Row(
      children: [
        Icon(icono, size: 20, color: Colors.grey[800]),
        const SizedBox(width: 8),
        Text(texto, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );

    Widget _clienteCard() => Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _tituloCard(Icons.person_outline, 'Datos del cliente'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nombreCtrl,
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
              decoration: InputDecoration(
                labelText: 'Nombre',
                prefixIcon: const Icon(Icons.badge_outlined),
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Ingrese el nombre' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _telefonoCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _closeKeyboard(),
              decoration: InputDecoration(
                labelText: 'Teléfono (10 dígitos)',
                prefixIcon: const Icon(Icons.phone_outlined),
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              validator: (v) {
                final s = (v ?? '').trim();
                if (s.isEmpty) return 'Ingrese el teléfono';
                if (!RegExp(r'^\d{10}$').hasMatch(s)) {
                  return 'Debe tener exactamente 10 dígitos';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );

    Widget _busquedaCard() => Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _tituloCard(Icons.search, 'Buscar prenda (solo disponibles)'),
            const SizedBox(height: 8),
            TextField(
              controller: _buscarCtrl,
              focusNode: _buscarFocus,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _closeKeyboard(),
              decoration: InputDecoration(
                labelText: 'Nombre…',
                hintText: 'Ej: Jean azul',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (_resultados.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 230),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _resultados.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final p = _resultados[index];
                      final numRaw = (p['precioVenta'] is num)
                          ? p['precioVenta'] as num
                          : num.tryParse('${p['precioVenta']}') ?? 0;
                      final precio = numRaw.toDouble();

                      return ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: _buildImageFromDoc(p, w: 44, h: 44),
                        ),
                        title: Text(
                          p['nombre'] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(_mon.format(precio)),
                        trailing: IconButton.filledTonal(
                          icon: const Icon(Icons.add),
                          tooltip: 'Agregar a este apartado',
                          onPressed: () => _addProducto(p),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    Widget _seleccionadosCard() {
      const double imgWidth = 150; // ancho grande de la foto
      const double imgAspect = 2 / 2; // relación ancho:alto

      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: Colors.grey[50],
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              _tituloCard(Icons.shopping_bag_outlined, 'Prendas seleccionadas'),
              const SizedBox(height: 8),
              if (_seleccionados.isEmpty)
                const Text(
                  'Sin prendas aún',
                  style: TextStyle(color: Colors.black54),
                ),
              if (_seleccionados.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 480),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _seleccionados.length,
                    separatorBuilder: (_, __) => const Divider(height: 12),
                    itemBuilder: (context, i) {
                      final p = _seleccionados[i];
                      final numRaw = (p['precioVenta'] is num)
                          ? p['precioVenta'] as num
                          : num.tryParse('${p['precioVenta']}') ?? 0;
                      final precio = numRaw.toDouble();

                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // FOTO GRANDE
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                SizedBox(
                                  width: imgWidth,
                                  child: AspectRatio(
                                    aspectRatio: imgAspect,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: _buildImageFromDoc(
                                        p,
                                        w: imgWidth,
                                        h: imgWidth / imgAspect,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: -8,
                                  top: -8,
                                  child: IconButton(
                                    icon: const Icon(Icons.close, size: 20),
                                    color: Colors.redAccent,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => _removeProducto(p),
                                    tooltip: 'Eliminar',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 12),

                            // Detalles
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p['nombre'] ?? '',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _mon.format(precio),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      FilledButton.tonalIcon(
                                        onPressed: _abrirBusquedaParaAgregar,
                                        icon: const Icon(
                                          Icons.add_circle_outline,
                                        ),
                                        label: const Text('Agregar otra'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      );
    }

    Widget chipsAbonoRapido() {
      final valores = [10000, 20000];
      return Wrap(
        spacing: 8,
        runSpacing: 4,
        children: valores
            .map(
              (v) => ActionChip(
                label: Text(_mon.format(v)),
                onPressed: () {
                  _abonoCtrl.text = v.toString();
                  setState(() {});
                  _closeKeyboard();
                },
              ),
            )
            .toList(),
      );
    }

    // === RESUMEN ===
    Widget _resumenCard() => Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.green[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _tituloCard(Icons.receipt_long_outlined, 'Resumen'),
            const SizedBox(height: 8),
            _row('Subtotal', _mon.format(_total)),
            const SizedBox(height: 8),
            TextField(
              controller: _descuentoCtrl,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Descuento (monto)',
                hintText: '0',
                prefixIcon: const Icon(Icons.percent),
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            _row(
              'Total con descuento',
              _mon.format(_totalNeto),
              isStrong: true,
            ),
            const Divider(height: 18),

            // Abono
            TextField(
              controller: _abonoCtrl,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _closeKeyboard(),
              decoration: InputDecoration(
                labelText: 'Abono',
                hintText: '0',
                prefixIcon: const Icon(Icons.payments_outlined),
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 6),
            chipsAbonoRapido(),
            const SizedBox(height: 10),
            _row('Falta', _mon.format(_falta), isStrong: true),
          ],
        ),
      ),
    );

    Widget _acciones() => Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _guardando ? null : _limpiar,
            icon: const Icon(Icons.cleaning_services_outlined),
            label: const Text('Limpiar'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _guardando
                ? null
                : () async {
                    _closeKeyboard();
                    try {
                      await SystemChannels.textInput.invokeMethod(
                        'TextInput.hide',
                      );
                    } catch (_) {}
                    await _guardarApartado();
                  },
            icon: _guardando
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('Agregar'),
          ),
        ),
      ],
    );

    // ---------- Scaffold ----------
    return GestureDetector(
      onTap: _closeKeyboard, // cierra teclado al tocar fuera
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.bookmark_add_outlined, size: 22),
              SizedBox(width: 8),
              Text(
                'Crear apartado',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          foregroundColor: Colors.white,
          elevation: 0,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [brandColor, brandAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, c) {
              final bool wide = c.maxWidth >= 900;
              final content = [
                Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _clienteCard(),
                      const SizedBox(height: 8),
                      if (_mostrarBusqueda) _busquedaCard(),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _seleccionadosCard(),
                    const SizedBox(height: 8),
                    _resumenCard(),
                    const SizedBox(height: 10),
                    _acciones(),
                  ],
                ),
              ];

              if (wide) {
                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: content[0]),
                      const SizedBox(width: 12),
                      Expanded(child: content[1]),
                    ],
                  ),
                );
              } else {
                return ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    content[0],
                    const SizedBox(height: 12),
                    content[1],
                  ],
                );
              }
            },
          ),
        ),
      ),
    );
  }

  // reabrir el cuadro de búsqueda para agregar otra prenda
  void _abrirBusquedaParaAgregar() {
    setState(() {
      _mostrarBusqueda = true;
      _buscarCtrl.clear();
      _resultados.clear();
    });
    // enfoca el campo de búsqueda
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) FocusScope.of(context).requestFocus(_buscarFocus);
    });
  }

  Widget _row(String l, String v, {bool isStrong = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          l,
          style: TextStyle(
            fontWeight: isStrong ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          v,
          style: TextStyle(
            fontWeight: isStrong ? FontWeight.bold : FontWeight.normal,
            color: isStrong ? Colors.green[800] : null,
          ),
        ),
      ],
    );
  }
}
