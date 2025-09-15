import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:gestion_inventario/services/mongo_service.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;

class HistorialApartadosPage extends StatefulWidget {
  const HistorialApartadosPage({super.key});

  @override
  State<HistorialApartadosPage> createState() => _HistorialApartadosPageState();
}

class _HistorialApartadosPageState extends State<HistorialApartadosPage> {
  final Set<String> _loadingIds = {}; // ids en proceso
  final _fmtFecha = DateFormat('dd/MM/yyyy HH:mm');
  final _fmtMon = NumberFormat.currency(
    locale: 'es_CO',
    symbol: r'$',
    decimalDigits: 0,
  );
  Future<List<Map<String, dynamic>>>? _future;

  // Controlador del filtro por nombre
  final _filtroCtrl = TextEditingController();
  late VoidCallback _filtroListener;

  @override
  void initState() {
    super.initState();
    _future = _cargar();
    _filtroListener = () => setState(() {});
    _filtroCtrl.addListener(_filtroListener);
  }

  @override
  void dispose() {
    _filtroCtrl.removeListener(_filtroListener);
    _filtroCtrl.dispose();
    super.dispose();
  }

  String _oidHex(dynamic raw) {
    if (raw == null) return '';
    if (raw is ObjectId) return raw.toHexString();
    if (raw is Map && raw[r'$oid'] is String) return (raw[r'$oid'] as String);
    final s = raw.toString();
    final m = RegExp(r'[0-9a-fA-F]{24}').firstMatch(s);
    return m?.group(0) ?? '';
  }

  bool _esApartadoPagado(Map<String, dynamic> a) {
    final estado = '${a['estado'] ?? ''}'.toLowerCase().trim();
    if (estado == 'pagado' || estado == 'vendido') return true;

    final total = (a['valorTotal'] ?? 0) as num;
    final abono = (a['valorAbono'] ?? 0) as num;
    final falta = (a['valorFalta'] ?? (total - abono)) as num;
    return falta <= 0;
  }

  // Actualiza en BD
  Future<void> _actualizarApartado(
    String idHex, {
    double? valorAbono,
    double? valorFalta,
    String? estado,
  }) async {
    await MongoService().actualizarApartado(
      idHex,
      valorAbono: valorAbono,
      valorFalta: valorFalta,
      estado: estado,
    );
    await _refresh();
  }

  // -------- Helpers de productos/ventas a partir del apartado --------

  List<Map<String, dynamic>> _productosDesdeApartado(Map<String, dynamic> a) {
    final List prendas = (a['prendas'] ?? []) as List;
    return prendas.map<Map<String, dynamic>>((raw) {
      final p = (raw as Map).cast<String, dynamic>();
      final precio = (p['precioVenta'] is num)
          ? (p['precioVenta'] as num).toDouble()
          : double.tryParse('${p['precioVenta']}') ?? 0.0;

      return {
        'productoId': _oidHex(p['productoId'] ?? p['_id']),
        'nombre': p['nombre'] ?? '',
        'precioVendido': precio,
        'fotoBase64': (p['fotoBase64'] ?? '') as String,
        'foto': (p['foto'] ?? '') as String,
        'sku': p['sku'],
        'talla': p['talla'],
        'color': p['color'],
      };
    }).toList();
  }

