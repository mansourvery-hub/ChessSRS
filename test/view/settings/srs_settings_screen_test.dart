// Copyright (C) 2024 ChessSRS contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:chess_srs/src/view/settings/srs_settings_screen.dart';
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

  testWidgets('SrsSettingsScreen renders all unified sections and toggles settings', (
    tester,
  ) async {
    final app = await makeTestProviderScopeApp(tester, home: const SrsSettingsScreen());

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    // Verify section titles
    expect(find.text('Algorithm & Intervals'), findsOneWidget);
    expect(find.text('Review Experience'), findsOneWidget);

    // Verify review switches are present
    expect(find.text('Animate opponent moves'), findsOneWidget);
    expect(find.text('Show move notes & comments'), findsOneWidget);

    // Scroll to Diagnostics
    await tester.scrollUntilVisible(find.text('Diagnostics'), 100);
    await tester.pumpAndSettle();
    expect(find.text('Diagnostics'), findsOneWidget);
    expect(find.text('Developer / SRS diagnostics'), findsOneWidget);

    // Scroll back to top
    await tester.scrollUntilVisible(find.text('Algorithm & Intervals'), -100);
    await tester.pumpAndSettle();

    // Switch to ChessFSRS algorithm
    await tester.tap(find.text('SRS scheduling algorithm'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ChessFSRS (DSR Power-Law)'));
    await tester.pumpAndSettle();

    // Verify FSRS options and preview appear
    expect(find.text('Target recall retention'), findsOneWidget);
    expect(find.text('88%'), findsOneWidget);
    expect(find.text('FSRS interval progression preview'), findsOneWidget);

    // Switch retention to 95% (Tournament mode)
    await tester.tap(find.text('Target recall retention'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('95% (Tournament mode)'));
    await tester.pumpAndSettle();

    expect(find.text('95%'), findsOneWidget);

    // Toggle diagnostics
    await tester.scrollUntilVisible(find.text('Developer / SRS diagnostics'), 100);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Developer / SRS diagnostics'));
    await tester.pumpAndSettle();

    // Toggle comments
    await tester.tap(find.text('Show move notes & comments'));
    await tester.pumpAndSettle();
  });
}
