// lib/pages/prestamos_activos_page.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:gestion_inventario/services/mongo_service.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;

class PrestamosActivosPage extends StatefulWidget {
  const PrestamosActivosPage({super.key});

  @override
  State<PrestamosActivosPage> createState() => _PrestamosActivosPageState();
}

class _PrestamosActivosPageState extends State<PrestamosActivosPage> {
  final _fmtFecha = DateFormat('dd/MM/yyyy HH:mm');
  final _mon = NumberFormat.currency(locale: 'es_CO', symbol: r'$');

  Future<List<Map<String, dynamic>>>? _future;
  final Set<String> _loadingIds = {};

  @override
  void initState() {
    super.initState();
    _future = _cargarPrestamosActivos();
  }

  // -------- Helpers num/double seguros --------
  double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? 0.0;
  }

  double _clampD(num value, num lower, num upper) {
    return value.clamp(lower, upper).toDouble();
  }

  // --------- ObjectId helpers ---------
  String _oidHex(dynamic raw) {
    if (raw == null) return '';
    if (raw is ObjectId) return raw.toHexString();
    if (raw is Map && raw[r'$oid'] is String) return raw[r'$oid'] as String;

    final s = raw.toString();
    final mHex = RegExp(r'^[0-9a-fA-F]{24}$').firstMatch(s);
    if (mHex != null) return mHex.group(0)!;

    final mObj = RegExp(r'ObjectId\("([0-9a-fA-F]{24})"\)').firstMatch(s);
    if (mObj != null) return mObj.group(1)!;

    final mAny = RegExp(r'([0-9a-fA-F]{24})').firstMatch(s);
    return mAny?.group(1) ?? '';
  }

  // --------- UI helpers ---------
  Widget _placeholder(double w, double h, {bool broken = false}) {
    return Container(
      width: w,
      height: h,
      color: Colors.grey[300],
      child: Icon(broken ? Icons.broken_image : Icons.photo, size: w * 0.6),
    );
  }

  Widget _buildImage(
    Map<String, dynamic> doc, {
    double w = 64,
    double h = 64,
    double radius = 10,
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

  Widget _rowInfo(String l, String v) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(l),
        Flexible(child: Text(v, textAlign: TextAlign.right)),
      ],
    );
  }

  // ---------- Data ----------
  Future<List<Map<String, dynamic>>> _cargarPrestamosActivos() async {
    try {
      // 1) Intenta traer por estado 'activo'
      List<Map<String, dynamic>> base = [];
      try {
        base = await MongoService().getPrestamos(estado: 'activo');
      } catch (_) {
        // si tu service no acepta estado, seguimos abajo
      }

      // 2) Si vino vacío, trae todos y filtra manualmente
      if (base.isEmpty) {
        try {
          base = await MongoService().getPrestamos();
        } catch (_) {
          /* ignore */
        }
      }

      // 3) Filtra: 'activo' O con al menos una línea en 'prestado'
      final activos = base.where((pr) {
        final estadoDoc = '${pr['estado'] ?? ''}'.toLowerCase().trim();
        final List prendas =
            ((pr['prendas'] ?? pr['productos'] ?? pr['items']) as List?) ??
            const [];
        final tienePrestado = prendas.any((e) {
          final m = (e as Map).cast<String, dynamic>();
          final el = '${m['estadoLinea'] ?? 'prestado'}'.toLowerCase();
          return el == 'prestado';
        });
        return estadoDoc == 'activo' || tienePrestado;
      }).toList();

      // 4) Ordena por fecha desc (si existe)
      activos.sort((a, b) {
        DateTime da, db;
        try {
          da = DateTime.parse('${a['fechaPrestamo'] ?? ''}');
        } catch (_) {
          da = DateTime.fromMillisecondsSinceEpoch(0);
        }
        try {
          db = DateTime.parse('${b['fechaPrestamo'] ?? ''}');
        } catch (_) {
          db = DateTime.fromMillisecondsSinceEpoch(0);
        }
        return db.compareTo(da);
      });

      return activos;
    } catch (_) {
      return [];
    }
  }

  Future<void> _refresh() async {
    final fut = _cargarPrestamosActivos(); // 1) correr lo async FUERA
    if (!mounted) return;
    setState(() {
      // 2) callback sin async y sin =>
      _future = fut; //    no devolver nada
    });
    await fut; // 3) esperar después
  }

  // -------- Dialogo de venta (precio, descuento, total, ganancia) --------
  Future<double?> _dialogoVenderLinea({
    required BuildContext context,
    required double precio,
    required double costo, // si no se conoce, pasa 0
  }) async {
    final c = TextEditingController();

    return showDialog<double>(
      context: context,
      builder: (ctx) {
        double descuento = 0.0;
        double total = precio;
        double ganancia = _clampD(precio - costo, 0.0, double.infinity);

        void _recalc(String v, void Function(void Function()) setSt) {
          final d = _clampD(_toDouble(v), 0.0, precio);
          setSt(() {
            descuento = d;
            total = _clampD(precio - d, 0.0, precio);
            ganancia = _clampD(total - costo, 0.0, double.infinity);
          });
        }

        return StatefulBuilder(
          builder: (ctx, setSt) {
            // Calcula una vez al abrir
            if (descuento == 0 && total == precio) {
              _recalc(c.text, setSt);
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('Vender producto'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Precio
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Precio'),
                      Text(
                        _mon.format(precio),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Descuento input
                  TextField(
                    controller: c,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Descuento (opcional)',
                      prefixText: r'$',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (v) => _recalc(v, setSt),
                  ),

                  const SizedBox(height: 14),
                  // Total a pagar
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        ctx,
                      ).colorScheme.primary.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(ctx).dividerColor.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total a pagar',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _mon.format(total),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Descuento',
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                            Text(_mon.format(descuento)),
                          ],
                        ),
                        if (costo > 0) ...[
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Ganancia (estimada)',
                                style: TextStyle(color: Colors.grey[700]),
                              ),
                              Text(
                                _mon.format(ganancia),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.point_of_sale),
                  onPressed: () {
                    final d = _clampD(_toDouble(c.text), 0.0, precio);
                    Navigator.pop(ctx, d);
                  },
                  label: const Text('Vender'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // -------- Marcar línea y crear venta si aplica --------
Future<void> _marcarLinea(
  Map<String, dynamic> prestamo,
  Map<String, dynamic> linea, {
  required String nuevoEstadoLinea, // 'devuelto' | 'vendido'
  double? descuento,
}) async {
  final prestamoId = _oidHex(prestamo['_id']);
  final pidHex = _oidHex(linea['productoId']);
  final nombreProd = '${linea['nombre'] ?? ''}';

  if (pidHex.isEmpty) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ID de producto inválido')),
      );
    }
    return;
  }

  if (mounted) {
    setState(() => _loadingIds.add('$prestamoId|$pidHex'));
  }

  try {
    // Inventario
    if (nuevoEstadoLinea == 'devuelto') {
      await MongoService().marcarProductosDisponibles([pidHex]);
    } else if (nuevoEstadoLinea == 'vendido') {
      await MongoService().marcarProductosVendidos([pidHex]);
    }

    // Actualiza array de prendas en el préstamo
    final List prendas =
        (prestamo['prendas'] ?? prestamo['productos'] ?? prestamo['items'] ?? [])
            as List;
    final nuevas = prendas.map((raw) {
      final m = (raw as Map).cast<String, dynamic>();
      final idLinea = _oidHex(m['productoId']);
      if (idLinea == pidHex) {
        final updated = {...m, 'estadoLinea': nuevoEstadoLinea};
        if (nuevoEstadoLinea == 'vendido' && descuento != null) {
          updated['ventaRegistrada'] = true;
          updated['descuento'] = descuento;
        }
        return updated;
      }
      return m;
    }).toList();

    final todasResueltas = nuevas.every((m) {
      final el = (m['estadoLinea'] ?? 'prestado').toString().toLowerCase();
      return el == 'devuelto' || el == 'vendido';
    });

    // Actualiza el estado del préstamo a 'cerrado' si todas las líneas están 'devueltas' o 'vendidas'
    if (todasResueltas) {
      await MongoService().actualizarPrestamo(
        prestamoId,
        prendas: nuevas,
        estado: 'cerrado',
      );
      // Elimina el préstamo de la base de datos
      await MongoService().eliminarPrestamo(prestamoId); // Elimina el préstamo cerrado
    } else {
      await MongoService().actualizarPrestamo(
        prestamoId,
        prendas: nuevas,
        estado: 'activo',
      );
    }

    // Mensaje
    if (mounted) {
      final msg = (nuevoEstadoLinea == 'devuelto')
          ? '✅ ${nombreProd.isEmpty ? "Producto" : nombreProd} devuelto'
          : '✅ ${nombreProd.isEmpty ? "Producto" : nombreProd} vendido${(descuento ?? 0) > 0 ? " (desc. ${_mon.format(descuento)})" : ""}';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(msg)));
    }

    await _refresh();
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error actualizando línea: $e')));
    }
  } finally {
    if (mounted) {
      setState(() => _loadingIds.remove('$prestamoId|$pidHex'));
    }
  }
}

  // -------- Crear venta para UNA línea (con ganancia) --------
  Future<void> _crearVentaPorLinea(
    Map<String, dynamic> prestamo,
    Map<String, dynamic> linea, {
    required double descuento,
  }) async {
    final prestamoId = _oidHex(prestamo['_id']);
    final cliente = (prestamo['cliente'] ?? {}) as Map<String, dynamic>;

    final precio = _toDouble(linea['precioVenta']);
    final costo = _toDouble(
      linea['precioCosto'] ?? linea['costo'] ?? linea['precioCompra'],
    );
    final total = _clampD(precio - descuento, 0.0, precio);
    final ganancia = _clampD(total - costo, 0.0, double.infinity);

    final venta = {
      'cliente': {
        'nombre': '${cliente['nombre'] ?? ''}',
        'telefono': '${cliente['telefono'] ?? ''}',
      },
      'productos': [
        {
          'productoId': linea['productoId'],
          'nombre': linea['nombre'],
          'precioLista': precio, // precio antes de descuento
          'descuento': descuento,
          'precioVendido': total, // precio final
          'fotoBase64': linea['fotoBase64'] ?? '',
          'foto': linea['foto'] ?? '',
          'sku': linea['sku'],
          'talla': linea['talla'],
          'color': linea['color'],
        },
      ],
      'subtotal': precio,
      'descuento': descuento,
      'total': total,
      'ganancia': ganancia,
      'fechaVenta': DateTime.now().toIso8601String(),
      'origen': {'tipo': 'prestamo', 'prestamoId': prestamoId},
    };

    await MongoService().saveVenta(venta);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Venta registrada: total ${_mon.format(total)} • ganancia ${_mon.format(ganancia)}',
          ),
        ),
      );
    }
  }

  // -------- Registrar venta con varias líneas (las ya marcadas como vendido y NO registradas) --------
  Future<void> _registrarVentaDesdePrestamo(
    Map<String, dynamic> prestamo,
  ) async {
    final prestamoId = _oidHex(prestamo['_id']);
    final cliente = (prestamo['cliente'] ?? {}) as Map;
    final List prendas =
        ((prestamo['prendas'] ?? prestamo['productos'] ?? prestamo['items'])
            as List?) ??
        const [];

    final vendidas = prendas
        .where((e) {
          final m = (e as Map);
          final estado = m['estadoLinea']?.toString().toLowerCase();
          final yaRegistrada = m['ventaRegistrada'] == true;
          return estado == 'vendido' && !yaRegistrada;
        })
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();

    if (vendidas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Marca al menos una prenda como vendida')),
      );
      return;
    }

    // Suma precios lista (si no usas descuento por línea en batch)
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
              'precioLista': p['precioVenta'],
              'descuento': p['descuento'] ?? 0.0,
              'precioVendido': _clampD(
                _toDouble(p['precioVenta']) - _toDouble(p['descuento']),
                0.0,
                _toDouble(p['precioVenta']),
              ),
              'fotoBase64': p['fotoBase64'] ?? '',
              'foto': p['foto'] ?? '',
              'sku': p['sku'],
              'talla': p['talla'],
              'color': p['color'],
            },
          )
          .toList(),
      'subtotal': subtotal,
      'descuento': vendidas.fold<double>(
        0.0,
        (acc, p) => acc + _toDouble(p['descuento']),
      ),
      'total': vendidas.fold<double>(
        0.0,
        (acc, p) =>
            acc +
            _clampD(
              _toDouble(p['precioVenta']) - _toDouble(p['descuento']),
              0.0,
              _toDouble(p['precioVenta']),
            ),
      ),
      'fechaVenta': DateTime.now().toIso8601String(),
      'origen': {'tipo': 'prestamo', 'prestamoId': prestamoId},
    };

    if (mounted) setState(() => _loadingIds.add('$prestamoId|venta'));

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Venta registrada (${vendidas.length} producto(s))'),
        ),
      );
      await _refresh();
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

    return Scaffold(
      appBar: AppBar(
          elevation: 0,
          centerTitle: true,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.pending_actions_outlined, size: 24),
              SizedBox(width: 8),
              Text('Prendas prestadas', style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          foregroundColor: Colors.white,
          backgroundColor: const Color.fromRGBO(244, 143, 177, 1)
        ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 200),
                  Center(child: CircularProgressIndicator()),
                  SizedBox(height: 200),
                ],
              );
            }
            if (snap.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 80),
                  Center(child: Text('Error: ${snap.error}')),
                ],
              );
            }

            final lista = (snap.data ?? []);
            if (lista.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 80),
                  Center(child: Text('No hay préstamos activos')),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: lista.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, idx) {
                final pr = lista[idx];
                final cliente = (pr['cliente'] ?? {}) as Map;
                final nombre = '${cliente['nombre'] ?? 'Sin nombre'}';
                final tel = '${cliente['telefono'] ?? ''}';
                final fecha =
                    DateTime.tryParse('${pr['fechaPrestamo'] ?? ''}') ??
                    DateTime.fromMillisecondsSinceEpoch(0);

                // Toma el arreglo de líneas cualquiera sea el nombre usado
                final List prendas =
                    ((pr['prendas'] ?? pr['productos'] ?? pr['items'])
                        as List?) ??
                    const [];

                // Muestra SOLO las prendas en estado PRESTADO
                final List prendasVisibles = prendas.where((raw) {
                  final m = (raw as Map).cast<String, dynamic>();
                  final el = '${m['estadoLinea'] ?? 'prestado'}'.toLowerCase();
                  return el == 'prestado';
                }).toList();

                // preview
                Widget? preview;
                final Map<String, dynamic>? firstForPreview =
                    prendasVisibles.isNotEmpty
                    ? (prendasVisibles.first as Map).cast<String, dynamic>()
                    : (prendas.isNotEmpty
                          ? (prendas.first as Map).cast<String, dynamic>()
                          : null);
                if (firstForPreview != null) {
                  preview = ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: _buildImage(firstForPreview, w: 56, h: 56),
                  );
                }

                return Card(
                  elevation: 0.8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      leading:
                          preview ?? const Icon(Icons.inventory_2_outlined),
                      tilePadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                      childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      title: Text(
                        nombre.toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(_fmtFecha.format(fecha)),
                      ),
                      children: [
                        const SizedBox(height: 6),
                        _rowInfo('Teléfono', tel.isEmpty ? '—' : tel),
                        const SizedBox(height: 10),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Prendas (en PRESTADO)',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 8),

                        if (prendasVisibles.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'Este préstamo no tiene prendas en estado PRESTADO.',
                            ),
                          )
                        else
                          ...prendasVisibles.map((raw) {
                            final l = (raw as Map).cast<String, dynamic>();
                            final nombreP = '${l['nombre'] ?? ''}';
                            final precio = _toDouble(l['precioVenta']);
                            final costo = _toDouble(
                              l['precioCosto'] ??
                                  l['costo'] ??
                                  l['precioCompra'],
                            );
                            final estadoLinea = (l['estadoLinea'] ?? 'prestado')
                                .toString();

                            final prestamoId = _oidHex(pr['_id']);
                            final pidHex = _oidHex(l['productoId']);
                            final loading = _loadingIds.contains(
                              '$prestamoId|$pidHex',
                            );

                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                children: [
                                  _buildImage(l, w: 64, h: 64, radius: 8),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          nombreP,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _mon.format(precio),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: [
                                            ChoiceChip(
                                              label: const Text('Prestado'),
                                              selected:
                                                  estadoLinea == 'prestado',
                                              onSelected: (_) {},
                                            ),
                                            ChoiceChip(
                                              label: const Text('Devuelto'),
                                              selected:
                                                  estadoLinea == 'devuelto',
                                              onSelected: loading
                                                  ? null
                                                  : (_) => _marcarLinea(
                                                      pr,
                                                      l,
                                                      nuevoEstadoLinea:
                                                          'devuelto',
                                                    ),
                                            ),
                                            ChoiceChip(
                                              label: const Text('Vendido'),
                                              selected:
                                                  estadoLinea == 'vendido',
                                              onSelected: loading
                                                  ? null
                                                  : (_) async {
                                                      // 1) Abrir diálogo para capturar descuento y mostrar total/ganancia
                                                      final desc =
                                                          await _dialogoVenderLinea(
                                                            context: context,
                                                            precio: precio,
                                                            costo: costo,
                                                          );
                                                      if (desc == null)
                                                        return; // cancelado

                                                      // 2) Marcar, actualizar y crear venta
                                                      await _marcarLinea(
                                                        pr,
                                                        l,
                                                        nuevoEstadoLinea:
                                                            'vendido',
                                                        descuento: desc,
                                                      );
                                                    },
                                            ),
                                            if (loading)
                                              const Padding(
                                                padding: EdgeInsets.only(
                                                  left: 6,
                                                ),
                                                child: SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),

                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton.icon(
                            icon:
                                _loadingIds.contains(
                                  '${_oidHex(pr['_id'])}|venta',
                                )
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.point_of_sale),
                            onPressed:
                                _loadingIds.contains(
                                  '${_oidHex(pr['_id'])}|venta',
                                )
                                ? null
                                : () => _registrarVentaDesdePrestamo(pr),
                            label: const Text('Registrar venta (vendidos)'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
