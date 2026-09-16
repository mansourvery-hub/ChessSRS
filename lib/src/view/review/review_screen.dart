// Copyright (C) 2024 ChessSRS contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:chess_srs/src/domain/domain.dart';
import 'package:chess_srs/src/model/common/chess.dart';
import 'package:chess_srs/src/model/game/game_board_params.dart';
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
              if (state.hasDuePositions && state.isLapseAcknowledged) {
                return IconButton(
                  icon: const Icon(Symbols.skip_next_rounded),
                  tooltip: 'Skip position',
                  onPressed: () => ref.read(reviewControllerProvider.notifier).skip(),
                );
              }
              return const SizedBox.shrink();
            },
            orElse: () => const SizedBox.shrink(),
          ),
          IconButton(
            icon: const Icon(Symbols.upload_file_rounded),
            tooltip: 'Import PGN',
            onPressed: () => RepertoireImportDialog.show(context),
          ),
        ],
      ),
      drawer: const ReviewScopeDrawer(),
      body: reviewStateAsync.when(
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
    final title = state.scope.studyId != null
        ? state.studies
              .firstWhere(
                (s) => s.id == state.scope.studyId,
                orElse: () => const Study(id: '', title: 'Study'),
              )
              .title
        : 'All Studies';

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
class _AllCaughtUpView extends StatelessWidget {
  const _AllCaughtUpView({required this.state});

  final ReviewScreenState state;

  @override
  Widget build(BuildContext context) {
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
                OutlinedButton.icon(
                  icon: const Icon(Symbols.menu_book_rounded),
                  label: const Text('Change Study'),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
                FilledButton.tonalIcon(
                  icon: const Icon(Symbols.upload_file_rounded),
                  label: const Text('Import Another PGN'),
                  onPressed: () => RepertoireImportDialog.show(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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

    final playerSide = isLapse
        ? PlayerSide.none
        : (state.boardOrientation == Side.white ? PlayerSide.white : PlayerSide.black);

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title.isNotEmpty)
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Styles.bold),
                if (prompt.comment != null && prompt.comment!.isNotEmpty)
                  Text(
                    prompt.comment!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Styles.formDescription,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomReviewFeedback extends StatelessWidget {
  const _BottomReviewFeedback({
    required this.state,
    required this.onContinue,
    required this.onSkip,
  });

  final ReviewScreenState state;
  final VoidCallback onContinue;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final isLapse = state.feedback == ReviewFeedback.incorrect;
    final isCorrect = state.feedback == ReviewFeedback.correct;

    if (isLapse) {
      return Container(
        margin: const EdgeInsets.all(12.0),
        padding: const EdgeInsets.all(12.0),
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
                        ? 'Repertoire move was ${state.expectedMove!.san}'
                        : 'Move not in repertoire',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16.0,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10.0),
            FilledButton(onPressed: onContinue, child: const Text('Continue')),
          ],
        ),
      );
    }

    if (isCorrect) {
      return Container(
        margin: const EdgeInsets.all(12.0),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Row(
          children: [
            const Icon(Symbols.check_circle_rounded, color: LichessColors.secondary),
            const SizedBox(width: 8.0),
            Text(
              'Good move!',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16.0,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
      );
    }

    // Default quiet idle prompt
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
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
    );
  }
}
