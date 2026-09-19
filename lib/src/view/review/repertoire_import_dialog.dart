// Copyright (C) 2024 ChessSRS contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:io' as io;

import 'package:chess_srs/src/import/lichess_study_importer.dart';
import 'package:chess_srs/src/review/review_controller.dart';
import 'package:chess_srs/src/styles/styles.dart';
import 'package:chess_srs/src/view/more/import_pgn_screen.dart';
import 'package:chess_srs/src/widgets/feedback.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

enum ImportSource { lichess, file }

/// Bottom sheet dialog for importing a repertoire PGN or Lichess study.
class RepertoireImportDialog extends ConsumerStatefulWidget {
  const RepertoireImportDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const RepertoireImportDialog(),
    );
  }

  @override
  ConsumerState<RepertoireImportDialog> createState() => _RepertoireImportDialogState();
}

class _RepertoireImportDialogState extends ConsumerState<RepertoireImportDialog> {
  ImportSource _importSource = ImportSource.lichess;
  final _lichessUrlController = TextEditingController();
  final _pgnController = TextEditingController();
  final _titleController = TextEditingController();
  Side? _repertoireSide;
  bool _isImporting = false;

  @override
  void dispose() {
    _lichessUrlController.dispose();
    _pgnController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickPgnFile() async {
    final picker = ref.read(pickPgnFileProvider);
    final file = await picker();
    if (file != null && file.path != null) {
      final content = await io.File(file.path!).readAsString();
      setState(() {
        _pgnController.text = content;
        if (_titleController.text.isEmpty) {
          _titleController.text = file.name.replaceAll(RegExp(r'\.pgn$', caseSensitive: false), '');
        }
      });
    }
  }

  Future<void> _handleLichessImport() async {
    final input = _lichessUrlController.text.trim();
    if (input.isEmpty) {
      showSnackBar(
        context,
        'Please enter a Lichess study URL or study ID',
        type: SnackBarType.error,
      );
      return;
    }

    final studyId = extractLichessStudyId(input);
    if (studyId == null) {
      showSnackBar(
        context,
        'Invalid Lichess study URL or ID. Example: https://lichess.org/study/xxxxxx',
        type: SnackBarType.error,
      );
      return;
    }

    setState(() => _isImporting = true);
    try {
      final customTitle = _titleController.text.trim();
      final result = await ref
          .read(reviewControllerProvider.notifier)
          .importLichessStudy(
            studyIdOrUrl: input,
            title: customTitle.isNotEmpty ? customTitle : null,
            repertoireSide: _repertoireSide,
          );

      if (mounted) {
        Navigator.of(context).pop();
        if (result.isDuplicate) {
          showSnackBar(
            context,
            'Repertoire "${result.study.title}" is already imported and up to date',
            type: SnackBarType.info,
          );
        } else {
          showSnackBar(
            context,
            'Imported "${result.study.title}" (${result.decisions.length} recall positions across ${result.chapters.length} chapters)',
            type: SnackBarType.success,
          );
        }
      }
    } on FormatException catch (e) {
      if (mounted) {
        showSnackBar(context, e.message, type: SnackBarType.error);
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, 'Lichess import failed: $e', type: SnackBarType.error);
      }
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  Future<void> _handleFileImport() async {
    final pgn = _pgnController.text.trim();
    if (pgn.isEmpty) {
      showSnackBar(context, 'Please enter or select PGN content', type: SnackBarType.error);
      return;
    }

    // Auto-detect Lichess URL entered in PGN text area
    final lichessStudyId = extractLichessStudyId(pgn);
    if (lichessStudyId != null && !pgn.contains('1.')) {
      _lichessUrlController.text = pgn;
      await _handleLichessImport();
      return;
    }

    setState(() => _isImporting = true);
    try {
      final title = _titleController.text.trim().isNotEmpty
          ? _titleController.text.trim()
          : 'Imported Repertoire';

      final result = await ref
          .read(reviewControllerProvider.notifier)
          .importPgnText(pgnText: pgn, title: title, repertoireSide: _repertoireSide);

      if (mounted) {
        Navigator.of(context).pop();
        if (result.isDuplicate) {
          showSnackBar(
            context,
            'Repertoire "${result.study.title}" is already imported and up to date',
            type: SnackBarType.info,
          );
        } else {
          showSnackBar(
            context,
            'Imported "${result.study.title}" (${result.decisions.length} recall positions)',
            type: SnackBarType.success,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, 'Import failed: $e', type: SnackBarType.error);
      }
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0, bottom: bottomInset + 16.0),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Import Repertoire', style: Styles.title),
                IconButton(
                  icon: const Icon(Symbols.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12.0),
            SegmentedButton<ImportSource>(
              segments: const [
                ButtonSegment(
                  value: ImportSource.lichess,
                  icon: Icon(Symbols.link_rounded),
                  label: Text('Lichess Study'),
                ),
                ButtonSegment(
                  value: ImportSource.file,
                  icon: Icon(Symbols.description_rounded),
                  label: Text('PGN Text / File'),
                ),
              ],
              selected: {_importSource},
              onSelectionChanged: (selected) {
                setState(() => _importSource = selected.first);
              },
            ),
            const SizedBox(height: 14.0),
            if (_importSource == ImportSource.lichess) ...[
              TextField(
                controller: _lichessUrlController,
                decoration: InputDecoration(
                  labelText: 'Lichess Study URL or ID',
                  hintText: 'https://lichess.org/study/... or 8-char ID',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Symbols.link_rounded),
                  suffixIcon: IconButton(
                    icon: const Icon(Symbols.content_paste_rounded),
                    tooltip: 'Paste from clipboard',
                    onPressed: () async {
                      final data = await Clipboard.getData(Clipboard.kTextPlain);
                      if (data?.text != null && mounted) {
                        setState(() => _lichessUrlController.text = data!.text!.trim());
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12.0),
              Row(
                children: [
                  const Text('Train as:', style: Styles.subtitle),
                  const SizedBox(width: 12.0),
                  SegmentedButton<Side?>(
                    segments: const [
                      ButtonSegment(value: null, label: Text('Auto')),
                      ButtonSegment(value: Side.white, label: Text('White')),
                      ButtonSegment(value: Side.black, label: Text('Black')),
                    ],
                    selected: {_repertoireSide},
                    onSelectionChanged: (selected) {
                      setState(() => _repertoireSide = selected.first);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12.0),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Study Title (optional)',
                  hintText: 'Derived from Lichess if left blank',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16.0),
              FilledButton.icon(
                icon: _isImporting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Symbols.download_rounded),
                label: Text(
                  _isImporting ? 'Fetching from Lichess...' : 'Fetch & Import from Lichess',
                ),
                onPressed: _isImporting ? null : _handleLichessImport,
              ),
            ] else ...[
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Study Title (optional)',
                  hintText: 'e.g. French Defense / 1.d4 Repertoire',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12.0),
              Row(
                children: [
                  const Text('Train as:', style: Styles.subtitle),
                  const SizedBox(width: 12.0),
                  SegmentedButton<Side?>(
                    segments: const [
                      ButtonSegment(value: null, label: Text('Auto')),
                      ButtonSegment(value: Side.white, label: Text('White')),
                      ButtonSegment(value: Side.black, label: Text('Black')),
                    ],
                    selected: {_repertoireSide},
                    onSelectionChanged: (selected) {
                      setState(() => _repertoireSide = selected.first);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12.0),
              TextField(
                controller: _pgnController,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'PGN text',
                  hintText: 'Paste PGN moves here...',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12.0),
              OutlinedButton.icon(
                icon: const Icon(Symbols.upload_file_rounded),
                label: const Text('Pick .pgn file from disk'),
                onPressed: _isImporting ? null : _pickPgnFile,
              ),
              const SizedBox(height: 16.0),
              FilledButton.icon(
                icon: _isImporting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Symbols.download_done_rounded),
                label: Text(_isImporting ? 'Importing...' : 'Import and Start Review'),
                onPressed: _isImporting ? null : _handleFileImport,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
