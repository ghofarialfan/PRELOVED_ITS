import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'home_page.dart';
import 'profile_page.dart';
import 'home_page.dart';
import 'orders_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'edit_profile_page.dart';
import 'edit_photo_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const devUrl = 'https://qasmoyqdipdwngghboob.supabase.co';
  const devAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFhc21veXFkaXBkd25nZ2hib29iIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQzMzE4MjMsImV4cCI6MjA3OTkwNzgyM30.r-G27SvnEleAB03l9cGr64nuuCurvAcpX4aR9SjWGzY';
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: kReleaseMode ? '' : devUrl);
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: kReleaseMode ? '' : devAnonKey);
  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    debugPrint('Supabase env not provided; using dev fallback: ${kReleaseMode ? 'disabled' : 'enabled'}');
  }
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
      home: const HomePage(),
      routes: {
        '/profile': (context) => const ProfilePage(),
        '/orders': (context) => const OrdersPage(),
        '/home': (context) => const HomePage(),
        '/edit_profile': (context) => const EditProfilePage(),
        '/edit_photo': (context) => const EditPhotoPage(),
      },
    );
  }
}