  // Líneas para VENTA DE CIERRE: usa precioVentaNeto si existe; incluye costo si está guardado
  List<Map<String, dynamic>> _lineasCierreDesdeApartado(Map<String, dynamic> a) {
    final List prendas = (a['prendas'] ?? []) as List;
    return prendas.map<Map<String, dynamic>>((raw) {
      final p = (raw as Map).cast<String, dynamic>();
      final pv = (p['precioVenta'] is num)
          ? (p['precioVenta'] as num).toDouble()
          : double.tryParse('${p['precioVenta']}') ?? 0.0;
      final neto = (p['precioVentaNeto'] is num)
          ? (p['precioVentaNeto'] as num).toDouble()
          : pv;
      final costo = (p['precioCompra'] is num)
          ? (p['precioCompra'] as num).toDouble()
          : double.tryParse('${p['precioCompra']}') ?? 0.0;

      return {
        'productoId': _oidHex(p['productoId'] ?? p['_id']),
        'nombre': p['nombre'] ?? '',
        // ⚠️ El Resumen calcula ganancia a partir de 'precioVendido' y 'precioCompra'
        'precioVendido': neto,    // neto para reflejar descuento real
        'precioCompra': costo,
        'descuentoLinea': (p['descuentoLinea'] is num)
            ? (p['descuentoLinea'] as num).toDouble()
            : double.tryParse('${p['descuentoLinea']}') ?? 0.0,
        'fotoBase64': (p['fotoBase64'] ?? '') as String,
        'foto': (p['foto'] ?? '') as String,
        'sku': p['sku'],
        'talla': p['talla'],
        'color': p['color'],
      };
    }).toList();
  }

  Future<void> _marcarVendidosDesdeApartado(Map<String, dynamic> a) async {
    final productos = _productosDesdeApartado(a);
    final idsVendidos = productos
        .map((l) => '${l['productoId']}')
        .map(_oidHex)
        .where((s) => s.isNotEmpty)
        .toList();
    if (idsVendidos.isNotEmpty) {
      await MongoService().marcarProductosVendidos(idsVendidos);
    }
  }

  // ===== Ventas que se generan según acción =====

  // 1) Venta por ABONO (parcial o inicial): sin líneas, sin ganancia
  Future<void> _crearVentaAbonoDesdeApartado(
    Map<String, dynamic> a,
    double montoAbono,
    String evento, // 'creacion' | 'abono'
  ) async {
    final apartId = _oidHex(a['_id']);
    final cliente = (a['cliente'] ?? {}) as Map;

    // Snapshot informativo de líneas (no impacta ganancia)
    final snapshot = _productosDesdeApartado(a);

    final venta = {
      'cliente': {
        'nombre': '${cliente['nombre'] ?? ''}',
        'telefono': '${cliente['telefono'] ?? ''}',
      },

      // 👇 SIN líneas de productos: así el Resumen NO calcula ganancia
      'productos': [],
      'productosSnapshot': snapshot,

      // Flujo de caja del abono
      'total': montoAbono,
      'fechaVenta': DateTime.now().toIso8601String(),

      'tipoVenta': 'abono_apartado',
      'impactaGanancia': false, // explícito

      'origen': {
        'tipo': 'apartado',
        'apartadoId': apartId,
        'evento': evento, // 'creacion' o 'abono'
        'montoAbono': montoAbono,
      },
      'rotulo': 'Abono de apartado',
    };

    await MongoService().saveVenta(venta);
  }

  // 2) Venta de CIERRE: total = faltante y rótulo "Apartado pagado", SÍ ganancia
  Future<void> _crearVentaCierreDesdeApartado(
    Map<String, dynamic> a, {
    required double montoFaltante,
  }) async {
    final apartId = _oidHex(a['_id']);
    final cliente = (a['cliente'] ?? {}) as Map;
    final lineas = _lineasCierreDesdeApartado(a);

    // Suma de netos de líneas (referencia para ganancia)
    final double subtotalNeto = lineas.fold<double>(
      0.0,
      (acc, l) => acc + ((l['precioVendido'] as num?)?.toDouble() ?? 0.0),
    );

    final venta = {
      'cliente': {
        'nombre': '${cliente['nombre'] ?? ''}',
        'telefono': '${cliente['telefono'] ?? ''}',
      },
      'productos': lineas,        // 👈 líneas con neto y costo (para ganancia)
      'subtotal': subtotalNeto,   // referencia neta
      'descuento': 0.0,
      'total': montoFaltante,     // 👈 SOLO lo que faltaba por cobrar
      'fechaVenta': DateTime.now().toIso8601String(),
      'tipoVenta': 'apartado_pagado', // 👈 etiqueta de cierre
      'impactaGanancia': true,

      'origen': {
        'tipo': 'apartado',
        'apartadoId': apartId,
        'evento': 'cierre',
        'montoFaltante': montoFaltante,
      },
      'rotulo': 'Apartado pagado',
    };

    await MongoService().saveVenta(venta);
  }

