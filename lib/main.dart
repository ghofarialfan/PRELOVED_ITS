import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://qasmoyqdipdwngghboob.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFhc21veXFkaXBkd25nZ2hib29iIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQzMzE4MjMsImV4cCI6MjA3OTkwNzgyM30.r-G27SvnEleAB03l9cGr64nuuCurvAcpX4aR9SjWGzY',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PreLovedITS',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'PreLovedITS - Supabase Test'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  // Status teks biar kamu bisa lihat hasil tes juga di layar
  String _supabaseStatus = 'Belum dites...';

  @override
  void initState() {
    super.initState();
    _testSupabase(); // auto tes saat app dibuka
  }

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  Future<void> _testSupabase() async {
    setState(() {
      _supabaseStatus = 'Testing Supabase...';
    });

    try {
      // Tes query sederhana (tabel public read)
      final rows = await Supabase.instance.client
          .from('categories')
          .select()
          .limit(5);

      setState(() {
        _supabaseStatus = '✅ CONNECT OK\nResult: $rows';
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('✅ Supabase OK: $rows')));
    } catch (e) {
      setState(() {
        _supabaseStatus = '❌ CONNECT FAIL\nError: $e';
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Supabase ERROR: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'Test Supabase lagi',
            onPressed: _testSupabase,
            icon: const Icon(Icons.wifi_tethering),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text('Counter (UI lama kamu tetap ada):'),
              Text(
                '$_counter',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 24),
              const Text(
                'Status koneksi Supabase:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(_supabaseStatus, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _testSupabase,
                child: const Text('Tes Supabase Sekarang'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
