import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../components/app_utils.dart';
import '../database/inventory_db.dart';
import '../services/notification_service.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final InventoryDB _db = InventoryDB.instance;
  bool _loading = true;
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _spending = [];
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final result = await Future.wait([
      _db.getInventory(),
      _db.getSpendingByStore(),
      _db.getPurchaseHistory(),
    ]);
    if (!mounted) return;
    setState(() {
      _products = result[0];
      _spending = result[1];
      _history = result[2];
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final alerts = _products.where((product) => esAlerta(estadoProducto(product))).length;
    final expired = _products.where((product) => estadoProducto(product) == 'Caducado').length;
    final empty = _products.where((product) => estadoProducto(product) == 'Sin existencia').length;
    final spendingTotal = _spending.fold<double>(0, (sum, row) => sum + (row['total'] as num).toDouble());
    final maxSpending = _spending.fold<double>(0, (maxValue, row) {
      final value = (row['total'] as num).toDouble();
      return value > maxValue ? value : maxValue;
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Resumen y estadísticas')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _reload,
              child: CustomScrollView(slivers: [
                SliverToBoxAdapter(child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.5,
                    children: [
                      _SummaryCard(title: 'Productos', value: '${_products.length}', icon: Icons.inventory_2_outlined, color: Colors.green.shade700),
                      _SummaryCard(title: 'Con alerta', value: '$alerts', icon: Icons.notifications_active_outlined, color: Colors.orange.shade800),
                      _SummaryCard(title: 'Caducados', value: '$expired', icon: Icons.warning_amber_outlined, color: Colors.red.shade700),
                      _SummaryCard(title: 'Sin existencia', value: '$empty', icon: Icons.remove_shopping_cart_outlined, color: Colors.deepOrange.shade700),
                    ],
                  ),
                )),
                SliverToBoxAdapter(child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                  child: Card(child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Gasto registrado por tienda', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('Total histórico registrado: ${monedaFormato.format(spendingTotal)}'),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            try {
                              await NotificationService.instance.showTestNotification();
                              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Se envió una notificación de prueba. Revisa el panel de notificaciones.')));
                            } catch (e) {
                              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo mostrar la prueba: $e')));
                            }
                          },
                          icon: const Icon(Icons.notifications_active_outlined),
                          label: const Text('Probar notificación local'),
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (_spending.isEmpty || maxSpending <= 0)
                        const SizedBox(height: 100, child: Center(child: Text('Registra compras al crear lotes para generar la gráfica.')))
                      else
                        SizedBox(
                          height: 250,
                          child: BarChart(
                            BarChartData(
                              minY: 0,
                              maxY: maxSpending * 1.25,
                              gridData: const FlGridData(show: true, drawVerticalLine: false),
                              borderData: FlBorderData(show: false),
                              barGroups: List.generate(_spending.length, (index) {
                                final amount = (_spending[index]['total'] as num).toDouble();
                                return BarChartGroupData(x: index, barRods: [
                                  BarChartRodData(toY: amount, width: 22, color: Colors.green.shade700, borderRadius: BorderRadius.circular(5)),
                                ]);
                              }),
                              titlesData: FlTitlesData(
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                leftTitles: AxisTitles(sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 48,
                                  getTitlesWidget: (value, meta) => SideTitleWidget(
                                  meta: meta,
                                  child: Text(
                                    value.toInt().toString(),
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                ),
                                )),
                                bottomTitles: AxisTitles(sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 48,
                                  getTitlesWidget: (value, meta) {
                                    final index = value.toInt();
                                    if (index < 0 || index >= _spending.length) return const SizedBox.shrink();
                                    return SideTitleWidget(
                                    meta: meta,
                                    space: 8,
                                    child: SizedBox(
                                      width: 65,
                                      child: Text(
                                        _spending[index]['name'].toString(),
                                        maxLines: 2,
                                        textAlign: TextAlign.center,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                    ),
                                  );
                                  },
                                )),
                              ),
                              barTouchData: BarTouchData(enabled: true),
                            ),
                          ),
                        ),
                    ]),
                  )),
                )),
                SliverToBoxAdapter(child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text('Compras recientes', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                )),
                if (_history.isEmpty)
                  const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(16), child: Text('Aún no se han registrado compras.')))
                else
                  SliverList(delegate: SliverChildBuilderDelegate((context, index) {
                    final entry = _history[index];
                    final total = (entry['quantity'] as num).toDouble() * (entry['unit_cost'] as num).toDouble();
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.receipt_long_outlined)),
                      title: Text(entry['product_name']?.toString() ?? 'Producto'),
                      subtitle: Text('${entry['store_name']} · ${fechaTexto(entry['purchased_at'])} · Cantidad: ${entry['quantity']}'),
                      trailing: Text(monedaFormato.format(total), style: const TextStyle(fontWeight: FontWeight.w600)),
                    );
                  }, childCount: _history.length > 20 ? 20 : _history.length)),
                const SliverToBoxAdapter(child: SizedBox(height: 30)),
              ]),
            ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.title, required this.value, required this.icon, required this.color});
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Icon(icon, color: color, size: 25),
        Text(value, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
        Text(title, style: Theme.of(context).textTheme.bodyMedium),
      ]),
    ));
  }
}
