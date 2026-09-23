// Copyright (C) 2024 ChessSRS contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:chess_srs/src/constants.dart';
import 'package:chess_srs/src/model/log/http_log_paginator.dart';
import 'package:chess_srs/src/model/log/http_log_storage.dart';
import 'package:chess_srs/src/styles/styles.dart';
import 'package:chess_srs/src/utils/navigation.dart';
import 'package:chess_srs/src/utils/share.dart';
import 'package:chess_srs/src/widgets/adaptive_action_sheet.dart';
import 'package:chess_srs/src/widgets/feedback.dart';
import 'package:chess_srs/src/widgets/haptic_refresh_indicator.dart';
import 'package:chess_srs/src/widgets/platform.dart';
import 'package:chess_srs/src/widgets/platform_search_bar.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

class HttpLogScreen extends ConsumerStatefulWidget {
  const HttpLogScreen({super.key});

  static Route<dynamic> buildRoute() {
    return buildScreenRoute(screen: const HttpLogScreen());
  }

  @override
  ConsumerState<HttpLogScreen> createState() => _HttpLogScreenState();
}

class _HttpLogScreenState extends ConsumerState<HttpLogScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();
  final TextEditingController _searchController = TextEditingController();
  String? _searchQuery;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      final currentState = ref.read(httpLogPaginatorProvider(_searchQuery));
      if (currentState.hasValue && !currentState.isLoading && currentState.requireValue.hasMore) {
        ref.read(httpLogPaginatorProvider(_searchQuery).notifier).next();
      }
    }
  }

  Future<void> _onRefresh() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return await ref.read(httpLogPaginatorProvider(_searchQuery).notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(httpLogPaginatorProvider(_searchQuery));
    final logs = asyncState.value?.logs.toList() ?? [];

    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: const Text('HTTP logs'),
        actions: [
          if (logs.isNotEmpty)
            IconButton(
              tooltip: 'Export',
              icon: const Icon(Icons.share),
              onPressed: () => launchShareDialog(
                context,
                ShareParams(text: logs.map(_formatHttpLogEntry).join('\n\n---\n\n')),
              ),
            ),
          if (asyncState.value?.isDeleteButtonVisible == true)
            IconButton(
              tooltip: 'Clear all logs',
              icon: const Icon(Icons.delete_sweep),
              onPressed: () {
                showConfirmDialog<dynamic>(
                  context,
                  title: const Text('Delete all logs'),
                  onConfirm: () =>
                      ref.read(httpLogPaginatorProvider(_searchQuery).notifier).deleteAll(),
                );
              },
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
        ),
      ),
      body: _HttpLogList(
        scrollController: _scrollController,
        refreshIndicatorKey: _refreshIndicatorKey,
        logs: logs,
        onRefresh: _onRefresh,
      ),
    );
  }
}

class _HttpLogList extends ConsumerStatefulWidget {
  const _HttpLogList({
    required this.logs,
    required this.onRefresh,
    required this.scrollController,
    required this.refreshIndicatorKey,
  });

  final List<HttpLogEntry> logs;
  final ScrollController scrollController;
  final GlobalKey<RefreshIndicatorState> refreshIndicatorKey;
  final RefreshCallback onRefresh;

  @override
  ConsumerState<_HttpLogList> createState() => _HttpLogListState();
}

class _HttpLogListState extends ConsumerState<_HttpLogList> {
  @override
  Widget build(BuildContext context) {
    if (widget.logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No logs to show'),
            TextButton(onPressed: widget.onRefresh, child: const Text('Tap to refresh')),
          ],
        ),
      );
    }
    return HapticRefreshIndicator(
      key: widget.refreshIndicatorKey,
      onRefresh: widget.onRefresh,
      child: ListView.separated(
        controller: widget.scrollController,
        itemCount: widget.logs.length,
        separatorBuilder: (_, _) => const Divider(height: 1, thickness: 0),
        itemBuilder: (_, index) {
          if (index < 0 || index >= widget.logs.length) {
            return null;
          }

          return HttpLogTile(httpLog: widget.logs[index]);
        },
      ),
    );
  }
}

final _logDateFormatter = DateFormat.yMd().add_Hms();

String _formatElapsed(Duration elapsed) {
  if (elapsed.inMilliseconds < 1000) {
    return '${elapsed.inMilliseconds}ms';
  }
  return '${(elapsed.inMilliseconds / 1000).toStringAsFixed(1)}s';
}

