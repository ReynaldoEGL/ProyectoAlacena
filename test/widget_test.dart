import 'package:alacena_local/components/app_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('estadoProducto', () {
    test('sin existencia', () {
      expect(
          estadoProducto({
            'stock_total': 0,
            'expired_stock': 0,
            'min_stock': 2,
            'expiry_alert_days': 5,
            'next_expiry': null,
          }),
          'Sin existencia');
    });

    test('los caducados tienen prioridad', () {
      expect(
          estadoProducto({
            'stock_total': 3,
            'expired_stock': 3,
            'min_stock': 2,
            'expiry_alert_days': 5,
            'next_expiry': null,
          }),
          'Caducado');
    });

    test('alerta de bajo stock', () {
      expect(
          estadoProducto({
            'stock_total': 1,
            'expired_stock': 0,
            'min_stock': 2,
            'expiry_alert_days': 5,
            'next_expiry': null,
          }),
          'Por agotarse');
    });

    test('producto disponible', () {
      expect(
          estadoProducto({
            'stock_total': 4,
            'expired_stock': 0,
            'min_stock': 2,
            'expiry_alert_days': 5,
            'next_expiry': null,
          }),
          'Disponible');
    });
  });
}
