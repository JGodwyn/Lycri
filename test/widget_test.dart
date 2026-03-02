import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lycri_lyrics/app.dart';

void main() {
  testWidgets('App renders without errors', (WidgetTester tester) async {
    await tester.pumpWidget(const LycriApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
