// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:preloved_its/main.dart';

void main() {
  setUpAll(() {
    FlutterError.onError = (FlutterErrorDetails details) {
      final msg = details.exception.toString();
      if (msg.contains('HTTP') || msg.contains('NetworkImage') || msg.contains('ImageCodecException')) {
        return;
      }
      FlutterError.presentError(details);
    };
  });
  testWidgets('Profile page renders', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    expect(find.byType(BottomNavigationBar), findsOneWidget);
    await tester.tap(find.byIcon(CupertinoIcons.person));
    await tester.pumpAndSettle();
    expect(find.text('Profil'), findsOneWidget);
    await tester.tap(find.byIcon(CupertinoIcons.house));
    await tester.pumpAndSettle();
    expect(find.text('Selamat Datang, Andra'), findsOneWidget);
  });
}
