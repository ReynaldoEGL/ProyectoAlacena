import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'components/app_navigator.dart';
import 'database/inventory_db.dart';
import 'screens/calendar_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/catalog_screen.dart';
import 'screens/inventory_screen.dart';
import 'screens/lot_form_screen.dart';
import 'screens/product_detail_screen.dart';
import 'screens/product_form_screen.dart';
import 'screens/stats_screen.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_MX', null);
  await InventoryDB.instance.database;
  await NotificationService.instance.initialize();
  runApp(const AlacenaApp());
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await NotificationService.instance.requestPermissions();
    await NotificationService.instance.handleInitialPayload();
  });
}

class AlacenaApp extends StatelessWidget {
  const AlacenaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'Mi Alacena',
      debugShowCheckedModeBanner: false,
      locale: const Locale('es', 'MX'),
      supportedLocales: const [Locale('es', 'MX'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF287C57)),
        scaffoldBackgroundColor: const Color(0xFFF7F8F5),
        appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
      ),
      routes: {
        '/': (_) => const InventoryScreen(),
        '/calendar': (_) => const CalendarScreen(),
        '/cart': (_) => const CartScreen(),
        '/product-form': (_) => const ProductFormScreen(),
        '/product-detail': (_) => const ProductDetailScreen(),
        '/lot-form': (_) => const LotFormScreen(),
        '/catalogs': (_) => const CatalogScreen(),
        '/stats': (_) => const StatsScreen(),
      },
    );
  }
}
