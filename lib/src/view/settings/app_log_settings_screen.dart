// Copyright (C) 2024 ChessSRS contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:chess_srs/src/model/log/app_log_paginator.dart';
import 'package:chess_srs/src/model/log/app_log_service.dart';
import 'package:chess_srs/src/model/log/app_log_storage.dart';
import 'package:chess_srs/src/model/settings/log_preferences.dart';
import 'package:chess_srs/src/styles/styles.dart';
import 'package:chess_srs/src/utils/navigation.dart';
import 'package:chess_srs/src/utils/share.dart';
import 'package:chess_srs/src/widgets/adaptive_action_sheet.dart';
import 'package:chess_srs/src/widgets/adaptive_choice_picker.dart';
import 'package:chess_srs/src/widgets/feedback.dart';
import 'package:chess_srs/src/widgets/haptic_refresh_indicator.dart';
import 'package:chess_srs/src/widgets/platform.dart';
import 'package:chess_srs/src/widgets/platform_search_bar.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

final Logger _logger = Logger('AppLogSettingsScreen');

final _logDateFormatter = DateFormat.yMd().add_Hms();

enum LogCategory {
  all('All', null),
  review('Review', 'Review'),
  repository('Repo / DB', 'StudyRepository'),
  importer('Import', 'StudyImporter'),
  network('Network', 'Http'),
  engine('Engine', 'fish');

  const LogCategory(this.label, this.filterKey);
  final String label;
  final String? filterKey;
}

class AppLogSettingsScreen extends ConsumerStatefulWidget {
  const AppLogSettingsScreen({super.key, this.initialCategory = LogCategory.all});

  final LogCategory initialCategory;

  static Route<dynamic> buildRoute({LogCategory initialCategory = LogCategory.all}) {
    return buildScreenRoute(screen: AppLogSettingsScreen(initialCategory: initialCategory));
  }

  @override
  ConsumerState<AppLogSettingsScreen> createState() => _AppLogSettingsScreenState();
}

class _AppLogSettingsScreenState extends ConsumerState<AppLogSettingsScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String? _searchQuery;
  late LogCategory _selectedCategory;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String? get _effectiveSearchQuery {
    if (_searchQuery != null && _searchQuery!.isNotEmpty) {
      return _searchQuery;
    }
    return _selectedCategory.filterKey;
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      final currentState = ref.read(appLogPaginatorProvider(_effectiveSearchQuery));
      if (currentState.hasValue && !currentState.isLoading && currentState.requireValue.hasMore) {
        ref.read(appLogPaginatorProvider(_effectiveSearchQuery).notifier).next();
      }
    }
  }

  Future<void> _onRefresh() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return await ref.read(appLogPaginatorProvider(_effectiveSearchQuery).notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final currentLevel = ref.watch(logPreferencesProvider.select((prefs) => prefs.level));
    final asyncState = ref.watch(appLogPaginatorProvider(_effectiveSearchQuery));
    final logs = asyncState.value?.logs ?? [];

    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: const Text('App Logs'),
        actions: [
          if (logs.isNotEmpty)
            IconButton(
              tooltip: 'Export',
              icon: const Icon(Icons.share),
              onPressed: () => launchShareDialog(
                context,
                ShareParams(text: logs.map(_formatLogEntry).join('\n\n---\n\n')),
              ),
            ),
          if (asyncState.value?.isDeleteButtonVisible == true)
            IconButton(
              tooltip: 'Delete all logs',
              icon: const Icon(Icons.delete_sweep),
              onPressed: () {
                showConfirmDialog<dynamic>(
                  context,
                  title: const Text('Delete all logs'),
                  onConfirm: () {
                    ref.read(appLogServiceProvider).clear();
                    ref.read(appLogPaginatorProvider(_effectiveSearchQuery).notifier).deleteAll();
                  },
                );
              },
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(104.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: PlatformSearchBar(
                        controller: _searchController,
                        hintText: 'Search logs...',
                        onChanged: (value) => setState(() {
                          _searchQuery = value.isEmpty ? null : value;
                        }),
                        onClear: () => setState(() {
                          _searchQuery = null;
                          _searchController.clear();
                        }),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        showChoicePicker<Level>(
                          context,
                          choices: kLogPreferencesAvailableLevels,
                          selectedItem: currentLevel,
                          labelBuilder: (Level l) => Text(l.name),
                          onSelectedItemChanged: (Level value) {
                            _logger.fine('Changing log level to ${value.name}');
                            ref.read(logPreferencesProvider.notifier).setLogLevel(value);
                          },
                        );
                      },
                      child: Text(currentLevel.name),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 32,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: LogCategory.values.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (context, index) {
                      final category = LogCategory.values[index];
                      final isSelected = _selectedCategory == category;
                      return ChoiceChip(
                        label: Text(
                          category.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (_) {
                          setState(() {
                            _selectedCategory = category;
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: switch (asyncState) {
        AsyncData(:final value) when value.logs.isEmpty => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No logs to show'),
              TextButton(onPressed: _onRefresh, child: const Text('Tap to refresh')),
            ],
          ),
        ),
        AsyncData(:final value) => HapticRefreshIndicator(
          onRefresh: _onRefresh,
          child: ListView.separated(
            controller: _scrollController,
            itemCount: value.logs.length,
            separatorBuilder: (_, _) => const Divider(height: 1, thickness: 0),
            itemBuilder: (_, index) => _LogTile(entry: value.logs[index]),
          ),
        ),
        AsyncError(:final error) => Center(
          child: Padding(
            padding: Styles.bodySectionPadding,
            child: Text('Failed to load logs: $error'),
          ),
        ),
        _ => const Center(child: CircularProgressIndicator.adaptive()),
      },
    );
  }
}

String _formatLogEntry(AppLogEntry entry) {
  final buffer = StringBuffer(
    '[${_logDateFormatter.format(entry.logTime)}] [${entry.loggerName}] [${entry.levelName}] ${entry.message}',
  );
  final error = entry.error;
  final stackTrace = entry.stackTrace;
  if (error != null) {
    buffer.write('\nError: $error');
  }
  if (stackTrace != null) {
    buffer.write('\nStack trace:\n$stackTrace');
  }
  return buffer.toString();
}

Color _loggerBadgeColor(String loggerName) {
  if (loggerName.contains('Review') || loggerName.contains('Fsrs')) {
    return Colors.blue;
  }
  if (loggerName.contains('Repository') || loggerName.contains('Database')) {
    return Colors.purple;
  }
  if (loggerName.contains('Import')) {
    return Colors.teal;
  }
  if (loggerName.contains('Http') || loggerName.contains('Socket')) {
    return Colors.orange;
  }
  if (loggerName.contains('Engine') ||
      loggerName.contains('Stockfish') ||
      loggerName.contains('Lc0')) {
    return Colors.indigo;
  }
  return Colors.blueGrey;
}

class _LogTile extends StatelessWidget {
  const _LogTile({required this.entry});

  final AppLogEntry entry;

  @override
  Widget build(BuildContext context) {
    const titleStyle = TextStyle(fontSize: 13, letterSpacing: -0.15);
    final subtitleStyle = TextStyle(color: textShade(context, 0.7), fontSize: 11);

    final isSevere = entry.levelValue >= Level.SEVERE.value;
    final isWarning = entry.levelValue >= Level.WARNING.value;

    final (levelIcon, levelColor) = isSevere
        ? (Icons.error_outline, Colors.red)
        : isWarning
        ? (Icons.warning_amber_outlined, Colors.orange)
        : (Icons.info_outline, textShade(context, 0.7));

    final badgeColor = _loggerBadgeColor(entry.loggerName);

    return ListTile(
      dense: true,
      onTap: () => _showLogDetails(context, entry),
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: _formatLogEntry(entry)));
        showSnackBar(context, 'Log entry copied to clipboard');
      },
      leading: Icon(levelIcon, size: 20, color: levelColor, semanticLabel: entry.levelName),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              entry.loggerName,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeColor),
            ),
          ),
          Expanded(
            child: Text(
              entry.message,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: titleStyle,
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 2),
          Text(_logDateFormatter.format(entry.logTime), style: subtitleStyle),
          if (entry.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: Text(
                entry.error!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.red, fontSize: 11),
              ),
            ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right, size: 16),
    );
  }
}

