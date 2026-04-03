import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/role_home_screen.dart';
import 'services/auth_service.dart';
import 'services/cart_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    throw StateError(
      'Supabase chua duoc cau hinh. Hay chay app voi '
      '--dart-define=SUPABASE_URL=... va --dart-define=SUPABASE_ANON_KEY=... '
      '(va tuy chon SUPABASE_STORAGE_BUCKET).',
    );
  }
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

  await AuthService.instance.init();
  await CartService().loadFromPrefs();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static final AuthService _authService = AuthService.instance;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _authService,
      builder: (context, _) {
        return MaterialApp(
          key: ValueKey(_authService.currentUser?.email ?? 'logged-out'),
          title: 'Project Cuoi Ky',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: _authService.currentUser == null || _authService.isRegistering
              ? LoginScreen(authService: _authService)
              : RoleHomeScreen(authService: _authService),
        );
      },
    );
  }
}
