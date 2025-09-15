import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:gestion_inventario/services/mongo_service.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;

class CambiosVentaPage extends StatefulWidget {
  const CambiosVentaPage({super.key});

  @override
  State<CambiosVentaPage> createState() => _CambiosVentaPageState();
}

class _CambiosVentaPageState extends State<CambiosVentaPage> {
  final _fmt = NumberFormat.currency(locale: 'es_CO', symbol: r'$');
  final _fmtFecha = DateFormat('dd/MM/yyyy HH:mm');
  Timer? _pollTimer;
  static const Duration _pollEvery = Duration(seconds: 4); // ajusta si quieres

  // búsquedas
  final _buscarVentaCtrl = TextEditingController();
  final _buscarProductoCtrl = TextEditingController();
  Timer? _debounceVenta;
  Timer? _debounceProd;

  // datos
  Future<List<Map<String, dynamic>>>? _futureVentas;
  List<Map<String, dynamic>> _ventas = [];
  List<Map<String, dynamic>> _ventasFiltradas = [];
  List<Map<String, dynamic>> _reemplazos = [];

  Map<String, dynamic>? _ventaSel;
  Map<String, dynamic>?
  _renglonSel; // línea de producto de la venta seleccionada

  bool _procesando = false;

  @override
  void initState() {
    super.initState();
    _futureVentas = _cargarVentas();
    _buscarVentaCtrl.addListener(_onBuscarVentaChanged);
    _buscarProductoCtrl.addListener(_onBuscarProductoChanged);
    _startPolling();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollEvery, (_) async {
      // evita competir con un cambio en curso
      if (!mounted || _procesando) return;
      await _refreshVentas(keepSelection: true);
    });
  }

  @override
  void dispose() {
    _buscarVentaCtrl.removeListener(_onBuscarVentaChanged);
    _buscarProductoCtrl.removeListener(_onBuscarProductoChanged);
    _debounceVenta?.cancel();
    _debounceProd?.cancel();
    _pollTimer?.cancel();
    _buscarVentaCtrl.dispose();
    _buscarProductoCtrl.dispose();
    super.dispose();
  }

  Future<void> _refreshVentas({bool keepSelection = true}) async {
    final selId = (keepSelection && _ventaSel != null)
        ? _oidHex(_ventaSel!['_id'])
        : null;

    await _cargarVentas(); // ya reordena, filtra y limpia selección si no existe

    if (!mounted) return;
    setState(() {
      // reintenta mantener la venta seleccionada si sigue existiendo
      if (selId != null) {
        final match = _ventas.firstWhere(
          (v) => _oidHex(v['_id']) == selId,
          orElse: () => {},
        );
        if (match is Map && match.isNotEmpty) {
          _ventaSel = match;
        }
      }
    });
  }

  // ------------ util ids / imágenes ------------
  String _oidHex(dynamic raw) {
    if (raw == null) return '';
    if (raw is ObjectId) return raw.toHexString();
    if (raw is Map && raw[r'$oid'] is String) return raw[r'$oid'] as String;
    final s = raw.toString();
    final m = RegExp(r'ObjectId\("([0-9a-fA-F]{24})"\)').firstMatch(s);
    return m != null ? m.group(1)! : s;
  }

  Widget _imgFromDoc(
    Map<String, dynamic> d, {
    double w = 44,
    double h = 44,
    BoxFit fit = BoxFit.cover,
  }) {
    final String b64 = (d['fotoBase64'] ?? '') as String;
    final String f = (d['foto'] ?? '') as String;

    if (b64.isNotEmpty) {
      try {
        return Image.memory(base64Decode(b64), width: w, height: h, fit: fit);
      } catch (_) {}
    }
    if (f.startsWith('http://') || f.startsWith('https://')) {
      return Image.network(
        f,
        width: w,
        height: h,
        fit: fit,
        errorBuilder: (_, __, ___) => _ph(w, h, broken: true),
      );
    }
    if (f.isNotEmpty && f.startsWith('/')) {
      final file = File(f);
      if (file.existsSync())
        return Image.file(file, width: w, height: h, fit: fit);
    }
    if (f.isNotEmpty && !f.startsWith('http') && !f.startsWith('/')) {
      try {
        return Image.memory(base64Decode(f), width: w, height: h, fit: fit);
      } catch (_) {}
    }
    return _ph(w, h);
  }

  Widget _ph(double w, double h, {bool broken = false}) => Container(
    width: w,
    height: h,
    color: Colors.grey[300],
    child: Icon(broken ? Icons.broken_image : Icons.photo, size: w * .6),
  );

  // ------------ FILTRO: solo ventas regulares ------------
  bool _esVentaParaCambio(Map<String, dynamic> v) {
    // Oculta:
    // - tipoVenta: 'abono_apartado', 'apartado', 'cambio'
    // - ventas con origen.tipo == 'apartado' (ventas creadas desde apartado)
    final tipoVenta = '${v['tipoVenta'] ?? ''}'.toLowerCase().trim();
    if (tipoVenta == 'abono_apartado' ||
        tipoVenta == 'apartado' ||
        tipoVenta == 'cambio') {
      return false;
    }
    final origen = (v['origen'] ?? {}) as Map;
    final origenTipo = '${origen['tipo'] ?? ''}'.toLowerCase().trim();
    if (origenTipo == 'apartado') return false;

    // Todo lo demás se considera "venta regular" y sí se muestra.
    return true;
  }

  // ------------ cargar/filtrar ventas ------------
  Future<List<Map<String, dynamic>>> _cargarVentas() async {
    final v = await MongoService().getVentas();

    // 1) aplica filtro para mostrar solo ventas regulares
    final soloVentas = v.where(_esVentaParaCambio).toList();

    // 2) ordena desc por fecha
    soloVentas.sort((a, b) {
      DateTime da, db;
      try {
        da = DateTime.parse('${a['fechaVenta'] ?? ''}');
      } catch (_) {
        da = DateTime.fromMillisecondsSinceEpoch(0);
      }
      try {
        db = DateTime.parse('${b['fechaVenta'] ?? ''}');
      } catch (_) {
        db = DateTime.fromMillisecondsSinceEpoch(0);
      }
      return db.compareTo(da);
    });

    _ventas = soloVentas;
    _ventasFiltradas = _aplicarFiltroVentas(_buscarVentaCtrl.text.trim());

    // si la venta seleccionada quedó fuera por el filtro, des-selecciona
    if (_ventaSel != null) {
      final selId = _oidHex(_ventaSel!['_id']);
      final sigue = _ventas.any((v) => _oidHex(v['_id']) == selId);
      if (!sigue) {
        _ventaSel = null;
        _renglonSel = null;
      }
    }

    return _ventas;
  }

  List<Map<String, dynamic>> _aplicarFiltroVentas(String q) {
    if (q.isEmpty) return List.of(_ventas);
    final lq = q.toLowerCase();
    return _ventas.where((v) {
      final id = _oidHex(v['_id']);
      final cliente = (v['cliente'] ?? {}) as Map;
      final nombre = '${cliente['nombre'] ?? ''}'.toLowerCase();
      return id.contains(lq) || nombre.contains(lq);
    }).toList();
  }

  void _onBuscarVentaChanged() {
    _debounceVenta?.cancel();
    _debounceVenta = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _ventasFiltradas = _aplicarFiltroVentas(_buscarVentaCtrl.text.trim());
      });
    });
  }

  // ------------ buscar productos disponibles para reemplazo ------------
  void _onBuscarProductoChanged() {
    _debounceProd?.cancel();
    _debounceProd = Timer(const Duration(milliseconds: 350), () async {
      await _buscarDisponibles(_buscarProductoCtrl.text.trim());
    });
  }

  Future<void> _buscarDisponibles(String q) async {
    if (q.isEmpty) {
      setState(() => _reemplazos = []);
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

      // evita proponer el mismo producto que ya está en la venta (por id)
      final idsVenta = (_ventaSel?['productos'] as List? ?? [])
          .map((l) => (l as Map)['productoId'])
          .map(_oidHex)
          .toSet();
      r = r.where((e) => !idsVenta.contains(_oidHex(e['_id']))).toList();

      setState(() => _reemplazos = r);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al buscar productos: $e')));
    }
  }

  // ------------ lógica de cambio ------------
  Future<void> _confirmarReemplazo(Map<String, dynamic> nuevo) async {
    if (_ventaSel == null || _renglonSel == null) return;

    final double precioViejo = _asDouble(
      _renglonSel!['precioVendido'] ?? _renglonSel!['precioVenta'],
    );
    final double precioNuevo = _asDouble(nuevo['precioVenta']);
    final double diferencia = (precioNuevo - precioViejo);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar cambio'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Anterior: ${_renglonSel!['nombre']} — ${_fmt.format(precioViejo)}',
            ),
            const SizedBox(height: 6),
            Text('Nuevo: ${nuevo['nombre']} — ${_fmt.format(precioNuevo)}'),
            const Divider(height: 18),
            Text(
              (diferencia > 0)
                  ? 'Diferencia a cobrar: ${_fmt.format(diferencia)}'
                  : (diferencia == 0)
                  ? 'Mismo valor: no se generará cargo extra.'
                  : 'Más barato: no se generará saldo a favor (se mantiene el total).',
              style: TextStyle(
                color: (diferencia > 0) ? Colors.red[700] : Colors.green[800],
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _procesarCambio(nuevo, diferencia);
            },
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
  }

  Future<void> _procesarCambio(
    Map<String, dynamic> nuevoProd,
    double diferencia,
  ) async {
    if (_ventaSel == null || _renglonSel == null) return;
    if (_procesando) return;

    setState(() => _procesando = true);
    try {
      final ventaId = _oidHex(_ventaSel!['_id']);
      final prodViejoIdHex = _oidHex(_renglonSel!['productoId']);
      final prodNuevoIdHex = _oidHex(nuevoProd['_id']);

      // Mantener el importe cobrado originalmente
      final double precioViejo = _asDouble(
        _renglonSel!['precioVendido'] ?? _renglonSel!['precioVenta'],
      );

      // Nuevo renglón para la venta (mismo valor cobrado)
      final nuevoRenglon = {
        'productoId': prodNuevoIdHex,
        'nombre': '${nuevoProd['nombre'] ?? ''}',
        'precioVendido': precioViejo,
        'fotoBase64': (nuevoProd['fotoBase64'] ?? '') as String,
        'foto': (nuevoProd['foto'] ?? '') as String,
        'sku': nuevoProd['sku'],
        'talla': nuevoProd['talla'],
        'color': nuevoProd['color'],
      };

      // Auditoría del cambio
      final registroCambio = {
        'fecha': DateTime.now().toIso8601String(),
        'productoAnterior': {
          'productoId': prodViejoIdHex,
          'nombre': '${_renglonSel!['nombre'] ?? ''}',
          'precio': precioViejo,
        },
        'productoNuevo': {
          'productoId': prodNuevoIdHex,
          'nombre': '${nuevoProd['nombre'] ?? ''}',
          'precio': _asDouble(nuevoProd['precioVenta']),
        },
        'diferencia': _asDouble(diferencia),
        'tipo': (diferencia > 0) ? 'con_diferencia' : 'sin_diferencia',
      };

      // 1) Reemplaza la línea y guarda auditoría
      await MongoService().reemplazarProductoEnVenta(
        ventaId,
        prodViejoIdHex,
        nuevoRenglon,
        registroCambio,
      );

      // 2) INVENTARIO (siempre intentamos ambas operaciones)
      String? invWarn;
      try {
        await MongoService().marcarProductosDisponibles([prodViejoIdHex]);
      } catch (e) {
        invWarn = 'No se pudo marcar DISPONIBLE el producto anterior: $e';
      }
      try {
        await MongoService().marcarProductosVendidos([prodNuevoIdHex]);
      } catch (e) {
        invWarn = (invWarn == null)
            ? 'No se pudo marcar VENDIDO el producto nuevo: $e'
            : '$invWarn • No se pudo marcar VENDIDO el producto nuevo: $e';
      }

      // 3) Diferencia a cobrar → venta adicional tipo "cambio"
      if (diferencia > 0) {
        final ventaCambio = {
          'cliente': _ventaSel!['cliente'] ?? {},
          'productos': [
            {
              'productoId': prodNuevoIdHex,
              'nombre': ' Ingreso adicional por cambio',
              'precioVendido': _asDouble(diferencia),
              'fotoBase64': (nuevoProd['fotoBase64'] ?? '') as String,
              'foto': (nuevoProd['foto'] ?? '') as String,
              'sku': 'CAMBIO',
            },
          ],
          'subtotal': _asDouble(diferencia),
          'descuento': 0.0,
          'total': _asDouble(diferencia),
          'fechaVenta': DateTime.now().toIso8601String(),
          'tipoVenta': 'cambio',
          'origen': {
            'tipo': 'cambio',
            'ventaIdOriginal': ventaId,
            'productoAnteriorId': prodViejoIdHex,
            'productoNuevoId': prodNuevoIdHex,
          },
        };
        await MongoService().saveVenta(ventaCambio);
      }

      if (!mounted) return;

      final baseMsg = (diferencia > 0)
          ? 'Cambio aplicado. Se generó venta por diferencia de ${_fmt.format(diferencia)}.'
          : 'Cambio aplicado sin diferencia.';
      final fullMsg = (invWarn == null) ? baseMsg : '$baseMsg\n$invWarn';

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(fullMsg)));

      // 4) Refrescar vista
      await _refreshVentas(keepSelection: true);
      if (!mounted) return;
      setState(() {
        _renglonSel = null;
        _buscarProductoCtrl.clear();
        _reemplazos.clear();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo aplicar el cambio: $e')),
      );
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  double _asDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? 0.0;
  }

  // ------------ UI ------------
  @override
  Widget build(BuildContext context) {
    const Color brandA = Color(0xFF9333EA); // violeta
    const Color brandB = Color(0xFF06B6D4); // cian

    return Scaffold(
      appBar: AppBar(
          elevation: 0,
          centerTitle: true,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.swap_horiz, size: 24),
              SizedBox(width: 8),
              Text('Generar cambios', style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          foregroundColor: Colors.white,
          backgroundColor: const Color.fromRGBO(244, 143, 177, 1)
        ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _futureVentas,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          // ya cargamos a _ventas/_ventasFiltradas en _cargarVentas
          return LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 980;
              final left = _panelVentas();
              final right = _panelDetalleYCambio();
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: left),
                    const VerticalDivider(width: 1),
                    Expanded(child: right),
                  ],
                );
              }
              return ListView(
                children: [left, const SizedBox(height: 8), right],
              );
            },
          );
        },
      ),
    );
  }

  Widget _panelVentas() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _buscarVentaCtrl,
                decoration: InputDecoration(
                  labelText: 'Buscar venta por cliente o ID',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: (_buscarVentaCtrl.text.isNotEmpty)
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() {
                            _buscarVentaCtrl.clear();
                            _ventasFiltradas = _aplicarFiltroVentas('');
                          }),
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (_ventasFiltradas.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No hay ventas que coincidan'),
            )
          else
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _ventasFiltradas.length.clamp(
                  0,
                  50,
                ), // evita listas enormes
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final v = _ventasFiltradas[i];
                  final id = _oidHex(v['_id']);
                  final cliente = (v['cliente'] ?? {}) as Map;
                  final nombre = '${cliente['nombre'] ?? 'Sin nombre'}';
                  DateTime f;
                  try {
                    f = DateTime.parse('${v['fechaVenta'] ?? ''}');
                  } catch (_) {
                    f = DateTime.fromMillisecondsSinceEpoch(0);
                  }
                  final total = _asDouble(v['total']);
                  final productos = (v['productos'] ?? []) as List;

                  return ListTile(
                    selected:
                        _ventaSel != null && _oidHex(_ventaSel!['_id']) == id,
                    selectedTileColor: Colors.amber.withOpacity(.08),
                    leading: CircleAvatar(child: Text('${productos.length}')),
                    title: Text(
                      nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${_fmt.format(total)}  •  ${_fmtFecha.format(f)}',
                    ),
                    
                    onTap: () => setState(() {
                      _ventaSel = v;
                      _renglonSel = null;
                      _buscarProductoCtrl.clear();
                      _reemplazos.clear();
                    }),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _panelDetalleYCambio() {
    if (_ventaSel == null) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('Selecciona una venta para gestionar cambios.'),
      );
    }
    final productos = (_ventaSel!['productos'] ?? []) as List;
    final cliente = (_ventaSel!['cliente'] ?? {}) as Map;
    final nombre = '${cliente['nombre'] ?? 'Sin nombre'}';

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Venta de $nombre',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: productos.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final p = (productos[i] as Map).cast<String, dynamic>();
                final precio = _asDouble(
                  p['precioVendido'] ?? p['precioVenta'],
                );
                return ListTile(
                  selected: _renglonSel == p,
                  selectedTileColor: Colors.blue.withOpacity(.06),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _imgFromDoc(p, w: 54, h: 54),
                  ),
                  title: Text('${p['nombre'] ?? ''}'),
                  subtitle: Text('Cobrado: ${_fmt.format(precio)}'),
                  trailing: (_renglonSel == p)
                      ? const Icon(Icons.check_circle, color: Colors.blue)
                      : const Icon(Icons.swap_horiz),
                  onTap: () => setState(() => _renglonSel = p),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          if (_renglonSel == null)
            const Text('Selecciona el producto que deseas cambiar.')
          else ...[
            // buscador de reemplazo
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Buscar producto de reemplazo (solo disponibles)',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _buscarProductoCtrl,
                      decoration: InputDecoration(
                        labelText: 'Nombre…',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        suffixIcon: (_buscarProductoCtrl.text.isNotEmpty)
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () => setState(() {
                                  _buscarProductoCtrl.clear();
                                  _reemplazos.clear();
                                }),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_reemplazos.isNotEmpty)
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 280),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _reemplazos.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final r = _reemplazos[i];
                            final precioNuevo = _asDouble(r['precioVenta']);
                            final precioViejo = _asDouble(
                              _renglonSel!['precioVendido'] ??
                                  _renglonSel!['precioVenta'],
                            );
                            final diff = precioNuevo - precioViejo;

                            return ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: _imgFromDoc(r, w: 48, h: 48),
                              ),
                              title: Text('${r['nombre'] ?? ''}'),
                              subtitle: Text(
                                'Precio nuevo: ${_fmt.format(precioNuevo)}',
                              ),
                              trailing: Text(
                                (diff > 0)
                                    ? '+${_fmt.format(diff)}'
                                    : (diff == 0 ? 'Igual' : _fmt.format(diff)),
                                style: TextStyle(
                                  color: diff > 0
                                      ? Colors.red[700]
                                      : (diff < 0
                                            ? Colors.green[800]
                                            : Colors.black87),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              onTap: _procesando
                                  ? null
                                  : () => _confirmarReemplazo(r),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
