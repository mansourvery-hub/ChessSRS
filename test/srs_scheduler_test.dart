import 'package:chess_repertoire_srs/domain/srs/review_result.dart';
import 'package:chess_repertoire_srs/domain/srs/review_state.dart';
import 'package:chess_repertoire_srs/domain/srs/simple_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SimpleScheduler', () {
    const scheduler = SimpleScheduler();
    final t0 = DateTime(2026, 9, 10, 10, 0);

    test('initial unreviewed item is due immediately', () {
      final state = ReviewState.initial(itemId: '1', decisionId: 'd1');
      expect(scheduler.isDue(state, t0), isTrue);
    });

    test('first successful recall schedules 1 day later', () {
      final initial = ReviewState.initial(itemId: '1', decisionId: 'd1');
      final next = scheduler.schedule(
        previous: initial,
        result: const ReviewResult.correct(),
        now: t0,
      );

      expect(next.repetitionCount, 1);
      expect(next.lapseCount, 0);
      expect(next.firstReviewedAt, t0);
      expect(next.lastReviewedAt, t0);
      expect(next.nextDueAt, t0.add(const Duration(days: 1)));
      expect(scheduler.isDue(next, t0), isFalse);
      expect(scheduler.isDue(next, t0.add(const Duration(days: 1))), isTrue);
    });

    test('consecutive successful recalls grow intervals exponentially', () {
      var state = ReviewState.initial(itemId: '1', decisionId: 'd1');
      var now = t0;

      // 1st recall
      state = scheduler.schedule(previous: state, result: const ReviewResult.correct(), now: now);
      expect(state.repetitionCount, 1);
      now = state.nextDueAt!;

      // 2nd recall
      state = scheduler.schedule(previous: state, result: const ReviewResult.correct(), now: now);
      expect(state.repetitionCount, 2);
      expect(state.nextDueAt!.difference(now).inDays, greaterThanOrEqualTo(2));
      now = state.nextDueAt!;

      // 3rd recall
      state = scheduler.schedule(previous: state, result: const ReviewResult.correct(), now: now);
      expect(state.repetitionCount, 3);
      expect(state.nextDueAt!.difference(now).inDays, greaterThanOrEqualTo(4));
    });

    test('lapse resets streak and schedules short relearning interval', () {
      final initial = ReviewState.initial(itemId: '1', decisionId: 'd1');
      final learned = scheduler.schedule(
        previous: initial,
        result: const ReviewResult.correct(),
        now: t0,
      );

      final lapsed = scheduler.schedule(
        previous: learned,
        result: const ReviewResult.incorrect(),
        now: t0.add(const Duration(days: 1)),
      );

      expect(lapsed.repetitionCount, 0);
      expect(lapsed.lapseCount, 1);
      expect(lapsed.nextDueAt, isNotNull);
      expect(lapsed.nextDueAt!.isBefore(t0.add(const Duration(days: 2))), isTrue);
    });
  });
}