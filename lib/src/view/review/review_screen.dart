// Copyright (C) 2024 ChessSRS contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:chess_srs/src/domain/domain.dart';
import 'package:chess_srs/src/model/common/chess.dart';
import 'package:chess_srs/src/model/game/game_board_params.dart';
import 'package:chess_srs/src/model/settings/board_preferences.dart';
import 'package:chess_srs/src/model/study/study_preferences.dart';
import 'package:chess_srs/src/review/review_controller.dart';
import 'package:chess_srs/src/styles/lichess_colors.dart';
import 'package:chess_srs/src/styles/styles.dart';
import 'package:chess_srs/src/view/review/repertoire_import_dialog.dart';
import 'package:chess_srs/src/view/review/review_scope_drawer.dart';
import 'package:chess_srs/src/widgets/feedback.dart';
import 'package:chess_srs/src/widgets/game_layout.dart';
import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

export 'package:chess_srs/src/view/review/study_chapters_screen.dart';

/// Board-dominant Review screen for active spaced-repetition training.
class ReviewScreen extends ConsumerWidget {
  const ReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewStateAsync = ref.watch(reviewControllerProvider);

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Symbols.menu_rounded),
            tooltip: 'Studies & Scope',
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: reviewStateAsync.maybeWhen(
          data: (state) => _AppBarTitle(state: state),
          orElse: () => const Text('Review'),
        ),
        actions: [
          reviewStateAsync.maybeWhen(
            data: (state) {
              if (state.isPracticeMode) {
                return TextButton.icon(
                  icon: const Icon(Symbols.close_rounded, size: 18),
                  label: const Text('Exit Practice'),
                  onPressed: () => ref.read(reviewControllerProvider.notifier).exitPracticeMode(),
                );
              }
              return const SizedBox.shrink();
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      drawer: const ReviewScopeDrawer(),
      body: reviewStateAsync.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Symbols.error_rounded, size: 48, color: LichessColors.red),
                const SizedBox(height: 16.0),
                Text('Error loading review: $err', textAlign: TextAlign.center),
                const SizedBox(height: 16.0),
                FilledButton(
                  onPressed: () => ref.read(reviewControllerProvider.notifier).reload(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (state) {
          if (!state.hasStudies) {
            return const _FirstLaunchEmptyView();
          }

          if (state.isComplete || state.currentPrompt == null || state.boardPosition == null) {
            return _AllCaughtUpView(state: state);
          }

          return _ActiveReviewView(state: state);
        },
      ),
    );
  }
}

class _AppBarTitle extends StatelessWidget {
  const _AppBarTitle({required this.state});

  final ReviewScreenState state;

