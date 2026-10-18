import 'package:alacena_local/components/app_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('estadoProducto', () {
    test('identifica un producto sin existencia', () {
      final estado = estadoProducto({
        'stock_total': 0,
        'expired_stock': 0,
        'min_stock': 2,
        'expiry_alert_days': 5,
        'next_expiry': null,
      });

      expect(estado, 'Sin existencia');
    });

    test('da prioridad al estado caducado', () {
      final estado = estadoProducto({
        'stock_total': 0,
        'expired_stock': 3,
        'min_stock': 2,
        'expiry_alert_days': 5,
        'next_expiry': null,
      });

      expect(estado, 'Caducado');
    });
  });
}
