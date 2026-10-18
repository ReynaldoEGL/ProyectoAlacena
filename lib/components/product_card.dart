import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../components/app_utils.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    required this.onAddToCart,
    required this.onEdit,
    required this.onConsume,
    required this.onArchive,
  });

  final Map<String, dynamic> product;
  final VoidCallback onTap;
  final VoidCallback onAddToCart;
  final VoidCallback onEdit;
  final VoidCallback onConsume;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final status = estadoProducto(product);
    final stock = (product['stock_total'] as num?)?.toDouble() ?? 0;
    final unit = product['unit']?.toString() ?? 'pieza';
    final expiry = product['next_expiry'];
    return Slidable(
      key: ValueKey('product-${product['id']}'),
      endActionPane: ActionPane(
        motion: const BehindMotion(),
        extentRatio: .72,
        children: [
          SlidableAction(
            onPressed: (_) => onEdit(),
            backgroundColor: Colors.blue.shade700,
            foregroundColor: Colors.white,
            icon: Icons.edit_outlined,
            label: 'Editar',
            borderRadius: BorderRadius.circular(12),
          ),
          SlidableAction(
            onPressed: (_) => onConsume(),
            backgroundColor: Colors.teal.shade700,
            foregroundColor: Colors.white,
            icon: Icons.remove_circle_outline,
            label: 'Consumir',
          ),
          SlidableAction(
            onPressed: (_) => onArchive(),
            backgroundColor: Colors.red.shade700,
            foregroundColor: Colors.white,
            icon: Icons.archive_outlined,
            label: 'Archivar',
            borderRadius: BorderRadius.circular(12),
          ),
        ],
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                imagenProducto(product['image_path']?.toString(), size: 76),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product['name']?.toString() ?? 'Artículo',
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      if ((product['brand']?.toString() ?? '').isNotEmpty)
                        Text(product['brand'].toString(), style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 5),
                      Text('Existencia: ${stock.toStringAsFixed(stock % 1 == 0 ? 0 : 2)} $unit'),
                      if (expiry != null) Text('Próxima caducidad: ${fechaTexto(expiry)}',
                          style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 7),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: colorEstado(status).withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(iconoEstado(status), size: 15, color: colorEstado(status)),
                            const SizedBox(width: 4),
                            Text(status, style: TextStyle(color: colorEstado(status), fontWeight: FontWeight.w600, fontSize: 12)),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Agregar a la lista de compra',
                  onPressed: onAddToCart,
                  icon: const Icon(Icons.add_shopping_cart_outlined),
                  color: Colors.green.shade800,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