  @override
  Widget build(BuildContext context) {
    final String title;
    if (state.scope.openingFamily != null) {
      title = state.scope.openingFamily!;
    } else if (state.scope.studyId != null) {
      final study = state.studies.firstWhere(
        (s) => s.id == state.scope.studyId,
        orElse: () => const Study(id: '', title: 'Study'),
      );
      if (state.scope.chapterId != null && state.currentPrompt?.chapterTitle != null) {
        title = '${study.title} • ${state.currentPrompt!.chapterTitle}';
      } else {
        title = study.title;
      }
    } else {
      title = 'All Studies';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
          ),
        ),
        if (state.isPracticeMode) ...[
          const SizedBox(width: 6.0),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Text(
              'Practice',
              style: TextStyle(
                fontSize: 11.0,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onTertiaryContainer,
              ),
            ),
          ),
        ],
        const SizedBox(width: 8.0),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
          decoration: BoxDecoration(
            color: state.totalDueCount > 0
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10.0),
          ),
          child: Text(
            '${state.totalDueCount}',
            style: TextStyle(
              fontSize: 12.0,
              fontWeight: FontWeight.bold,
              color: state.totalDueCount > 0
                  ? Theme.of(context).colorScheme.onPrimaryContainer
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// First launch view when no studies have been imported yet (PRODUCT.md Journey 2).
class _FirstLaunchEmptyView extends StatelessWidget {
  const _FirstLaunchEmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Symbols.chess_rounded, size: 80, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 20.0),
            const Text('Welcome to ChessSRS', style: Styles.title, textAlign: TextAlign.center),
            const SizedBox(height: 12.0),
            const Text(
              'Memorize and retain your opening repertoire through active spaced repetition.',
              style: Styles.subtitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28.0),
            FilledButton.icon(
              icon: const Icon(Symbols.upload_file_rounded),
              label: const Text('Import Repertoire PGN'),
              onPressed: () => RepertoireImportDialog.show(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// Calm idle view when all items are caught up (PRODUCT.md Journey 1 §6).
class _AllCaughtUpView extends ConsumerWidget {
  const _AllCaughtUpView({required this.state});

  final ReviewScreenState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Symbols.check_circle_rounded, size: 80, color: LichessColors.secondary),
            const SizedBox(height: 20.0),
            const Text('All Caught Up!', style: Styles.title, textAlign: TextAlign.center),
            const SizedBox(height: 12.0),
            const Text(
              '0 positions due for review right now across this repertoire.',
              style: Styles.subtitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28.0),
            Wrap(
              spacing: 12.0,
              runSpacing: 12.0,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  icon: const Icon(Symbols.fitness_center_rounded),
                  label: const Text('Free Practice'),
                  onPressed: () => ref.read(reviewControllerProvider.notifier).startPracticeMode(),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Symbols.menu_book_rounded),
                  label: const Text('Repertoires'),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

extension on PgnCommentShape {
  Shape get chessground {
    final shapeColor = switch (color) {
      CommentShapeColor.green => ShapeColor.green,
      CommentShapeColor.red => ShapeColor.red,
      CommentShapeColor.blue => ShapeColor.blue,
      CommentShapeColor.yellow => ShapeColor.yellow,
    };
    return from != to
        ? Arrow(color: shapeColor.color, orig: from, dest: to)
        : Circle(color: shapeColor.color, orig: from);
  }
}

/// Active review board view driven by GameLayout.
class _ActiveReviewView extends ConsumerWidget {
  const _ActiveReviewView({required this.state});

  final ReviewScreenState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prompt = state.currentPrompt!;
    final boardPosition = state.boardPosition!;
    final isLapse = state.feedback == ReviewFeedback.incorrect;

    final shapes = <Shape>{};
    if (isLapse && state.expectedMove != null) {
      try {
        final orig = Square.fromName(state.expectedMove!.from);
        final dest = Square.fromName(state.expectedMove!.to);
        shapes.add(Arrow(orig: orig, dest: dest, color: Colors.orangeAccent));
      } catch (_) {}
    }

    final showAnnotations = ref.watch(studyPreferencesProvider.select((p) => p.showAnnotations));
    final isAnswerRevealed = isLapse || state.revealedComment != null;
    // Commentary shapes are strictly hidden during active recall (before guess)
    // and only revealed post-guess (on success or lapse) when annotations are enabled.
    if (showAnnotations && isAnswerRevealed) {
      if (prompt.comment != null && prompt.comment!.isNotEmpty) {
        final promptPgn = PgnComment.fromPgn(prompt.comment!);
        for (final pgnShape in promptPgn.shapes) {
          shapes.add(pgnShape.chessground);
        }
      }
      if (state.revealedComment != null && state.revealedComment!.isNotEmpty) {
        final revealedPgn = PgnComment.fromPgn(state.revealedComment!);
        for (final pgnShape in revealedPgn.shapes) {
          shapes.add(pgnShape.chessground);
        }
      }
    }

    final playerSide = state.boardOrientation == Side.white ? PlayerSide.white : PlayerSide.black;

    return GameLayout(
      orientation: state.boardOrientation,
      shapes: shapes.lock,
      boardParams: GameBoardParams.interactive(
        variant: Variant.standard,
        position: boardPosition,
        playerSide: playerSide,
        onMove: (move, {viaDragAndDrop}) {
          ref.read(reviewControllerProvider.notifier).onUserMove(move);
        },
        lastMove: state.lastMove,
      ),
      topTable: _TopReviewInfo(prompt: prompt, orientation: state.boardOrientation),
      bottomTable: _BottomReviewFeedback(
        state: state,
        onContinue: () => ref.read(reviewControllerProvider.notifier).acknowledgeLapse(),
        onSkip: () => ref.read(reviewControllerProvider.notifier).skip(),
      ),
    );
  }
}

class _TopReviewInfo extends StatelessWidget {
  const _TopReviewInfo({required this.prompt, required this.orientation});

  final ReviewPrompt prompt;
  final Side orientation;

  @override
  Widget build(BuildContext context) {
    final title = prompt.chapterTitle ?? prompt.studyTitle ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          SideToPlayPiece(side: orientation),
          const SizedBox(width: 8.0),
          Expanded(
            child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Styles.bold),
          ),
        ],
      ),
    );
  }
}

class _BottomReviewFeedback extends ConsumerWidget {
  const _BottomReviewFeedback({
    required this.state,
    required this.onContinue,
    required this.onSkip,
  });

  final ReviewScreenState state;
  final VoidCallback onContinue;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showComments = ref.watch(studyPreferencesProvider.select((p) => p.showPgnComments));
    final isLapse = state.feedback == ReviewFeedback.incorrect;
    final rawComment = state.revealedComment;
    final comment = showComments && rawComment != null ? PgnComment.fromPgn(rawComment).text : null;

    if (isLapse) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Symbols.info_rounded, color: Theme.of(context).colorScheme.onErrorContainer),
                const SizedBox(width: 8.0),
                Expanded(
                  child: Text(
                    state.expectedMove?.san != null
                        ? 'Repertoire was ${state.expectedMove!.san} — try it on the board!'
                        : 'Not in repertoire — try another move!',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14.0,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Symbols.skip_next_rounded, size: 18),
                  label: const Text('Skip'),
                  onPressed: onContinue,
                ),
              ],
            ),
            if (comment != null && comment.trim().isNotEmpty) ...[
              const SizedBox(height: 6.0),
              Text(
                comment.trim(),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.0,
                  color: Theme.of(context).colorScheme.onErrorContainer.withValues(alpha: 0.9),
                ),
              ),
            ],
          ],
        ),
      );
    }

    // Default quiet idle prompt (no "Good move!" message clutter)
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your move (${state.boardOrientation == Side.white ? 'White' : 'Black'})',
                style: Styles.subtitle,
              ),
              TextButton.icon(
                icon: const Icon(Symbols.skip_next_rounded),
                label: const Text('Skip'),
                onPressed: onSkip,
              ),
            ],
          ),
          if (comment != null && comment.trim().isNotEmpty) ...[
            const SizedBox(height: 4.0),
            Text(
              comment.trim(),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: Styles.formDescription,
            ),
          ],
        ],
      ),
    );
  }
}
