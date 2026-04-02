import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/role_home_screen.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
    const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw StateError(
        'Supabase chua duoc cau hinh. Hay chay app voi '
        '--dart-define=SUPABASE_URL=... va --dart-define=SUPABASE_ANON_KEY=... '
        '(hoac --dart-define-from-file=supabase.dev.json).',
      );
    }
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

    await AuthService.instance.init();
    runApp(const MyApp());
  } catch (error) {
    runApp(StartupErrorApp(message: error.toString()));
  }
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

class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'App khoi dong that bai',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Nguyen nhan pho bien: thieu SUPABASE_URL va SUPABASE_ANON_KEY.',
                ),
                const SizedBox(height: 12),
                const Text('Chi tiet loi:'),
                const SizedBox(height: 6),
                Text(message),
                const SizedBox(height: 16),
                const Text(
                  'Goi y: chay app bang launch config Flutter Debug (Supabase) '
                  'hoac them --dart-define khi flutter run.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
