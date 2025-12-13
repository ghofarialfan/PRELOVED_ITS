import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'home_page.dart';
import 'profile_page.dart';
import 'orders_page.dart';
import 'edit_profile_page.dart';
import 'edit_photo_page.dart';

import 'auth/login_email_page.dart';
import 'auth/register_page.dart';
import 'auth/reset_request_page.dart';
import 'auth/reset_new_password_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // PAKAI DEV CONFIG LANGSUNG (biar tidak 401 Invalid API key)
  const supabaseUrl = 'https://qasmoyqdipdwngghboob.supabase.co';
  const supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFhc21veXFkaXBkd25nZ2hib29iIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQzMzE4MjMsImV4cCI6MjA3OTkwNzgyM30.r-G27SvnEleAB03l9cGr64nuuCurvAcpX4aR9SjWGzY';

  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Preloved ITS',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),

      // AUTO ROUTING: sudah login → Home, belum → Login (kecuali recovery)
      home: const AuthGate(),

      routes: {
        '/home': (context) => const HomePage(),
        '/profile': (context) => const ProfilePage(),
        '/orders': (context) => const OrdersPage(),
        '/edit_profile': (context) => const EditProfilePage(),
        '/edit_photo': (context) => const EditPhotoPage(),

        // auth routes
        '/login': (context) => const LoginEmailPage(),
        '/register': (context) => const RegisterPage(),
        '/reset': (context) => const ResetRequestPage(),
        '/reset-new': (context) => const ResetNewPasswordPage(),
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<void> _consumeRecoveryCodeIfAny() async {
    // 🔥 Ini penting untuk URL model:
    // http://localhost:32929/?code=XXXX#/reset-new
    final code = Uri.base.queryParameters['code'];
    if (code == null || code.isEmpty) return;

    try {
      await Supabase.instance.client.auth.exchangeCodeForSession(code);
    } catch (_) {
      // kalau gagal, biarkan page reset kasih pesan yang jelas
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _consumeRecoveryCodeIfAny(),
      builder: (context, snap) {
        return StreamBuilder<AuthState>(
          stream: Supabase.instance.client.auth.onAuthStateChange,
          builder: (context, snapshot) {
            final event = snapshot.data?.event;

            // ✅ kalau user datang dari link reset password
            if (event == AuthChangeEvent.passwordRecovery) {
              return const ResetNewPasswordPage();
            }

            final session = Supabase.instance.client.auth.currentSession;
            if (session != null) return const HomePage();
            return const LoginEmailPage();
          },
        );
      },
    );
  }
}
