import 'package:flutter_test/flutter_test.dart';
import 'package:chess_repertoire_srs/main.dart';

void main() {
  testWidgets('App renders Review UI smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ChessRepertoireApp());
    await tester.pumpAndSettle();

    expect(find.byType(ChessRepertoireApp), findsOneWidget);
    expect(find.text('Chess Repertoire Review'), findsOneWidget);
  });
}
