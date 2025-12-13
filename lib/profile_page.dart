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
  String? _name;
  String? _avatarUrl;

  Future<void> _loadUserProfile() async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return;

      final resId = await client
          .from('users')
          .select()
          .eq('id', user.id)
          .limit(1);
      var list = (resId as List<dynamic>);

      if (list.isNotEmpty) {
        final m = list.first as Map<String, dynamic>;
        final name = (m['full_name'] ?? '').toString();
        final avatar = (m['avatar_url'] ?? m['photo_url'] ?? '').toString();
        setState(() {
          _name = name.isNotEmpty ? name : null;
          _avatarUrl = avatar.isNotEmpty ? avatar : null;
        });
        debugPrint('Loaded user full_name: ${_name ?? '-'}');
      } else {
        final meta = user.userMetadata ?? {};
        final candidateName =
            (meta['full_name'] ??
                    meta['name'] ??
                    user.email?.split('@').first ??
                    '')
                .toString();
        final candidateAvatar = (meta['avatar_url'] ?? meta['picture'] ?? '')
            .toString();
        final candidateUsername = user.email?.split('@').first ?? candidateName;

        try {
          await client.from('users').upsert({
            'id': user.id,
            'full_name': candidateName,
            'photo_url': candidateAvatar,
            if ((user.email ?? '').isNotEmpty) 'email': user.email,
            'username': candidateUsername,
          }, onConflict: 'id');

          setState(() {
            _name = candidateName.isNotEmpty ? candidateName : null;
            _avatarUrl = candidateAvatar.isNotEmpty ? candidateAvatar : null;
          });
          debugPrint('Upserted users row with full_name: ${_name ?? '-'}');
        } catch (e) {
          debugPrint('Users upsert failed: ${e.toString()}');
        }
      }
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  String get _displayName {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final meta = user?.userMetadata ?? {};
      if (_name != null && _name!.isNotEmpty) return _name!;
      final name = (meta['full_name'] ?? '').toString();
      if (name.isNotEmpty) return name;

      final email = user?.email ?? '';
      if (email.isNotEmpty) return email.split('@').first;
    } catch (_) {}
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

      // bersihkan history biar tidak bisa back ke halaman sebelumnya
      Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal logout: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_name == null || _avatarUrl == null) {
      _loadUserProfile();
    }

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
                      child: Image.network(
                        (_avatarUrl == null || _avatarUrl!.isEmpty)
                            ? 'https://i.pravatar.cc/80?img=1'
                            : _avatarUrl!,
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
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      CupertinoIcons.chevron_forward,
                      color: Colors.white,
                    ),
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
          setState(() {
            _selectedIndex = i;
          });
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.house), label: ''),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.heart), label: ''),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.list_bullet),
            label: '',
          ),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.bag), label: ''),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.person), label: ''),
        ],
        selectedItemColor: Colors.black,
        unselectedItemColor: Color(0xFF2563FF),
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
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle!,
                style: const TextStyle(color: Color(0xFF8E99AF), fontSize: 12),
              )
            : null,
        trailing: const Icon(
          CupertinoIcons.chevron_forward,
          color: Colors.black38,
        ),
        onTap: onTap,
      ),
    );
  }
}
