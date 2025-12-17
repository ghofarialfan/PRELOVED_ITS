import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

class StartPage extends StatelessWidget {
  const StartPage({super.key});

  static const _blue = Color(0xFF0051FF);

  // SVG TAS dari kamu (langsung dipakai via SvgPicture.string)
  static const String _bagSvg = '''
<svg width="240" height="271" viewBox="0 0 240 271" fill="none" xmlns="http://www.w3.org/2000/svg">
<path d="M218.962 259.367L0 261.83L38.803 47.4077L193.093 56.2224L218.962 259.367Z" fill="#8BC6FF"/>
<path d="M239.287 270.449H34.7988L35.9478 261.428L218.962 259.368L193.991 63.2796L218.962 60.6016L239.287 270.449Z" fill="#0051FF" fill-opacity="0.6"/>
<path d="M35.9473 261.429L59.3422 77.7134L193.99 63.2805L218.961 259.369L35.9473 261.429Z" fill="#0051FF" fill-opacity="0.6"/>
<path d="M168.601 41.6284H155.517C155.517 25.8845 142.704 13.0779 126.952 13.0779C111.202 13.0779 98.3863 25.8845 98.3863 41.6284H85.3027C85.3027 18.6754 103.987 0.000152588 126.952 0.000152588C149.916 0.000152588 168.601 18.6754 168.601 41.6284Z" fill="#5982DA"/>
</svg>
''';

  @override
  Widget build(BuildContext context) {
    final titleStyle = GoogleFonts.nunitoSans(
      fontSize: 40,
      fontWeight: FontWeight.w900,
      letterSpacing: 1.0,
      color: const Color(0xFF222222),
    );

    final subtitleStyle = GoogleFonts.nunitoSans(
      fontSize: 24,
      fontWeight: FontWeight.w400,
      height: 1.35,
      color: const Color(0xFF2B2B2B),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 70),

              // ICON BULAT + TAS
              Center(
                child: Container(
                  width: 170,
                  height: 170,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 28,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Center(
                    child: SizedBox(
                      width: 92,
                      height: 104,
                      child: SvgPicture.string(_bagSvg),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              Text('PRELOVEDITS', style: titleStyle, textAlign: TextAlign.center),

              const SizedBox(height: 38),

              Text(
                'Aplikasi Jual Beli Barang\nPreloved Untuk Arek ITS',
                style: subtitleStyle,
                textAlign: TextAlign.center,
              ),

              const Spacer(),

              // TOMBOL MULAI!
              SizedBox(
                width: double.infinity,
                height: 82,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/register'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  child: Text(
                    'Mulai!',
                    style: GoogleFonts.nunitoSans(
                      fontSize: 34,
                      fontWeight: FontWeight.w300,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // SAYA SUDAH PUNYA AKUN + BUTTON PANAH
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Saya Sudah Punya Akun',
                    style: GoogleFonts.nunitoSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF5A5A5A),
                    ),
                  ),
                  const SizedBox(width: 16),
                  InkWell(
                    onTap: () => Navigator.pushNamed(context, '/login'),
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: _blue,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Icon(Icons.arrow_forward, color: Colors.white, size: 26),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 34),
            ],
          ),
        ),
      ),
    );
  }
}