  ScaffoldMessengerState? _messenger;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messenger = ScaffoldMessenger.maybeOf(context);
  }

  void _snack(String msg) {
    if (!mounted) return;
    _messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  // -------------------------------------------------------------------

  Future<void> _mostrarSheetAbono(Map<String, dynamic> a) async {
    final total = (a['valorTotal'] ?? 0) as num;
    final abono = (a['valorAbono'] ?? 0) as num;
    final falta = (a['valorFalta'] ?? (total - abono)) as num;

    final idHex = _oidHex(a['_id']);
    if (idHex.isEmpty) {
      _snack('No se pudo identificar el apartado.');
      return;
    }
    final ctrl = TextEditingController();
    final fmt = _fmtMon;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 16,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.payments_outlined),
                  SizedBox(width: 8),
                  Text(
                    'Registrar abono',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Falta actual', style: TextStyle(color: Colors.grey[700])),
                  Text(fmt.format(falta), style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                decoration: const InputDecoration(
                  labelText: 'Monto del abono',
                  prefixIcon: Icon(Icons.attach_money),
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                onSubmitted: (_) => FocusScope.of(ctx).unfocus(),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [10000, 20000].map((m) {
                  return ActionChip(
                    label: Text(fmt.format(m)),
                    onPressed: () => ctrl.text = m.toString(),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Aplicar abono'),
                  onPressed: () async {
                    final raw = ctrl.text.trim().replaceAll('.', '').replaceAll(',', '.');
                    double monto = double.tryParse(raw) ?? 0;
                    if (monto <= 0) {
                      _snack('Ingresa un monto válido');
                      return;
                    }
                    if (monto > falta) monto = falta.toDouble();

                    final nuevoAbono = (abono.toDouble() + monto);
                    final nuevoFalta = (total.toDouble() - nuevoAbono).clamp(0.0, double.infinity);
                    final nuevoEstado = (nuevoFalta <= 0) ? 'vendido' : null;

                    Navigator.pop(ctx);
                    setState(() => _loadingIds.add(idHex));
                    try {
                      // 1) Actualizar apartado
                      await _actualizarApartado(
                        idHex,
                        valorAbono: nuevoAbono,
                        valorFalta: nuevoFalta,
                        estado: nuevoEstado,
                      );

                      // 2) Crear venta del ABONO (no impacta ganancia)
                      await _crearVentaAbonoDesdeApartado(a, monto, 'abono');

                      // 3) Si quedó pagado, registrar VENTA DE CIERRE (total 0) y marcar vendidos
                      if ((nuevoEstado ?? '').toLowerCase() == 'vendido' || nuevoFalta <= 0) {
                        try {
                          // Ya se cobró el abono por "monto"; el cierre solo reconoce ganancia
                          await _crearVentaCierreDesdeApartado(
                            a,
                            montoFaltante: 0.0,
                          );
                          await _marcarVendidosDesdeApartado(a);
                        } catch (e) {
                          if (mounted) _snack('Pagado, pero error en cierre: $e');
                        }
                      }

                      // 4) Feedback
                      await showDialog<void>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Abono registrado'),
                          content: Text(
                            'Se registró una venta (abono) por ${fmt.format(monto)}.\nFalta: ${fmt.format(nuevoFalta)}',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text('Aceptar'),
                            ),
                          ],
                        ),
                      );
                    } finally {
                      if (mounted) setState(() => _loadingIds.remove(idHex));
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _cargar() async {
    final datos = await MongoService().getApartados();

    // ⬇️ QUITAR los pagados/vendidos del historial
    final activos = datos.where((a) => !_esApartadoPagado(a)).toList();

    // Ordena por fechaApartado desc
    activos.sort((a, b) {
      final sa = (a['fechaApartado'] ?? '') as String;
      final sb = (b['fechaApartado'] ?? '') as String;
      DateTime da, db;
      try {
        da = DateTime.parse(sa);
      } catch (_) {
        da = DateTime.fromMillisecondsSinceEpoch(0);
      }
      try {
        db = DateTime.parse(sb);
      } catch (_) {
        db = DateTime.fromMillisecondsSinceEpoch(0);
      }
      return db.compareTo(da);
    });
    return activos;
  }

  Future<void> _refresh() async {
    final nuevo = await _cargar();
    if (!mounted) return;
    setState(() {
      _future = Future.value(nuevo);
    });
  }

  // ---- Imagen: fotoBase64 -> URL -> ruta local -> (foto en base64) -> placeholder ----
  Widget _buildItemImage(
    Map<String, dynamic> item, {
    double w = 44,
    double h = 44,
  }) {
    final String b64 = (item['fotoBase64'] ?? '') as String;
    final String f = (item['foto'] ?? '') as String;

    if (b64.isNotEmpty) {
      try {
        final bytes = base64Decode(b64);
        return Image.memory(bytes, width: w, height: h, fit: BoxFit.cover);
      } catch (_) {}
    }
    if (f.startsWith('http://') || f.startsWith('https://')) {
      return Image.network(
        f,
        width: w,
        height: h,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(w, h, broken: true),
      );
    }
    if (f.isNotEmpty && f.startsWith('/')) {
      final file = File(f);
      if (file.existsSync()) {
        return Image.file(file, width: w, height: h, fit: BoxFit.cover);
      }
    }
    if (f.isNotEmpty && !f.startsWith('http') && !f.startsWith('/')) {
      try {
        final bytes = base64Decode(f);
        return Image.memory(bytes, width: w, height: h, fit: BoxFit.cover);
      } catch (_) {}
    }
    return _placeholder(w, h);
  }

  Widget _placeholder(double w, double h, {bool broken = false}) {
    return Container(
      width: w,
      height: h,
      color: const Color.fromARGB(255, 0, 0, 0),
      child: Icon(broken ? Icons.broken_image : Icons.photo, size: w * 0.6),
    );
  }

  void _verFotoGrande(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (_) {
        final String b64 = (item['fotoBase64'] ?? '') as String;
        final String f = (item['foto'] ?? '') as String;
        Widget img;

        if (b64.isNotEmpty) {
          try {
            final bytes = base64Decode(b64);
            img = Image.memory(bytes, fit: BoxFit.contain);
          } catch (_) {
            img = _placeholder(280, 280);
          }
        } else if (f.startsWith('http')) {
          img = Image.network(f, fit: BoxFit.contain);
        } else if (f.isNotEmpty && f.startsWith('/')) {
          final file = File(f);
          img = file.existsSync()
              ? Image.file(file, fit: BoxFit.contain)
              : _placeholder(280, 280);
        } else if (f.isNotEmpty) {
          try {
            final bytes = base64Decode(f);
            img = Image.memory(bytes, fit: BoxFit.contain);
          } catch (_) {
            img = _placeholder(280, 280);
          }
        } else {
          img = _placeholder(280, 280);
        }

        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            color: Colors.black,
            padding: const EdgeInsets.all(8),
            child: Stack(
              children: [
                Center(child: InteractiveViewer(child: img)),
                Positioned(
                  right: 8,
                  top: 8,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---- UI ----
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.bookmark_added_outlined, size: 28), // icono un poco más grande
            SizedBox(width: 8),
            Text(
              'Historial de Apartados',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        scrolledUnderElevation: 0,
      ),
      body: Column(
        children: [
          // Filtro
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              color: cs.surface,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: TextField(
                  controller: _filtroCtrl,
                  decoration: InputDecoration(
                    labelText: 'Filtrar por nombre',
                    hintText: 'Ej: Lina, Carlos…',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: (_filtroCtrl.text.isNotEmpty)
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _filtroCtrl.clear();
                              FocusScope.of(context).unfocus();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: cs.surface,
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Lista con pull-to-refresh
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return ListView(
                      children: const [
                        SizedBox(height: 200),
                        Center(child: CircularProgressIndicator()),
                        SizedBox(height: 200),
                      ],
                    );
                  }
                  if (snap.hasError) {
                    return ListView(
                      children: [
                        const SizedBox(height: 80),
                        Center(child: Text('Error: ${snap.error}')),
                      ],
                    );
                  }

                  final apartadosRaw = snap.data ?? [];
                  final apartados = apartadosRaw
                      .where((a) => !_esApartadoPagado(a))
                      .toList();
                  final q = _filtroCtrl.text.trim().toLowerCase();
                  final lista = q.isEmpty
                      ? apartados
                      : apartados.where((a) {
                          final cliente = (a['cliente'] ?? {}) as Map;
                          final nombre = '${cliente['nombre'] ?? ''}'
                              .toLowerCase();
                          return nombre.contains(q);
                        }).toList();

                  if (lista.isEmpty) {
                    return ListView(
                      children: const [
                        SizedBox(height: 80),
                        Center(child: Text('No hay apartados que coincidan')),
                      ],
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    itemCount: lista.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final a = lista[index];
                      final cliente = (a['cliente'] ?? {}) as Map;
                      final nombre = '${cliente['nombre'] ?? 'Sin nombre'}';

                      final total = (a['valorTotal'] ?? 0) as num;
                      final abono = (a['valorAbono'] ?? 0) as num;
                      final falta = (a['valorFalta'] ?? (total - abono)) as num;

                      DateTime fecha;
                      try {
                        fecha = DateTime.parse('${a['fechaApartado'] ?? ''}');
                      } catch (_) {
                        fecha = DateTime.fromMillisecondsSinceEpoch(0);
                      }

                      final List prendas = (a['prendas'] ?? []) as List;
                      final estado = '${a['estado'] ?? 'activo'}'.toLowerCase();
                      final isPagado = (estado == 'pagado') || (falta <= 0);

                      // preview
                      Widget? preview;
                      if (prendas.isNotEmpty) {
                        final first = (prendas.first as Map)
                            .cast<String, dynamic>();
                        preview = ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: _buildItemImage(first, w: 50, h: 50),
                        );
                      }

                      final idHex = _oidHex(a['_id']);
                      final isLoading = _loadingIds.contains(idHex);

                      final Map<String, dynamic>? primeraPrenda =
                          prendas.isNotEmpty
                              ? (prendas.first as Map).cast<String, dynamic>()
                              : null;

                      final String tel = '${cliente['telefono'] ?? ''}';

                      return Card(
                        elevation: 0.8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Theme(
                          data: Theme.of(
                            context,
                          ).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            tilePadding: const EdgeInsets.fromLTRB(
                              12,
                              8,
                              12,
                              8,
                            ),
                            childrenPadding: const EdgeInsets.fromLTRB(
                              12,
                              0,
                              12,
                              12,
                            ),

                            // ======= CARD CERRADA =======
                            leading:
                                preview ?? const Icon(Icons.inventory_2_outlined),
                            title: Text(
                              nombre.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Wrap(
                                spacing: 20,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Chip(
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    label: Text(
                                      'Debe: ${_fmtMon.format(isPagado ? 0 : falta)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            trailing: _estadoChip(estado, isPagado: isPagado),

                            // ======= CARD ABIERTA =======
                            children: [
                              const SizedBox(height: 6),

                              // FOTO grande
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: SizedBox(
                                  width: double.infinity,
                                  height: 260,
                                  child: (primeraPrenda != null)
                                      ? InkWell(
                                          onTap: () =>
                                              _verFotoGrande(primeraPrenda),
                                          child: _buildItemImage(
                                            primeraPrenda,
                                            w: MediaQuery.of(
                                              context,
                                            ).size.width,
                                            h: 260,
                                          ),
                                        )
                                      : Container(
                                          color: Colors.grey[200],
                                          child: const Icon(
                                            Icons.photo,
                                            size: 72,
                                            color: Colors.black26,
                                          ),
                                        ),
                                ),
                              ),

                              const SizedBox(height: 12),

                              // ABONADO y DEBE + FECHA
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  _moneyChip(
                                    'Abonado',
                                    _fmtMon.format(abono),
                                    Colors.blue,
                                    Colors.white,
                                    icon: Icons.savings,
                                  ),
                                  _moneyChip(
                                    'Debe',
                                    _fmtMon.format(isPagado ? 0 : falta),
                                    isPagado ? Colors.green : Colors.red,
                                    Colors.white,
                                  ),
                                  Chip(
                                    avatar: const Icon(Icons.event, size: 18),
                                    label: Text(
                                      'Fecha: ${_fmtFecha.format(fecha)}',
                                    ),
                                  ),
                                ],
                              ),

                              // --- Acciones ---
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      icon: const Icon(Icons.attach_money),
                                      label: const Text('Abonar'),
                                      onPressed: (isPagado || isLoading)
                                          ? null
                                          : () => _mostrarSheetAbono(a),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: FilledButton.icon(
                                      icon: isLoading
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(Icons.verified_rounded),
                                      label: const Text('Marcar pagado'),
                                      onPressed: (isPagado || isLoading)
                                          ? null
                                          : () async {
                                              setState(
                                                () => _loadingIds.add(idHex),
                                              );

                                              // monto por cobrar ahora = falta actual
                                              final double montoFinal = falta
                                                  .toDouble();

                                              try {
                                                // 1) Actualizar: abono = total, falta = 0, estado = vendido
                                                await _actualizarApartado(
                                                  idHex,
                                                  valorAbono: total.toDouble(),
                                                  valorFalta: 0,
                                                  estado: 'vendido',
                                                );

                                                // 2) Registrar SOLO la VENTA DE CIERRE (tipo: apartado_pagado) por el FALTANTE
                                                await _crearVentaCierreDesdeApartado(
                                                  a,
                                                  montoFaltante: montoFinal,
                                                );

                                                // 3) Marcar productos como vendidos
                                                await _marcarVendidosDesdeApartado(a);

                                                if (!mounted) return;
                                                _snack(
                                                  'Apartado marcado como PAGADO. Venta "Apartado pagado" registrada por ${_fmtMon.format(montoFinal)}.',
                                                );
                                              } catch (e) {
                                                if (!mounted) return;
                                                _snack('Error al completar pago: $e');
                                              } finally {
                                                if (mounted) {
                                                  setState(
                                                    () => _loadingIds.remove(
                                                      idHex,
                                                    ),
                                                  );
                                                }
                                              }
                                            },
                                    ),
                                  ),
                                ],
                              ),

                              // Contacto
                              const SizedBox(height: 14),
                              const Divider(height: 1),
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Icon(Icons.phone_iphone, size: 18),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Contacto:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: SelectableText(
                                      (tel.isEmpty) ? '—' : tel,
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 6),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _estadoChip(String estado, {required bool isPagado}) {
    final e = estado.toLowerCase();
    Color bg;
    String label;
    IconData icon;

    if (isPagado || e == 'pagado') {
      bg = Colors.green;
      label = 'PAGADO';
      icon = Icons.verified_rounded;
    } else if (e == 'activo') {
      bg = Colors.orange;
      label = 'ACTIVO';
      icon = Icons.schedule_rounded;
    } else {
      bg = Colors.grey;
      label = e.toUpperCase();
      icon = Icons.info_rounded;
    }

    return Chip(
      avatar: Icon(icon, color: Colors.white, size: 18),
      label: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
      backgroundColor: bg,
      side: BorderSide.none,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _moneyChip(
    String label,
    String value,
    Color bg,
    Color fg, {
    IconData icon = Icons.payments,
  }) {
    return Chip(
      avatar: Icon(icon, color: fg, size: 18),
      label: Text(
        '$label: $value',
        style: TextStyle(color: fg, fontWeight: FontWeight.w800),
      ),
      backgroundColor: bg.withOpacity(0.60),
      side: BorderSide(color: bg.withOpacity(0.40)),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
