// Copyright (C) 2024 ChessSRS contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:chess_srs/src/view/settings/settings_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../binding.dart';
import '../../test_provider_scope.dart';

void main() {
  setUpAll(() {
    TestLichessBinding.ensureInitialized();
  });

  setUp(() async {
    await TestLichessBinding.instance.sharedPreferences.clear();
  });

  testWidgets('SettingsScreen displays and switches SRS scheduling algorithm', (tester) async {
    final app = await makeTestProviderScopeApp(tester, home: const SettingsScreen());

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    // Scroll to SRS scheduling algorithm tile
    await tester.scrollUntilVisible(find.text('SRS scheduling algorithm'), 100);
    await tester.pumpAndSettle();

    // Initial default: Simple Doubling (2x)
    expect(find.text('SRS scheduling algorithm'), findsOneWidget);
    expect(find.text('Simple Doubling (2x)'), findsOneWidget);

    // Ease and scaling tiles are hidden when simple algorithm is selected
    expect(find.text('Initial ease factor'), findsNothing);
    expect(find.text('Growth rate scaling'), findsNothing);

    // Tap to switch scheduler algorithm
    await tester.tap(find.text('SRS scheduling algorithm'));
    await tester.pumpAndSettle();

    // Select Parametric Scaling (chessrs)
    await tester.tap(find.text('Parametric Scaling (chessrs)'));
    await tester.pumpAndSettle();

    // Verify Parametric is now selected
    expect(find.text('Parametric Scaling (chessrs)'), findsOneWidget);

    // Ease factor and growth rate tiles are now visible
    expect(find.text('Initial ease factor'), findsOneWidget);
    expect(find.text('2.5x'), findsOneWidget);
    expect(find.text('Growth rate scaling'), findsOneWidget);
    expect(find.text('1.5x'), findsOneWidget);

    // Progression preview is displayed
    expect(find.text('Interval progression preview'), findsOneWidget);
    expect(find.text('1d → 2.5d → 3.8d → 5.6d → 8.4d'), findsOneWidget);

    // Tap to change initial ease factor
    await tester.tap(find.text('Initial ease factor'));
    await tester.pumpAndSettle();

    // Select 3.0x
    await tester.tap(find.text('3.0x (interval after first success)'));
    await tester.pumpAndSettle();

    expect(find.text('3.0x'), findsOneWidget);
    expect(find.text('1d → 3d → 4.5d → 6.8d → 10.1d'), findsOneWidget);
  });
}
