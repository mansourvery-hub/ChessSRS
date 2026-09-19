// Copyright (C) 2024 ChessSRS contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:chess_srs/src/domain/domain.dart';
import 'package:chess_srs/src/import/pgn_exporter.dart';
import 'package:chess_srs/src/model/analysis/analysis_controller.dart';
import 'package:chess_srs/src/model/common/chess.dart';
import 'package:chess_srs/src/model/common/id.dart';
import 'package:chess_srs/src/persistence/study_repository.dart';
import 'package:chess_srs/src/review/review_controller.dart';
import 'package:chess_srs/src/styles/styles.dart';
import 'package:chess_srs/src/utils/navigation.dart';
import 'package:chess_srs/src/view/analysis/analysis_screen.dart';
import 'package:chess_srs/src/widgets/feedback.dart';
import 'package:chess_srs/src/widgets/misc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// Opens the study in analysis/explore mode.
///
/// If the study has a single chapter, navigates directly to [AnalysisScreen].
/// If the study has multiple chapters, opens [StudyChaptersScreen] so the user
/// can choose which chapter to explore.
Future<void> openStudyExplorer(BuildContext context, WidgetRef ref, {String? studyId}) async {
  final reviewState = ref.read(reviewControllerProvider).value;
  if (reviewState == null) return;

  final targetId = studyId ?? reviewState.scope.studyId ?? reviewState.studies.firstOrNull?.id;
  if (targetId == null) {
    showSnackBar(context, 'No studies available to explore', type: SnackBarType.info);
    return;
  }

  final repo = await ref.read(srsStudyRepositoryProvider.future);
  final study = await repo.getStudy(targetId);
  if (study == null) {
    if (context.mounted) {
      showSnackBar(context, 'Study not found', type: SnackBarType.error);
    }
    return;
  }

  final chapters = await repo.getChaptersByStudy(targetId);
  if (chapters.isEmpty) {
    if (context.mounted) {
      showSnackBar(context, 'Study has no chapters to explore', type: SnackBarType.info);
    }
    return;
  }

  if (!context.mounted) return;

  if (chapters.length == 1) {
    await openChapterAnalysis(context, ref, study: study, chapter: chapters.first);
  } else {
    Navigator.of(
      context,
      rootNavigator: true,
    ).push(StudyChaptersScreen.buildRoute(study: study, chapters: chapters));
  }
}

/// Opens [AnalysisScreen] for a specific chapter within [study].
Future<void> openChapterAnalysis(
  BuildContext context,
  WidgetRef ref, {
  required Study study,
  required Chapter chapter,
}) async {
  Chapter fullChapter = chapter;
  if (fullChapter.root == null) {
    final repo = await ref.read(srsStudyRepositoryProvider.future);
    final root = await repo.getPositionTree(chapter.id);
    fullChapter = chapter.copyWith(root: root);
  }

  final pgn = chapterToPgn(fullChapter, studyTitle: study.title);
  if (pgn.trim().isEmpty) {
    if (context.mounted) {
      showSnackBar(context, 'Chapter has no moves to explore', type: SnackBarType.info);
    }
    return;
  }

  if (!context.mounted) return;

  Navigator.of(context, rootNavigator: true).push(
    AnalysisScreen.buildRoute(
      AnalysisOptions.pgn(
        id: StringId('study_${study.id}_${chapter.id}'),
        orientation: chapter.orientation,
        pgn: pgn,
        isComputerAnalysisAllowed: true,
        variant: Variant.standard,
      ),
    ),
  );
}

/// Screen displaying the chapters of a study for interactive analysis.
class StudyChaptersScreen extends ConsumerWidget {
  const StudyChaptersScreen({required this.study, required this.chapters, super.key});

  final Study study;
  final List<Chapter> chapters;

  static Route<dynamic> buildRoute({required Study study, required List<Chapter> chapters}) {
    return buildScreenRoute(
      screen: StudyChaptersScreen(study: study, chapters: chapters),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppBarTitleText(study.title),
            Text(
              '${chapters.length} chapters',
              style: TextStyle(fontSize: 12.0, color: textShade(context, Styles.subtitleOpacity)),
            ),
          ],
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        itemCount: chapters.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final chapter = chapters[index];
          final chapterTitle = chapter.title?.trim().isNotEmpty == true
              ? chapter.title!.trim()
              : 'Chapter ${index + 1}';
          final reviewState = ref.watch(reviewControllerProvider).value;
          final progress = reviewState?.chapterProgress[chapter.id];
          final hasOpening = chapter.opening != null && chapter.opening!.trim().isNotEmpty;
          final hasProgress = progress != null && progress.totalDecisions > 0;

          return ListTile(
            leading: CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            title: Text(chapterTitle, style: Styles.subtitle),
            subtitle: hasOpening || hasProgress
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasOpening)
                        Text(
                          chapter.opening!.trim(),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 12.0,
                          ),
                        ),
                      if (hasProgress)
                        Text(
                          '${progress.learnedDecisions}/${progress.totalDecisions} learned (${progress.progressPercentage}%)'
                          '${progress.dueDecisions > 0 ? " • ${progress.dueDecisions} due" : ""}',
                          style: TextStyle(
                            fontSize: 11.0,
                            color: textShade(context, Styles.subtitleOpacity),
                          ),
                        ),
                    ],
                  )
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Symbols.explore_rounded),
                  tooltip: 'Analyze chapter',
                  onPressed: () =>
                      openChapterAnalysis(context, ref, study: study, chapter: chapter),
                ),
                IconButton(
                  icon: const Icon(Symbols.fitness_center_rounded),
                  tooltip: 'Practice chapter',
                  onPressed: () {
                    ref
                        .read(reviewControllerProvider.notifier)
                        .startPracticeMode(
                          scope: ReviewScope.chapter(studyId: study.id, chapterId: chapter.id),
                        );
                    Navigator.of(context).pop();
                  },
                ),
                const Icon(Symbols.chevron_right_rounded),
              ],
            ),
            onTap: () {
              ref
                  .read(reviewControllerProvider.notifier)
                  .changeScope(ReviewScope.chapter(studyId: study.id, chapterId: chapter.id));
              Navigator.of(context).pop();
            },
          );
        },
      ),
    );
  }
}
