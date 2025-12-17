import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  int _selectedIndex = 4;

  String? _name;
  String? _avatarUrl;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    setState(() => _loading = true);

    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final res = await client
          .from('users')
          .select('full_name, photo_url, avatar_url')
          .eq('id', user.id)
          .maybeSingle();

      // ambil dari DB dulu
      final dbName = (res?['full_name'] ?? '').toString().trim();
      final dbPhoto = (res?['photo_url'] ?? res?['avatar_url'] ?? '').toString().trim();

      // fallback dari metadata auth
      final meta = user.userMetadata ?? {};
      final metaName =
          (meta['full_name'] ?? meta['name'] ?? user.email?.split('@').first ?? '').toString().trim();
      final metaPhoto =
          (meta['photo_url'] ?? meta['avatar_url'] ?? meta['picture'] ?? '').toString().trim();

      final finalName = dbName.isNotEmpty ? dbName : metaName;
      final finalPhoto = dbPhoto.isNotEmpty ? dbPhoto : metaPhoto;

      if (!mounted) return;
      setState(() {
        _name = finalName.isNotEmpty ? finalName : null;
        _avatarUrl = finalPhoto.isNotEmpty ? finalPhoto : null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String get _displayName {
    final n = (_name ?? '').trim();
    if (n.isNotEmpty) return n;

    final user = Supabase.instance.client.auth.currentUser;
    final email = (user?.email ?? '').trim();
    if (email.isNotEmpty) return email.split('@').first;

    return 'Pengguna';
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar'),
        content: const Text('Yakin ingin logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal logout: $e')),
      );
    }
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
        child: RefreshIndicator(
          onRefresh: _loadUserProfile,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              InkWell(
                onTap: () => Navigator.pushNamed(context, '/edit_profile'),
                child: Container(
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
                        child: _loading
                            ? const Center(child: CupertinoActivityIndicator())
                            : (_avatarUrl == null || _avatarUrl!.isEmpty)
                                ? const Center(
                                    child: Icon(
                                      CupertinoIcons.person_fill,
                                      color: Color(0xFF2563FF),
                                    ),
                                  )
                                : Image.network(
                                    _avatarUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stack) {
                                      return const Center(
                                        child: Icon(
                                          CupertinoIcons.person_fill,
                                          color: Color(0xFF2563FF),
                                        ),
                                      );
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
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
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
                onTap: () => Navigator.pushNamed(context, '/favorites'),
              ),
              const SizedBox(height: 8),
              _MenuItem(
                icon: CupertinoIcons.square_arrow_right,
                title: 'Log out',
                subtitle: null,
                onTap: _logout,
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) {
          if (i == 0) {
            Navigator.pushNamed(context, '/home');
            return;
          }
          if (i == 1) {
            Navigator.pushNamed(context, '/favorites');
            return;
          }
          if (i == 2) {
            Navigator.pushNamed(context, '/orders');
            return;
          }
          setState(() => _selectedIndex = i);
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.house), label: ''),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.heart), label: ''),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.list_bullet), label: ''),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.bag), label: ''),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.person), label: ''),
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

  const _MenuItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

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
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle!,
                style: const TextStyle(color: Color(0xFF8E99AF), fontSize: 12),
              )
            : null,
        trailing: const Icon(CupertinoIcons.chevron_forward, color: Colors.black38),
        onTap: onTap,
      ),
    );
  }
}
