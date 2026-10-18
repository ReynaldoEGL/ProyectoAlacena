import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../components/app_utils.dart';
import '../database/inventory_db.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final InventoryDB _db = InventoryDB.instance;
  Map<DateTime, List<Map<String, dynamic>>> _events = {};
  DateTime _focusedDay = soloFecha(DateTime.now());
  DateTime? _selectedDay;
  bool _loading = true;
  bool _argsRead = false;
  bool _openDayFromNotification = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_argsRead) {
      _argsRead = true;
      final arg = ModalRoute.of(context)?.settings.arguments;
      if (arg is DateTime) {
        _selectedDay = soloFecha(arg);
        _focusedDay = soloFecha(arg);
        _openDayFromNotification = true;
      }
      _reload();
    }
  }

  Future<void> _reload() async {
    final raw = await _db.getCalendarEvents();
    final parsed = <DateTime, List<Map<String, dynamic>>>{};
    for (final entry in raw.entries) {
      final date = DateTime.tryParse(entry.key);
      if (date != null) parsed[soloFecha(date)] = entry.value;
    }
    if (!mounted) return;
    setState(() { _events = parsed; _loading = false; });
    if (_openDayFromNotification && _selectedDay != null) {
      _openDayFromNotification = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showDay(_selectedDay!);
      });
    }
  }

  List<Map<String, dynamic>> _eventsForDay(DateTime day) => _events[soloFecha(day)] ?? const [];

  Future<void> _showDay(DateTime day) async {
    final entries = _eventsForDay(day);
    await showDialog<void>(
      context: context,
      useSafeArea: false,
      builder: (_) => Dialog.fullscreen(child: DayAlertsModal(day: day, events: entries)),
    );
  }

  Widget _markerBuilder(BuildContext context, DateTime day, List<dynamic> events) {
    if (events.isEmpty) return const SizedBox.shrink();
    final visibleDots = events.length > 8 ? 8 : events.length;
    return Positioned(
      bottom: 2,
      left: 1,
      right: 1,
      child: Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
        Flexible(child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 2,
          runSpacing: 2,
          children: List.generate(visibleDots, (index) => Container(
            width: 4.5,
            height: 4.5,
            decoration: BoxDecoration(color: Colors.deepOrange.shade600, shape: BoxShape.circle),
          )),
        )),
        if (events.length > 8)
          Text('+${events.length - 8}', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Calendario de alertas')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _reload,
              child: CustomScrollView(slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: TableCalendar<Map<String, dynamic>>(
                          locale: 'es_MX',
                          firstDay: DateTime(2020, 1, 1),
                          lastDay: DateTime(2100, 12, 31),
                          focusedDay: _focusedDay,
                          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                          eventLoader: _eventsForDay,
                          startingDayOfWeek: StartingDayOfWeek.monday,
                          calendarFormat: CalendarFormat.month,
                          rowHeight: 54,
                          headerStyle: const HeaderStyle(
                            formatButtonVisible: false,
                            titleCentered: true,
                            leftChevronIcon: Icon(Icons.chevron_left),
                            rightChevronIcon: Icon(Icons.chevron_right),
                          ),
                          calendarStyle: CalendarStyle(
                            todayDecoration: BoxDecoration(color: Colors.green.shade300, shape: BoxShape.circle),
                            selectedDecoration: BoxDecoration(color: Colors.green.shade800, shape: BoxShape.circle),
                            outsideDaysVisible: false,
                            markersMaxCount: 0,
                          ),
                          calendarBuilders: CalendarBuilders(markerBuilder: _markerBuilder),
                          onDaySelected: (selectedDay, focusedDay) {
                            setState(() { _selectedDay = soloFecha(selectedDay); _focusedDay = soloFecha(focusedDay); });
                            _showDay(selectedDay);
                          },
                          onPageChanged: (focusedDay) => setState(() => _focusedDay = soloFecha(focusedDay)),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                    child: Row(children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: Colors.deepOrange.shade600, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      const Expanded(child: Text('Cada punto representa un producto con una alerta en esa fecha. En días con más de ocho productos, el excedente se indica con +N.')),
                    ]),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 8), child: Text('Alertas de hoy', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))),
                ),
                if (_eventsForDay(DateTime.now()).isEmpty)
                  const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.fromLTRB(16, 4, 16, 30), child: Text('No hay productos con alertas para hoy.')))
                else
                  SliverList(delegate: SliverChildBuilderDelegate((context, index) {
                    final item = _eventsForDay(DateTime.now())[index];
                    return ListTile(
                      leading: imagenProducto(item['image_path']?.toString(), size: 48),
                      title: Text(item['name']?.toString() ?? 'Artículo'),
                      subtitle: Text(item['event_type']?.toString() ?? 'Alerta'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showDay(DateTime.now()),
                    );
                  }, childCount: _eventsForDay(DateTime.now()).length)),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ]),
            ),
    );
  }
}

class DayAlertsModal extends StatelessWidget {
  const DayAlertsModal({super.key, required this.day, required this.events});
  final DateTime day;
  final List<Map<String, dynamic>> events;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(fechaTexto(fechaIso(day))),
        leading: IconButton(tooltip: 'Cerrar', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
      ),
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Productos de esta fecha', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('${events.length} producto(s) con alertas o caducidades registradas.'),
            ]),
          ),
        ),
        if (events.isEmpty)
          const SliverFillRemaining(hasScrollBody: false, child: Center(child: Text('No hay artículos con alertas para esta fecha.')))
        else
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 24),
            sliver: SliverList(delegate: SliverChildBuilderDelegate((context, index) {
              final item = events[index];
              final quantityRaw =
                  item['quantity_current'] ?? item['stock_total'] ?? 0;

              final quantityValue = quantityRaw is num
                  ? quantityRaw.toDouble()
                  : double.tryParse(quantityRaw.toString()) ?? 0.0;
              final unit = item['unit']?.toString() ?? 'pieza';
              final eventType = item['event_type']?.toString() ?? 'Caducidad';
              final lotExpiry = item['expiration_date'] ?? item['next_expiry'];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    imagenProducto(item['image_path']?.toString(), size: 78),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(item['name']?.toString() ?? 'Artículo', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      if ((item['brand']?.toString() ?? '').isNotEmpty) Text(item['brand'].toString()),
                      if ((item['category_name']?.toString() ?? '').isNotEmpty) Text('Categoría: ${item['category_name']}'),
                      const SizedBox(height: 6),
                      Text('Alerta: $eventType', style: TextStyle(color: Colors.deepOrange.shade800, fontWeight: FontWeight.w600)),
                      if (lotExpiry != null) Text('Caducidad: ${fechaTexto(lotExpiry)}'),
                      Text(
                        'Cantidad registrada: '
                        '${quantityValue.toStringAsFixed(quantityValue % 1 == 0 ? 0 : 2)} $unit',
                      ),
                      if (item['store_name'] != null) Text('Tienda: ${item['store_name']}'),
                    ])),
                  ]),
                ),
              );
            }, childCount: events.length)),
          ),
      ]),
    );
  }
}
