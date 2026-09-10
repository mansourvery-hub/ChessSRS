import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chess_repertoire_srs/main.dart';

void main() {
  testWidgets('App renders Review UI smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ChessRepertoireApp());

    // Just verify the widget tree builds without crashing
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}