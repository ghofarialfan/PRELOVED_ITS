import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  int _selectedIndex = 4;

  String get _displayName {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final meta = user?.userMetadata ?? {};
      final name = (meta['full_name'] ?? meta['name'] ?? '').toString();
      if (name.isNotEmpty) return name;
      final email = user?.email ?? '';
      if (email.isNotEmpty) return email.split('@').first;
    } catch (_) {}
    return 'Pengguna';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      backgroundColor: const Color(0xFFF8FAFF),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2563FF),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(26),
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: Image.network(
                      'https://i.pravatar.cc/80?img=1',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) {
                        return const Center(child: Icon(CupertinoIcons.person_fill, color: Color(0xFF2563FF)));
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _displayName,
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 4),
                        const Text(
                          'Edit Profil',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const Icon(CupertinoIcons.chevron_forward, color: Colors.white),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _MenuItem(
              icon: CupertinoIcons.doc_text,
              title: 'Riwayat Pesanan',
              subtitle: 'Lihat riwayat pesanan kamu',
              onTap: () => Navigator.pushNamed(context, '/orders'),
            ),
            const SizedBox(height: 8),
            _MenuItem(
              icon: CupertinoIcons.heart,
              title: 'Favorit',
              subtitle: 'Atur barang preloved favorit kamu',
            ),
            const SizedBox(height: 8),
            _MenuItem(
              icon: CupertinoIcons.square_arrow_right,
              title: 'Log out',
              subtitle: null,
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) {
          setState(() {
            _selectedIndex = i;
          });
        },
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(CupertinoIcons.house),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: const Icon(CupertinoIcons.heart),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: const Icon(CupertinoIcons.list_bullet),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: const Icon(CupertinoIcons.bag),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: const Icon(CupertinoIcons.person),
            label: '',
          ),
        ],
        selectedItemColor: Colors.black,
        unselectedItemColor: const Color(0xFF2563FF),
        showSelectedLabels: false,
        showUnselectedLabels: false,
        backgroundColor: Colors.white,
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  const _MenuItem({required this.icon, required this.title, this.subtitle, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFE9F0FF),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(icon, color: const Color(0xFF2563FF)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black)),
        subtitle: subtitle != null ? Text(subtitle!, style: const TextStyle(color: Color(0xFF8E99AF), fontSize: 12)) : null,
        trailing: const Icon(CupertinoIcons.chevron_forward, color: Colors.black38),
        onTap: onTap,
      ),
    );
  }
}
