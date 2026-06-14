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
  });

  testWidgets('HomeScreen opens UrlManagerDialog from drawer', (WidgetTester tester) async {
    final firestore = FakeFirebaseFirestore();

    // Add some initial config to firestore
    await firestore.collection('settings').doc('config').set({
      'targetUrls': ['https://example.com/test'],
    });

    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(firestore: firestore),
    ));

    await tester.pump(); // wait for streams

    // Open drawer
    ScaffoldState state = tester.firstState(find.byType(Scaffold));
    state.openDrawer();
    await tester.pumpAndSettle();

    // Tap on 情報取得先URL
    await tester.tap(find.text('情報取得先URL'));
    await tester.pumpAndSettle(); // wait for dialog

    // Dialog should open
    expect(find.text('情報取得先URL'), findsWidgets); // One in drawer, one in dialog title
    expect(find.text('https://example.com/test'), findsOneWidget);
  });

  testWidgets('HomeScreen opens DebugLogScreen from drawer', (WidgetTester tester) async {
    final firestore = FakeFirebaseFirestore();

    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(firestore: firestore),
    ));

    await tester.pump(); // wait for streams

    // Open drawer
    ScaffoldState state = tester.firstState(find.byType(Scaffold));
    state.openDrawer();
    await tester.pumpAndSettle();

    // Tap on デバッグログ
    await tester.tap(find.text('デバッグログ'));
    await tester.pumpAndSettle(); // wait for navigation

    // Should see DebugLogScreen with 'デバッグログ' in AppBar
    expect(find.text('デバッグログ'), findsWidgets); // One in drawer, one in app bar
    expect(find.text('ログはありません'), findsOneWidget); // Empty logs initially
  });
}
