import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AuthBg extends StatelessWidget {
  const AuthBg({super.key, required this.child});

  final Widget child;

  // Blob biru tua (SVG dari kamu)
  static const _blobBlue = r'''
<svg width="269" height="785" viewBox="0 0 269 785" fill="none" xmlns="http://www.w3.org/2000/svg">
<path d="M359.313 70.4723C528.394 -159.511 716.182 230.248 716.182 427.341C716.182 624.435 556.407 784.211 359.313 784.211C162.22 784.211 -23.5674 634.151 2.44454 427.341C28.4565 220.531 190.233 300.456 359.313 70.4723Z" fill="#004BFE"/>
</svg>
''';

  // Blob biru muda (SVG dari kamu)
  static const _blobLight = r'''
<svg width="870" height="972" viewBox="0 0 870 972" fill="none" xmlns="http://www.w3.org/2000/svg">
<path d="M590.897 782.915C473.724 1241.84 -57.4505 758.928 -179.96 455.705C-302.47 152.482 -155.974 -192.642 147.249 -315.152C450.472 -437.662 698.164 -234.3 831.918 33.2089C965.672 300.718 708.069 323.994 590.897 782.915Z" fill="#D9E4FF"/>
</svg>
''';

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Warna dasar background
        Container(color: const Color(0xFFF8FAFF)),

        // Blob biru muda (posisi kira-kira seperti Figma)
        Positioned(
          left: -280,
          top: -280,
          child: SvgPicture.string(_blobLight, width: 560),
        ),

        // Blob biru tua (di kanan)
        Positioned(
          right: -160,
          top: -60,
          child: SvgPicture.string(_blobBlue, width: 260, height: 760),
        ),

        SafeArea(child: child),
      ],
    );
  }
}
