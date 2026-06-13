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
}
