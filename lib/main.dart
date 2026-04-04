import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/role_home_screen.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _BootstrapApp());
}

class _BootstrapApp extends StatefulWidget {
  const _BootstrapApp();

  @override
  State<_BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<_BootstrapApp> {
  late final Future<void> _initFuture = _init();

  Future<void> _init() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 20));

    final supabaseConfig = await _loadSupabaseConfig();
    final supabaseUrl = supabaseConfig['SUPABASE_URL'] as String? ?? '';
    final supabaseAnonKey = supabaseConfig['SUPABASE_ANON_KEY'] as String? ?? '';

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
      storageBucket: supabaseConfig['SUPABASE_STORAGE_BUCKET'] as String? ?? '',
    );

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    ).timeout(const Duration(seconds: 20));

  await AuthService.instance.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, _) {
        return MaterialApp(
          key: ValueKey(_authService.currentUser?.email ?? 'logged-out'),
          title: 'Project Cuoi Ky',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: authService.currentUser == null || authService.isRegistering
              ? LoginScreen(authService: authService)
              : RoleHomeScreen(authService: authService),
        );
      },
    );
  }
}
