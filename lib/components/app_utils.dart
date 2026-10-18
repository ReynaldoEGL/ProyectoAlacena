import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

final DateFormat fechaFormato = DateFormat('dd/MM/yyyy', 'es_MX');
final NumberFormat monedaFormato = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

DateTime soloFecha(DateTime fecha) => DateTime(fecha.year, fecha.month, fecha.day);

String fechaTexto(Object? value) {
  if (value == null || value.toString().isEmpty) return 'Sin fecha';
  final parsed = DateTime.tryParse(value.toString());
  return parsed == null ? value.toString() : fechaFormato.format(parsed);
}

String fechaIso(DateTime value) {
  final d = soloFecha(value);
  return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

int diasHasta(Object? value) {
  if (value == null) return 999999;
  final parsed = DateTime.tryParse(value.toString());
  if (parsed == null) return 999999;
  return soloFecha(parsed).difference(soloFecha(DateTime.now())).inDays;
}

String estadoProducto(Map<String, dynamic> producto) {
  final stock = (producto['stock_total'] as num?)?.toDouble() ?? 0;
  final vencido = (producto['expired_stock'] as num?)?.toDouble() ?? 0;
  final minimo = (producto['min_stock'] as num?)?.toDouble() ?? 0;
  final diasAlerta = (producto['expiry_alert_days'] as num?)?.toInt() ?? 5;
  final dias = diasHasta(producto['next_expiry']);

  // La prioridad evita esconder un lote vencido detrás de una alerta menos urgente.
  if (vencido > 0) return 'Caducado';
  if (stock <= 0) return 'Sin existencia';
  if (dias >= 0 && dias <= diasAlerta) return 'Por caducar';
  if (stock <= minimo) return 'Por agotarse';
  return 'Disponible';
}

Color colorEstado(String estado) {
  switch (estado) {
    case 'Caducado':
      return Colors.red.shade700;
    case 'Sin existencia':
      return Colors.deepOrange.shade700;
    case 'Por caducar':
      return Colors.orange.shade800;
    case 'Por agotarse':
      return Colors.amber.shade900;
    default:
      return Colors.green.shade700;
  }
}

IconData iconoEstado(String estado) {
  switch (estado) {
    case 'Caducado':
      return Icons.warning_amber_rounded;
    case 'Sin existencia':
      return Icons.remove_shopping_cart_outlined;
    case 'Por caducar':
      return Icons.event_busy_outlined;
    case 'Por agotarse':
      return Icons.inventory_2_outlined;
    default:
      return Icons.check_circle_outline;
  }
}

bool esAlerta(String estado) => estado != 'Disponible';

Widget imagenProducto(String? path, {double size = 72}) {
  final filePath = path?.trim() ?? '';
  return ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: SizedBox(
      width: size,
      height: size,
      child: filePath.isNotEmpty && File(filePath).existsSync()
          ? Image.file(File(filePath), fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _imagenVacia(size))
          : _imagenVacia(size),
    ),
  );
}

Widget _imagenVacia(double size) => Container(
      color: Colors.green.shade50,
      alignment: Alignment.center,
      child: Icon(Icons.kitchen_outlined, size: size * .48, color: Colors.green.shade700),
    );
