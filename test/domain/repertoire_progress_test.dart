// Copyright (C) 2024 ChessSRS contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:chess_srs/src/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RepertoireProgress', () {
    test('computes correct fractions and percentages', () {
      const p1 = RepertoireProgress(totalDecisions: 10, learnedDecisions: 7, dueDecisions: 3);

      expect(p1.totalDecisions, 10);
      expect(p1.learnedDecisions, 7);
      expect(p1.dueDecisions, 3);
      expect(p1.unlearnedDecisions, 3);
      expect(p1.progressFraction, 0.7);
      expect(p1.progressPercentage, 70);
    });

    test('handles zero decisions safely without division by zero', () {
      const pZero = RepertoireProgress.zero;

      expect(pZero.totalDecisions, 0);
      expect(pZero.learnedDecisions, 0);
      expect(pZero.dueDecisions, 0);
      expect(pZero.unlearnedDecisions, 0);
      expect(pZero.progressFraction, 0.0);
      expect(pZero.progressPercentage, 0);
    });

    test('operator + aggregates multiple progress records', () {
      const ch1 = RepertoireProgress(totalDecisions: 8, learnedDecisions: 4, dueDecisions: 2);
      const ch2 = RepertoireProgress(totalDecisions: 12, learnedDecisions: 6, dueDecisions: 3);

      final combined = ch1 + ch2;
      expect(combined.totalDecisions, 20);
      expect(combined.learnedDecisions, 10);
      expect(combined.dueDecisions, 5);
      expect(combined.progressPercentage, 50);
    });

    test('equality and hashCode', () {
      const a = RepertoireProgress(totalDecisions: 5, learnedDecisions: 2, dueDecisions: 1);
      const b = RepertoireProgress(totalDecisions: 5, learnedDecisions: 2, dueDecisions: 1);
      const c = RepertoireProgress(totalDecisions: 5, learnedDecisions: 3, dueDecisions: 1);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });
}
