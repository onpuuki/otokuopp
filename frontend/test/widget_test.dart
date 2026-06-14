import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/screens/home_screen.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:frontend/screens/url_manager_dialog.dart';

void main() {
  testWidgets('HomeScreen basic rendering and Drawer test', (WidgetTester tester) async {
    final firestore = FakeFirebaseFirestore();

    // Add some test campaigns
    await firestore.collection('campaigns').add({
      'title': 'Test Campaign',
      'storeName': 'Test Store',
      'details': 'Details 123',
      'url': 'https://example.com'
    });

    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(firestore: firestore),
    ));

    // Wait for stream to emit data
    await tester.pumpAndSettle();

    expect(find.text('Test Campaign'), findsOneWidget);

    // Open drawer
    await tester.dragFrom(const Offset(0, 300), const Offset(300, 0));
    await tester.pumpAndSettle();

    expect(find.text('デバッグメニュー'), findsOneWidget);
    expect(find.text('情報取得先URL'), findsOneWidget);

    // Tap on URL manager
    await tester.tap(find.text('情報取得先URL'));
    await tester.pumpAndSettle();

    expect(find.byType(UrlManagerDialog), findsOneWidget);

    // Check initial defaults
    expect(find.text('https://www.family.co.jp/campaign.html'), findsOneWidget);
    expect(find.text('https://www.dennys.jp/campaign/'), findsOneWidget);

    // Try adding a new URL
    await tester.enterText(find.byType(TextField).first, 'https://test.com/new');
    await tester.tap(find.text('追加'));
    await tester.pumpAndSettle();

    expect(find.text('https://test.com/new'), findsOneWidget);

    // Try deleting a URL
    final deleteButtons = find.byIcon(Icons.delete);
    await tester.tap(deleteButtons.first);
    await tester.pumpAndSettle();

    // One url should be deleted (FamilyMart)
    expect(find.text('https://www.family.co.jp/campaign.html'), findsNothing);
  });
}
