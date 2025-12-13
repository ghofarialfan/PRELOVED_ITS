import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

import 'profile_page.dart';
import 'orders_page.dart';
import 'seller_profile_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const devUrl = 'https://qasmoyqdipdwngghboob.supabase.co';
  const devAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFhc21veXFkaXBkd25nZ2hib29iIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQzMzE4MjMsImV4cCI6MjA3OTkwNzgyM30.r-G27SvnEleAB03l9cGr64nuuCurvAcpX4aR9SjWGzY';

  const envUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  const envAnon = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

  final supabaseUrl = envUrl.isNotEmpty ? envUrl : devUrl;
  final supabaseAnonKey = envAnon.isNotEmpty ? envAnon : devAnonKey;

  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

  if (kDebugMode) {
    debugPrint('Supabase initialized: $supabaseUrl');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // untuk testing (ownerId auth.users.id kamu)
  static const testOwnerId = '7bff2e63-d6ce-4072-88ae-c5c6ac7b36b0';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PreLovedITS',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const ProfilePage(),
      routes: {
        '/profile': (context) => const ProfilePage(),
        '/orders': (context) => const OrdersPage(),
        '/seller': (context) => const SellerProfilePage(ownerId: testOwnerId),
      },
    );
  }
}
