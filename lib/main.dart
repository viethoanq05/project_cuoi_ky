import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/datasources/firestore_datasource.dart';
import 'data/repositories/order_repository.dart';
import 'data/repositories/review_repository.dart';
import 'data/repositories/user_repository.dart';
import 'firebase_options.dart';
import 'providers/checkout_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/order_history_provider.dart';
import 'providers/order_tracking_provider.dart';
import 'providers/review_provider.dart';
import 'providers/user_profile_provider.dart';
import 'screens/login_screen.dart';
import 'screens/role_home_screen.dart';
import 'services/auth_service.dart';
import 'services/cart_service.dart';
import 'services/menu_service.dart';
import 'services/supabase_config.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BootstrapApp());
}

class BootstrapApp extends StatefulWidget {
  const BootstrapApp({super.key});

  @override
  State<BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<BootstrapApp> {
  late final Future<void> _initFuture = _init();

  Future<void> _init() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 20));

    final supabaseConfig = await _loadSupabaseConfig();
    final supabaseUrl = supabaseConfig['SUPABASE_URL'] as String? ?? '';
    final supabaseAnonKey =
        supabaseConfig['SUPABASE_ANON_KEY'] as String? ?? '';
    final supabaseStorageBucket =
        supabaseConfig['SUPABASE_STORAGE_BUCKET'] as String? ?? '';

    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw StateError(
        'Supabase chua duoc cau hinh. Hay chay app voi '
        '--dart-define=SUPABASE_URL=... va --dart-define=SUPABASE_ANON_KEY=... '
        '(va tuy chon SUPABASE_STORAGE_BUCKET).',
      );
    }

    SupabaseConfig.instance.load(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      storageBucket: supabaseStorageBucket,
    );

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    ).timeout(const Duration(seconds: 20));

    await AuthService.instance.init().timeout(const Duration(seconds: 10));
    await CartService().loadFromPrefs().timeout(const Duration(seconds: 10));
  }

  Future<Map<String, dynamic>> _loadSupabaseConfig() async {
    const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
    const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    const supabaseStorageBucket = String.fromEnvironment(
      'SUPABASE_STORAGE_BUCKET',
    );

    if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
      return {
        'SUPABASE_URL': supabaseUrl,
        'SUPABASE_ANON_KEY': supabaseAnonKey,
        'SUPABASE_STORAGE_BUCKET': supabaseStorageBucket,
      };
    }

    try {
      final jsonString = await rootBundle.loadString(
        'assets/supabase.dev.json',
      );
      final config = json.decode(jsonString) as Map<String, dynamic>;
      return {
        'SUPABASE_URL': config['SUPABASE_URL'] as String? ?? '',
        'SUPABASE_ANON_KEY': config['SUPABASE_ANON_KEY'] as String? ?? '',
        'SUPABASE_STORAGE_BUCKET':
            config['SUPABASE_STORAGE_BUCKET'] as String? ?? '',
      };
    } catch (_) {
      return {
        'SUPABASE_URL': supabaseUrl,
        'SUPABASE_ANON_KEY': supabaseAnonKey,
        'SUPABASE_STORAGE_BUCKET': supabaseStorageBucket,
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            home: const Scaffold(
              body: Center(
                child: SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            home: Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Khoi dong that bai:\n${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          );
        }

        final datasource = FirestoreDatasource();
        final userRepository = UserRepository(datasource: datasource);
        final orderRepository = OrderRepository(datasource: datasource);
        final reviewRepository = ReviewRepository(datasource: datasource);

        return MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>.value(
              value: AuthService.instance,
            ),
            Provider<MenuService>.value(value: MenuService.instance),
            ChangeNotifierProvider<CartProvider>(create: (_) => CartProvider()),
            ChangeNotifierProvider<UserProfileProvider>(
              create: (_) =>
                  UserProfileProvider(userRepository: userRepository),
            ),
            ChangeNotifierProvider<OrderHistoryProvider>(
              create: (_) =>
                  OrderHistoryProvider(orderRepository: orderRepository),
            ),
            ChangeNotifierProvider<CheckoutProvider>(
              create: (_) => CheckoutProvider(
                orderRepository: orderRepository,
                userRepository: userRepository,
              ),
            ),
            ChangeNotifierProvider<OrderTrackingProvider>(
              create: (_) =>
                  OrderTrackingProvider(orderRepository: orderRepository),
            ),
            ChangeNotifierProvider<ReviewProvider>(
              create: (_) => ReviewProvider(reviewRepository: reviewRepository),
            ),
          ],
          child: const MyApp(),
        );
      },
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, _) {
        return MaterialApp(
          key: ValueKey(authService.currentUser?.id ?? 'logged-out'),
          title: 'Project Cuoi Ky',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: authService.currentUser == null || authService.isRegistering
              ? const LoginScreen()
              : const RoleHomeScreen(),
        );
      },
    );
  }
}
