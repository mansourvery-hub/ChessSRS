// Copyright (C) 2024 ChessSRS contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:chess_srs/src/domain/domain.dart';
import 'package:chess_srs/src/persistence/persistence.dart';
import 'package:chess_srs/src/review/review_controller.dart';
import 'package:chess_srs/src/styles/lichess_colors.dart';
import 'package:chess_srs/src/styles/styles.dart';
import 'package:chess_srs/src/view/review/repertoire_import_dialog.dart';
import 'package:chess_srs/src/view/review/review_screen.dart';
import 'package:chess_srs/src/widgets/feedback.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// Drawer allowing the user to select the review scope (all studies vs one study)
/// or trigger a new PGN import.
class ReviewScopeDrawer extends ConsumerStatefulWidget {
  const ReviewScopeDrawer({super.key});

  @override
  ConsumerState<ReviewScopeDrawer> createState() => _ReviewScopeDrawerState();
}

class _ReviewScopeDrawerState extends ConsumerState<ReviewScopeDrawer> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reviewStateAsync = ref.watch(reviewControllerProvider);
    final reviewState = reviewStateAsync.value;

    if (reviewState == null) {
      return const Drawer(child: Center(child: CircularProgressIndicator()));
    }

    final isAllSelected =
        reviewState.scope.studyId == null && reviewState.scope.openingFamily == null;

    final query = _searchQuery.trim().toLowerCase();
    final showAllStudies = query.isEmpty || 'all studies'.contains(query);

    final filteredOpeningHubs = query.isEmpty
        ? reviewState.openingDueCounts.entries.toList()
        : reviewState.openingDueCounts.entries
              .where((entry) => entry.key.toLowerCase().contains(query))
              .toList();

    final filteredStudies = query.isEmpty
        ? reviewState.studies
        : reviewState.studies.where((study) => study.title.toLowerCase().contains(query)).toList();

    final hasNoResults =
        query.isNotEmpty &&
        !showAllStudies &&
        filteredOpeningHubs.isEmpty &&
        filteredStudies.isEmpty;

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
              child: Row(
                children: [
                  Icon(
                    Symbols.menu_book_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 12.0),
                  const Text('Repertoires', style: Styles.title),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search repertoires & hubs...',
                  prefixIcon: const Icon(Symbols.search_rounded, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Symbols.close_rounded, size: 18),
                          tooltip: 'Clear search',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                ),
                onChanged: (value) => setState(() => _searchQuery = value.trim()),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: hasNoResults
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Symbols.search_off_rounded,
                              size: 40,
                              color: Theme.of(context).disabledColor,
                            ),
                            const SizedBox(height: 8.0),
                            Text(
                              'No repertoires matching "$_searchQuery"',
                              style: Styles.subtitle,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        if (showAllStudies)
                          ListTile(
                            leading: const Icon(Symbols.all_inclusive_rounded),
                            title: const Text('All Studies', style: Styles.subtitle),
                            subtitle: reviewState.totalProgress.totalDecisions > 0
                                ? Text(
                                    '${reviewState.totalProgress.learnedDecisions}/${reviewState.totalProgress.totalDecisions} learned (${reviewState.totalProgress.progressPercentage}%)',
                                    style: TextStyle(
                                      fontSize: 12.0,
                                      color: textShade(context, Styles.subtitleOpacity),
                                    ),
                                  )
                                : null,
                            selected: isAllSelected,
                            trailing: _DueChip(count: reviewState.totalDueCount),
                            onTap: () {
                              Navigator.of(context).pop();
                              ref
                                  .read(reviewControllerProvider.notifier)
                                  .changeScope(const ReviewScope.all());
                            },
                          ),
                        if (filteredOpeningHubs.isNotEmpty) ...[
                          const Divider(),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            child: Text('Opening Hubs', style: Styles.sectionTitle),
                          ),
                          for (final entry in filteredOpeningHubs)
                            ListTile(
                              leading: const Icon(Symbols.hub_rounded),
                              title: Text(entry.key, maxLines: 1, overflow: TextOverflow.ellipsis),
                              selected: reviewState.scope.openingFamily == entry.key,
                              trailing: _DueChip(count: entry.value),
                              onTap: () {
                                Navigator.of(context).pop();
                                ref
                                    .read(reviewControllerProvider.notifier)
                                    .changeScope(ReviewScope.opening(entry.key));
                              },
                            ),
                        ],
                        if (filteredStudies.isNotEmpty) ...[
                          const Divider(),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            child: Text('Repertoires', style: Styles.sectionTitle),
                          ),
                        ],
                        for (final study in filteredStudies)
                          Builder(
                            builder: (context) {
                              final progress = reviewState.studyProgress[study.id];
                              return ListTile(
                                leading: IconButton(
                                  icon: Icon(
                                    study.isActive
                                        ? Symbols.check_circle_rounded
                                        : Symbols.pause_circle_outline_rounded,
                                    color: study.isActive
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).disabledColor,
                                    size: 22,
                                  ),
                                  tooltip: study.isActive
                                      ? 'Active in review pool (tap to suspend)'
                                      : 'Suspended from review pool (tap to activate)',
                                  onPressed: () {
                                    ref
                                        .read(reviewControllerProvider.notifier)
                                        .toggleStudyActive(study.id, !study.isActive);
                                  },
                                ),
                                title: Text(
                                  study.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: study.isActive
                                      ? null
                                      : TextStyle(color: Theme.of(context).disabledColor),
                                ),
                                subtitle: progress != null && progress.totalDecisions > 0
                                    ? Text(
                                        '${progress.learnedDecisions}/${progress.totalDecisions} learned (${progress.progressPercentage}%)',
                                        style: TextStyle(
                                          fontSize: 12.0,
                                          color: textShade(context, Styles.subtitleOpacity),
                                        ),
                                      )
                                    : null,
                                selected: reviewState.scope.studyId == study.id,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _DueChip(count: reviewState.studyDueCounts[study.id] ?? 0),
                                    IconButton(
                                      icon: const Icon(Symbols.more_vert_rounded),
                                      tooltip: 'Study options',
                                      onPressed: () => _showStudyActionsSheet(context, ref, study),
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  Navigator.of(context).pop();
                                  ref
                                      .read(reviewControllerProvider.notifier)
                                      .changeScope(ReviewScope.study(study.id));
                                },
                              );
                            },
                          ),
                      ],
                    ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: FilledButton.tonalIcon(
                icon: const Icon(Symbols.upload_file_rounded),
                label: const Text('Import PGN'),
                onPressed: () {
                  Navigator.of(context).pop();
                  RepertoireImportDialog.show(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStudyActionsSheet(BuildContext context, WidgetRef ref, Study study) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                study.title,
                style: Styles.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Symbols.view_list_rounded),
              title: const Text('Chapters'),
              subtitle: const Text('View and train specific chapters in this study'),
              onTap: () async {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
                final repo = await ref.read(srsStudyRepositoryProvider.future);
                final chapters = await repo.getChaptersByStudy(study.id);
                if (context.mounted) {
                  Navigator.of(
                    context,
                    rootNavigator: true,
                  ).push(StudyChaptersScreen.buildRoute(study: study, chapters: chapters));
                }
              },
            ),
            ListTile(
              leading: const Icon(Symbols.explore_rounded),
              title: const Text('Analyze Study'),
              subtitle: const Text('Browse moves, variations, and engine evaluation'),
              onTap: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
                openStudyExplorer(context, ref, studyId: study.id);
              },
            ),
            ListTile(
              leading: const Icon(Symbols.fitness_center_rounded),
              title: const Text('Free Practice'),
              subtitle: const Text('Drill lines on the board without altering SRS schedule'),
              onTap: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
                ref
                    .read(reviewControllerProvider.notifier)
                    .startPracticeMode(scope: ReviewScope.study(study.id));
              },
            ),
            ListTile(
              leading: const Icon(Symbols.edit_rounded),
              title: const Text('Rename Study'),
              onTap: () {
                Navigator.of(ctx).pop();
                _showRenameStudyDialog(context, ref, study);
              },
            ),
            ListTile(
              leading: const Icon(Symbols.delete_rounded, color: LichessColors.red),
              title: const Text('Delete Study', style: TextStyle(color: LichessColors.red)),
              onTap: () {
                Navigator.of(ctx).pop();
                _showDeleteStudyDialog(context, ref, study);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameStudyDialog(BuildContext context, WidgetRef ref, Study study) {
    final textController = TextEditingController(text: study.title);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Study'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Study title', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final newTitle = textController.text.trim();
              if (newTitle.isNotEmpty) {
                ref.read(reviewControllerProvider.notifier).renameStudy(study.id, newTitle);
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _showDeleteStudyDialog(BuildContext context, WidgetRef ref, Study study) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Study?'),
        content: Text(
          'Are you sure you want to delete "${study.title}" and all its recall history? This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: LichessColors.red),
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
              ref.read(reviewControllerProvider.notifier).deleteStudy(study.id);
              showSnackBar(context, 'Deleted "${study.title}"');
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _DueChip extends StatelessWidget {
  const _DueChip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final isDue = count > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
      decoration: BoxDecoration(
        color: isDue
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Text(
        '$count due',
        style: TextStyle(
          fontSize: 12.0,
          fontWeight: FontWeight.w600,
          color: isDue
              ? Theme.of(context).colorScheme.onPrimaryContainer
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