String _formatHttpLogEntry(HttpLogEntry entry) {
  final buffer = StringBuffer(
    '[${_logDateFormatter.format(entry.requestDateTime)}] ${entry.requestMethod} ${entry.requestUrl}\n'
    'Status: ${entry.responseCode ?? "No response"} | Duration: ${entry.elapsed != null ? _formatElapsed(entry.elapsed!) : "N/A"}',
  );
  if (entry.errorMessage != null) {
    buffer.write('\nError: ${entry.errorMessage}');
  }
  return buffer.toString();
}

class HttpLogTile extends StatelessWidget {
  const HttpLogTile({super.key, required this.httpLog});

  final HttpLogEntry httpLog;

  String get endpoint =>
      (httpLog.requestUrl.host == kLichessHost || httpLog.requestUrl.host == 'lichess.org')
      ? Uri(path: httpLog.requestUrl.path, query: httpLog.requestUrl.query).toString()
      : httpLog.requestUrl.toString();

  @override
  Widget build(BuildContext context) {
    final isError =
        httpLog.errorMessage != null ||
        (httpLog.responseCode != null && httpLog.responseCode! >= 400);

    return ListTile(
      dense: true,
      onTap: () => _showHttpLogDetails(context, httpLog),
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: httpLog.requestUrl.toString()));
        showSnackBar(context, 'URL copied to clipboard');
      },
      leading: SizedBox(
        width: 44,
        child: httpLog.hasResponse
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    httpLog.responseCode!.toString(),
                    style: TextStyle(
                      color: isError ? context.lichessColors.error : null,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (httpLog.elapsed != null)
                    Text(
                      _formatElapsed(httpLog.elapsed!),
                      maxLines: 1,
                      style: TextStyle(
                        color: textShade(context, 0.7),
                        fontFeatures: const [FontFeature.tabularFigures()],
                        fontSize: 10,
                      ),
                    ),
                ],
              )
            : Icon(
                isError ? Icons.error_outline : Icons.pending_outlined,
                color: isError ? Colors.red : Colors.grey,
              ),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: isError
                  ? Colors.red.withValues(alpha: 0.15)
                  : Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              httpLog.requestMethod,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isError ? Colors.red : Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              endpoint,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                letterSpacing: -0.15,
                color: isError ? context.lichessColors.error : null,
              ),
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 2),
          Text(
            _logDateFormatter.format(httpLog.requestDateTime),
            style: TextStyle(color: textShade(context, 0.7), fontSize: 11),
          ),
          if (httpLog.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: Text(
                httpLog.errorMessage!,
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

void _showHttpLogDetails(BuildContext context, HttpLogEntry httpLog) {
  final statusText = httpLog.responseCode != null && httpLog.responseCode != 0
      ? '${httpLog.responseCode}'
      : (httpLog.errorMessage != null ? 'Failed' : 'Pending');
  final isError =
      httpLog.errorMessage != null ||
      (httpLog.responseCode != null && httpLog.responseCode! >= 400);

  showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isError
                    ? Colors.red.withValues(alpha: 0.15)
                    : Colors.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                httpLog.requestMethod,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isError ? Colors.red : Colors.green,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              statusText,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isError ? Colors.red : null,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Request URL',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 4),
              SelectableText(httpLog.requestUrl.toString(), style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 12),
              if (httpLog.elapsed != null) ...[
                Row(
                  children: [
                    const Text(
                      'Duration: ',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    Text(_formatElapsed(httpLog.elapsed!), style: const TextStyle(fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  const Text('Time: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  Text(
                    _logDateFormatter.format(httpLog.requestDateTime),
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
              if (httpLog.errorMessage != null) ...[
                const SizedBox(height: 12),
                const Text(
                  'Error Details',
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
                    httpLog.errorMessage!,
                    style: const TextStyle(fontSize: 12, color: Colors.red),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: httpLog.requestUrl.toString()));
              Navigator.of(dialogContext).pop();
              showSnackBar(context, 'URL copied to clipboard');
            },
            child: const Text('Copy URL'),
          ),
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _formatHttpLogEntry(httpLog)));
              Navigator.of(dialogContext).pop();
              showSnackBar(context, 'Details copied to clipboard');
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
