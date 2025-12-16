import 'package:flutter/material.dart';
<<<<<<< HEAD
import 'nego_page.dart';
import 'chat_page.dart';
import 'chat_list_page.dart';
=======
import 'package:supabase_flutter/supabase_flutter.dart';

import 'home_page.dart';
import 'profile_page.dart';
import 'orders_page.dart';
import 'edit_profile_page.dart';
import 'edit_photo_page.dart';
import 'favorites_page.dart';

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

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
>>>>>>> 2155c4aafe98a8784ebfbb64c0382fb8edb2ae3a

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
        '/favorites': (context) => const FavoritesPage(),

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
<<<<<<< HEAD
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                  MaterialPageRoute(builder: (_) => NegoPage(
                    productId: "P001", 
                    productName: "Sepatu Nike Air", 
                    productPrice: 450000,
                    productImage: "https://i.imgur.com/BoN9kdC.png",)),
      );
    },
    child: const Text("Buka Halaman Nego"),
  ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
=======
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
>>>>>>> 2155c4aafe98a8784ebfbb64c0382fb8edb2ae3a
    );
  }
}
