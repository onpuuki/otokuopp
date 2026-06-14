import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:frontend/screens/home_screen.dart';

void main() {
  testWidgets('HomeScreen basic rendering test', (WidgetTester tester) async {
    final firestore = FakeFirebaseFirestore();

    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(firestore: firestore),
    ));

    await tester.pump(); // wait for streams

    expect(find.text('Campaigns'), findsOneWidget);
    expect(find.text('現在地周辺のみ表示'), findsOneWidget);
    expect(find.byIcon(Icons.bug_report), findsNothing); // Ensure icon is removed from AppBar
  });

  testWidgets('Drawer opens and contains debug options', (WidgetTester tester) async {
    final firestore = FakeFirebaseFirestore();

    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(firestore: firestore),
    ));

    await tester.pump();

    // Open drawer
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(find.text('手動スクレイピング'), findsOneWidget);
    expect(find.text('自動スクレイピング'), findsOneWidget);

    // Test Manual Scraping Dialog
    await tester.tap(find.text('手動スクレイピング'));
    await tester.pumpAndSettle();

    expect(find.text('本当に実行しますか？'), findsOneWidget);

    // Tap Cancel
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();

    expect(find.text('本当に実行しますか？'), findsNothing);
  });

  testWidgets('Auto Scraping switch updates Firestore', (WidgetTester tester) async {
    final firestore = FakeFirebaseFirestore();

    // Initial state is default true
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: HomeScreen(firestore: firestore)),
    ));
    await tester.pump();

    // Open drawer
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    final switchFinder = find.byType(Switch);
    // Note: There might be multiple switches now (location filter & auto scraping).
    // The auto scraping one is in the SwitchListTile
    final autoScrapingSwitchFinder = find.descendant(
      of: find.byType(SwitchListTile),
      matching: find.byType(Switch),
    );

    expect(autoScrapingSwitchFinder, findsOneWidget);
    Switch switchWidget = tester.widget(autoScrapingSwitchFinder);
    expect(switchWidget.value, true);

    // Tap switch to turn it off
    await tester.tap(autoScrapingSwitchFinder);
    await tester.pumpAndSettle();

    // Verify Firestore was updated
    final docSnapshot = await firestore.collection('settings').doc('config').get();
    expect(docSnapshot.exists, true);
    expect(docSnapshot.data()?['isAutoScrapingEnabled'], false);
  });
}
