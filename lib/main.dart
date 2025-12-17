import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import 'start_page.dart';

import 'home_page.dart';
import 'profile_page.dart';
import 'orders_page.dart';
import 'edit_profile_page.dart';
import 'edit_photo_page.dart';
import 'favorites_page.dart';
import 'cart/cart_page.dart';
import 'payment/payment_success_view.dart';

import 'auth/login_email_page.dart';
import 'auth/register_page.dart';
import 'auth/reset_request_page.dart';
import 'auth/reset_new_password_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = 'https://qasmoyqdipdwngghboob.supabase.co';
  const supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFhc21veXFkaXBkd25nZ2hib29iIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQzMzE4MjMsImV4cCI6MjA3OTkwNzgyM30.r-G27SvnEleAB03l9cGr64nuuCurvAcpX4aR9SjWGzY';

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

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
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0051FF)),
        useMaterial3: true,
        textTheme: GoogleFonts.nunitoSansTextTheme(),
        primaryColor: const Color(0xFF0051FF),
      ),
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.mouse,
          PointerDeviceKind.touch,
          PointerDeviceKind.stylus,
          PointerDeviceKind.unknown,
        },
      ),

      // ENTRY POINT UTAMA
      home: const AuthGate(),

      routes: {
        '/start': (context) => const StartPage(),

        '/home': (context) => const HomePage(),
        '/profile': (context) => const ProfilePage(),
        '/orders': (context) => const OrdersPage(),
        '/edit_profile': (context) => const EditProfilePage(),
        '/edit_photo': (context) => const EditPhotoPage(),
        '/favorites': (context) => const FavoritesPage(),
        '/cart': (context) => const CartPage(),
        '/payment_success': (context) => const PaymentSuccessView(),

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

  /// Untuk handle link reset password:
  /// http://localhost:xxxx/?code=...#/reset-new
  Future<void> _consumeRecoveryCodeIfAny() async {
    final code = Uri.base.queryParameters['code'];
    if (code == null || code.isEmpty) return;

    try {
      await Supabase.instance.client.auth.exchangeCodeForSession(code);
    } catch (_) {
      // kalau gagal, biarkan saja – halaman reset akan handle error
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

            // KHUSUS reset password
            if (event == AuthChangeEvent.passwordRecovery) {
              return const ResetNewPasswordPage();
            }

            final session = Supabase.instance.client.auth.currentSession;

            // Sudah login → Home
            if (session != null) {
              return const HomePage();
            }

            // Belum login → Start Page (landing)
            return const StartPage();
          },
        );
      },
    );
  }
}
