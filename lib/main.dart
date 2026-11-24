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
    try {
      await NotificationService.instance.requestPermissions();
    } catch (e) {
      debugPrint('No se pudo solicitar permiso de notificaciones: $e');
    }
    try {
      await NotificationService.instance.handleInitialPayload();
    } catch (e) {
      debugPrint('No se pudo abrir la notificación inicial: $e');
    }
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
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF536646),
          brightness: Brightness.light,
        ).copyWith(
          primary: const Color(0xFF536646),
          secondary: const Color(0xFFB96C4B),
          surface: const Color(0xFFFFFCF6),
          error: const Color(0xFFB64D43),
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F2E9),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Color(0xFFF5F2E9),
          foregroundColor: Color(0xFF30372D),
          surfaceTintColor: Colors.transparent,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD8D8CB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD8D8CB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF536646), width: 1.5),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF536646),
          foregroundColor: Colors.white,
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
        ),
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