void _showLogDetails(BuildContext context, AppLogEntry entry) {
  final isSevere = entry.levelValue >= Level.SEVERE.value;
  final isWarning = entry.levelValue >= Level.WARNING.value;
  final levelColor = isSevere
      ? Colors.red
      : isWarning
      ? Colors.orange
      : Colors.blueGrey;

  final badgeColor = _loggerBadgeColor(entry.loggerName);

  showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: levelColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                entry.levelName,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: levelColor),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                entry.loggerName,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: badgeColor),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _logDateFormatter.format(entry.logTime),
                style: TextStyle(color: textShade(context, 0.7), fontSize: 11),
              ),
              const SizedBox(height: 10),
              const Text('Message', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 4),
              SelectableText(entry.message, style: const TextStyle(fontSize: 13)),
              if (entry.error != null) ...[
                const SizedBox(height: 12),
                const Text(
                  'Error',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.red),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: SelectableText(
                    entry.error!,
                    style: const TextStyle(fontSize: 12, color: Colors.red),
                  ),
                ),
              ],
              if (entry.stackTrace != null) ...[
                const SizedBox(height: 12),
                const Text(
                  'Stack Trace',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: SelectableText(
                    entry.stackTrace!,
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: entry.message));
              Navigator.of(dialogContext).pop();
              showSnackBar(context, 'Message copied to clipboard');
            },
            child: const Text('Copy Message'),
          ),
          if (entry.error != null || entry.stackTrace != null)
            TextButton(
              onPressed: () {
                final errText = [entry.error, entry.stackTrace].whereType<String>().join('\n');
                Clipboard.setData(ClipboardData(text: errText));
                Navigator.of(dialogContext).pop();
                showSnackBar(context, 'Error copied to clipboard');
              },
              child: const Text('Copy Error'),
            ),
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _formatLogEntry(entry)));
              Navigator.of(dialogContext).pop();
              showSnackBar(context, 'Full log entry copied');
            },
            child: const Text('Copy All'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}
