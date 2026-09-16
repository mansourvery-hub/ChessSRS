// Copyright (C) 2024 ChessSRS contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:chess_srs/src/domain/chapter.dart';
import 'package:chess_srs/src/domain/clock.dart';
import 'package:chess_srs/src/domain/repertoire_decision.dart';
import 'package:chess_srs/src/domain/review/review_scope.dart';
import 'package:chess_srs/src/domain/review/review_session.dart';
import 'package:chess_srs/src/domain/review_state.dart';
import 'package:chess_srs/src/domain/scheduler.dart';
import 'package:chess_srs/src/domain/study.dart';

/// Factory and configuration engine for [ReviewSession]s.
class ReviewEngine {
  const ReviewEngine({this.scheduler = const SimpleScheduler(), this.clock = const SystemClock()});

  final Scheduler scheduler;
  final Clock clock;

  ReviewSession createSession({
    required List<Study> studies,
    required List<Chapter> chapters,
    required List<RepertoireDecision> decisions,
    required Map<String, ReviewState> reviewStates,
    ReviewScope scope = const ReviewScope.all(),
  }) {
    return ReviewSession(
      studies: studies,
      chapters: chapters,
      decisions: decisions,
      reviewStates: reviewStates,
      scope: scope,
      scheduler: scheduler,
      clock: clock,
    );
  }
}
