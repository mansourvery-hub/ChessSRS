// Copyright (C) 2024 ChessSRS contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:chess_srs/src/domain/domain.dart';
import 'package:chess_srs/src/review/review_controller.dart';
import 'package:chess_srs/src/styles/styles.dart';
import 'package:chess_srs/src/view/review/repertoire_import_dialog.dart';
import 'package:chess_srs/src/view/review/review_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// Drawer allowing the user to select the review scope (all studies vs one study)
/// or trigger a new PGN import.
class ReviewScopeDrawer extends ConsumerWidget {
  const ReviewScopeDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewStateAsync = ref.watch(reviewControllerProvider);
    final reviewState = reviewStateAsync.asData?.value;

    if (reviewState == null) {
      return const Drawer(child: Center(child: CircularProgressIndicator()));
    }

    final isAllSelected = reviewState.scope.studyId == null;

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
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
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ListTile(
                    leading: const Icon(Symbols.all_inclusive_rounded),
                    title: const Text('All Studies', style: Styles.subtitle),
                    selected: isAllSelected,
                    trailing: _DueChip(count: reviewState.totalDueCount),
                    onTap: () {
                      Navigator.of(context).pop();
                      ref
                          .read(reviewControllerProvider.notifier)
                          .changeScope(const ReviewScope.all());
                    },
                  ),
                  if (reviewState.studies.isNotEmpty) const Divider(),
                  for (final study in reviewState.studies)
                    ListTile(
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
                      selected: reviewState.scope.studyId == study.id,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _DueChip(count: reviewState.studyDueCounts[study.id] ?? 0),
                          const SizedBox(width: 4.0),
                          IconButton(
                            icon: const Icon(Symbols.explore_rounded, size: 20),
                            tooltip: 'Explore moves',
                            onPressed: () {
                              Navigator.of(context).pop();
                              openStudyExplorer(context, ref, studyId: study.id);
                            },
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.of(context).pop();
                        ref
                            .read(reviewControllerProvider.notifier)
                            .changeScope(ReviewScope.study(study.id));
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
