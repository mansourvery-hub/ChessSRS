import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path_provider/path_provider.dart';
import 'package:chess_repertoire_srs/application/review_service.dart';
import 'package:chess_repertoire_srs/ui/board/piece_images.dart';
import 'package:chess_repertoire_srs/ui/study_tree_sidebar.dart';
import 'package:chess/chess.dart' as chess;
import 'package:chess_repertoire_srs/chess/chess_service.dart';
import 'package:chess_repertoire_srs/chess/pgn_converter.dart';
import 'package:chess_repertoire_srs/domain/clock.dart';
import 'package:chess_repertoire_srs/domain/entities/position_node.dart';
import 'package:chess_repertoire_srs/domain/entities/repertoire_move.dart';
import 'package:chess_repertoire_srs/domain/entities/study.dart';
import 'package:chess_repertoire_srs/domain/repertoire_decision.dart';
import 'package:chess_repertoire_srs/domain/srs/simple_scheduler.dart';
import 'package:chess_repertoire_srs/domain/review_engine.dart';
import 'package:chess_repertoire_srs/import/import_service.dart';
import 'package:chess_repertoire_srs/persistence/in_memory_study_repository.dart';
import 'package:chess_repertoire_srs/persistence/local_study_repository.dart';
import 'package:chess_repertoire_srs/persistence/study_repository.dart';

void main() {
  runApp(const ChessRepertoireApp());
}

class ChessRepertoireApp extends StatefulWidget {
  const ChessRepertoireApp({super.key});

  @override
  State<ChessRepertoireApp> createState() => _ChessRepertoireAppState();
}

class _ChessRepertoireAppState extends State<ChessRepertoireApp> {
  StudyRepository? _repository;
  ReviewService? _reviewService;
  late final ImportService _importService;
  late final ChessService _chessService;
  final Clock _clock = const SystemClock();

  @override
  void initState() {
    super.initState();
    _chessService = const ChessService();
    _importService = ImportService(
      converter: PgnConverter(chess: _chessService),
    );
    // Start async init WITHOUT blocking the first frame
    _initializeStorage();
  }

  Future<void> _initializeStorage() async {
    StudyRepository repo;
    try {
      // On web, skip local file I/O (slow IndexedDB) and use in-memory
      if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
        final docDir = await getApplicationDocumentsDirectory();
        final storageDir = Directory('${docDir.path}/chess_repertoire_srs');
        final localRepo = LocalStudyRepository(storageDirectory: storageDir);
        await localRepo.initialize();
        repo = localRepo;
      } else {
        repo = InMemoryStudyRepository();
      }
    } catch (_) {
      repo = InMemoryStudyRepository();
    }

    final service = ReviewService(
      studyRepository: repo,
      chessService: _chessService,
      scheduler: const SimpleScheduler(),
      clock: _clock,
    );

    // Seed starter repertoire only if empty (non-blocking)
    final existingStudies = await repo.getAllStudies();
    if (existingStudies.isEmpty) {
      await _seedStarterRepertoire(repo);
    }

    if (mounted) {
      setState(() {
        _repository = repo;
        _reviewService = service;
      });
    }
  }

  Future<void> _seedStarterRepertoire(StudyRepository repo) async {
    const defaultPgn = '''
[Event "Italian Game: Main Line"]
[Site "Chess Study"]

1. e4 e5 2. Nf3 Nc6 3. Bc4 Bc5 4. c3 Nf6 5. d3 *

[Event "Sicilian Defense: Open"]
[Site "Chess Study"]

1. e4 c5 2. Nf3 d6 3. d4 cxd4 4. Nxd4 Nf6 5. Nc3 *
''';
    await _importPgnWithRepo(repo, defaultPgn, 'Starter Repertoire');
  }

  Future<void> _importPgnWithRepo(StudyRepository repo, String pgnText, String title) async {
    final result = _importService.importPgn(pgnText, studyTitle: title);
    if (result.study.id.isNotEmpty) {
      await repo.saveStudy(result.study);
      for (final chapter in result.chapters) {
        await repo.saveChapter(chapter);
        if (chapter.root != null) {
          await repo.savePositionTree(chapter.id, chapter.root!);
          _saveDecisionsRecursive(repo, result.study.id, chapter.id, chapter.root!);
        }
      }
    }
  }

  void _saveDecisionsRecursive(StudyRepository repo, String studyId, String chapterId, PositionNode node) {
    if (!node.isLeaf && node.childMoves.isNotEmpty) {
      final decision = RepertoireDecision.create(
        studyId: studyId,
        chapterId: chapterId,
        nodeId: node.id,
        expectedMoves: node.childMoves,
      );
      repo.saveDecision(decision);
    }
    for (final child in node.children) {
      _saveDecisionsRecursive(repo, studyId, chapterId, child);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chess Repertoire SRS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF161512),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF629924),
          surface: Color(0xFF262421),
        ),
        useMaterial3: true,
      ),
      home: _repository == null || _reviewService == null
          ? const _LoadingScreen()  // Show immediately while init runs
          : ReviewPage(
              repository: _repository!,
              reviewService: _reviewService!,
              onImportPgn: _importPgn,
            ),
    );
  }

  Future<void> _importPgn(String pgnText, String title) async {
    if (_repository == null) return;
    await _importPgnWithRepo(_repository!, pgnText, title);
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF161512),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFF629924)),
            const SizedBox(height: 24),
            const Text(
              'Chess Repertoire SRS',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Loading repertoire...',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class ReviewPage extends StatefulWidget {
  const ReviewPage({
    super.key,
    required this.repository,
    required this.reviewService,
    required this.onImportPgn,
  });

  final StudyRepository repository;
  final ReviewService reviewService;
  final Future<void> Function(String pgnText, String title) onImportPgn;

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  RepertoireDecision? _currentDecision;
  PositionNode? _currentNode;
  PositionNode? _previewNode; // Non-null when exploring via tree preview
  String? _selectedSquare;
  String? _lastMoveFrom;
  String? _lastMoveTo;
  String _feedback = '';
  RepertoireMove? _expectedMove;
  bool _isLoading = true;
  int _dueCount = 0;

  String? _scopedStudyId; // null = All studies
  List<Study> _allStudies = [];
  Map<String, int> _studyDueCounts = {};

  @override
  void initState() {
    super.initState();
    _loadInitialDecision();
  }

  Future<void> _loadInitialDecision() async {
    setState(() => _isLoading = true);
    _allStudies = await widget.repository.getAllStudies();

    // Compute due counts per study
    final counts = <String, int>{};
    for (final study in _allStudies) {
      final studyDue = await widget.reviewService.getDueDecisions(studyId: study.id);
      counts[study.id] = studyDue.length;
    }
    _studyDueCounts = counts;

    final decisions = await widget.reviewService.getDueDecisions(studyId: _scopedStudyId);
    _dueCount = decisions.length;

    if (decisions.isNotEmpty) {
      final decision = decisions.first;
      _currentDecision = decision;
      final chapter = await widget.repository.getChapter(decision.chapterId);
      if (chapter != null && chapter.root != null) {
        _currentNode = _findNodeById(chapter.root!, decision.nodeId);
      }
    } else {
      _currentDecision = null;
      _currentNode = null;
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        _selectedSquare = null;
      });
    }
  }

  PositionNode? _findNodeById(PositionNode root, String targetId) {
    if (root.id == targetId) return root;
    for (final child in root.children) {
      final found = _findNodeById(child, targetId);
      if (found != null) return found;
    }
    return null;
  }

  List<PositionNode> _findPathToNode(PositionNode root, String targetId, [List<PositionNode> currentPath = const []]) {
    final path = [...currentPath, root];
    if (root.id == targetId) return path;
    for (final child in root.children) {
      final found = _findPathToNode(child, targetId, path);
      if (found.isNotEmpty) return found;
    }
    return [];
  }

  Future<List<PositionNode>> _getPreviewPath() async {
    if (_previewNode == null || _currentDecision == null) return [];
    final chapter = await widget.repository.getChapter(_currentDecision!.chapterId);
    if (chapter == null || chapter.root == null) return [];
    return _findPathToNode(chapter.root!, _previewNode!.id);
  }

  Future<void> _navigatePreview(bool next) async {
    if (_previewNode == null || _currentDecision == null) return;
    final chapter = await widget.repository.getChapter(_currentDecision!.chapterId);
    if (chapter == null || chapter.root == null) return;
    final path = _findPathToNode(chapter.root!, _previewNode!.id);
    if (path.isEmpty) return;

    if (next) {
      if (_previewNode!.children.length == 1) {
        setState(() {
          _previewNode = _previewNode!.children.first;
          _selectedSquare = null;
        });
      }
    } else {
      if (path.length > 1) {
        // path[path.length - 1] is _previewNode, path[path.length - 2] is parent
        setState(() {
          _previewNode = path[path.length - 2];
          _selectedSquare = null;
        });
      }
    }
  }

  void _onSquareTapped(String square) {
    if (_previewNode != null) return; // Read-only preview mode
    if (_currentDecision == null || _currentNode == null) return;

    if (_selectedSquare == null) {
      setState(() {
        _selectedSquare = square;
      });
    } else {
      final from = _selectedSquare!;
      final to = square;
      setState(() {
        _selectedSquare = null;
      });
      if (from != to) {
        _submitMove(from, to, null);
      }
    }
  }

  Future<void> _submitMove(String from, String to, String? promotion) async {
    if (_currentDecision == null || _currentNode == null) return;

    final result = await widget.reviewService.processAnswer(
      currentNode: _currentNode!,
      decision: _currentDecision!,
      from: from,
      to: to,
      promotion: promotion,
    );

    final outcome = result.outcome;
    final continuation = result.continuation;

    setState(() {
      _lastMoveFrom = from;
      _lastMoveTo = to;
    });

    if (outcome.correct) {
      try {
        HapticFeedback.lightImpact();
      } catch (_) {}

      setState(() {
        _feedback = '✓ Correct';
        _expectedMove = null;
      });
      
      // Handle automatic continuation
      if (continuation != null && continuation.autoPlayedMoves.isNotEmpty) {
        _showAutoPlayedMoves(continuation.autoPlayedMoves);
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      if (continuation?.nextPrompt != null) {
        // There's a next due decision - load it
        final nextPrompt = continuation!.nextPrompt!;
        final chapter = await widget.repository.getChapter(
          _currentDecision!.chapterId
        );
        if (chapter != null && chapter.root != null) {
          _currentNode = _findNodeById(chapter.root!, nextPrompt.nodeId);
          _currentDecision = RepertoireDecision.create(
            studyId: _currentDecision!.studyId,
            chapterId: _currentDecision!.chapterId,
            nodeId: nextPrompt.nodeId,
            expectedMoves: nextPrompt.expectedMoves,
          );
        }
        setState(() {
          _feedback = '✓ Correct';
          _selectedSquare = null;
        });
      } else {
        // No more due decisions - reload
        await _loadInitialDecision();
      }
    } else {
      // Incorrect answer - show expected move
      try {
        HapticFeedback.heavyImpact();
      } catch (_) {}

      setState(() {
        _feedback = '✗ Not in repertoire';
        _expectedMove = outcome.expectedMove;
      });
      // Still process the review result for SRS
      await widget.reviewService.processReviewResult(_currentDecision!.id, false);
      
      // After showing error, auto-continue to next due decision
      await Future.delayed(const Duration(milliseconds: 1500));
      await _loadInitialDecision();
    }
  }

  Future<void> _showAutoPlayedMoves(List<AutoPlayedMove> moves) async {
    if (!mounted) return;
    for (final move in moves) {
      if (!mounted) return;
      // Extract from/to if possible from SAN or UCI if represented, or keep last move
      setState(() {
        _feedback = move.isUserMove 
            ? '✓ Auto: ${move.san}' 
            : '✓ Opponent: ${move.san}';
      });
      await Future.delayed(const Duration(milliseconds: 400));
    }
  }

  void _showImportDialog() {
    final textController = TextEditingController();
    final titleController = TextEditingController(text: 'New Study');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import PGN Study'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Study Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'PGN Content (moves, chapters, variations)',
                  border: OutlineInputBorder(),
                  hintText: '1. e4 e5 2. Nf3 Nc6 (2... d6) ...',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final pgn = textController.text.trim();
              final title = titleController.text.trim();
              if (pgn.isNotEmpty) {
                Navigator.of(ctx).pop();
                await widget.onImportPgn(pgn, title.isNotEmpty ? title : 'Imported Study');
                await _loadInitialDecision();
              }
            },
            child: const Text('Import & Learn'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeStudyTitle = _scopedStudyId != null
        ? _allStudies.firstWhere((s) => s.id == _scopedStudyId, orElse: () => const Study(id: '', title: '')).title
        : 'All Studies';

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF161512),
        title: Row(
          children: [
            const Icon(Icons.bolt, color: Color(0xFF629924), size: 20),
            const SizedBox(width: 8),
            Text(
              activeStudyTitle.isNotEmpty ? activeStudyTitle : 'Review',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          if (_dueCount > 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  '$_dueCount due',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF81B64C), fontWeight: FontWeight.bold),
                ),
              ),
            ),
          Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.account_tree_outlined, size: 20),
              tooltip: 'Study Tree',
              onPressed: () => Scaffold.of(ctx).openEndDrawer(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.file_upload_outlined, size: 20),
            tooltip: 'Import PGN',
            onPressed: _showImportDialog,
          ),
          const SizedBox(width: 4),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF262421)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text(
                    'Chess Repertoire SRS',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Total studies: ${_allStudies.length}',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.all_inclusive),
              title: const Text('All Studies'),
              trailing: Chip(
                label: Text('${_studyDueCounts.values.fold(0, (a, b) => a + b)}'),
              ),
              selected: _scopedStudyId == null,
              onTap: () {
                Navigator.of(context).pop();
                setState(() => _scopedStudyId = null);
                _loadInitialDecision();
              },
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                'STUDIES',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
            ),
            for (final study in _allStudies)
              ListTile(
                leading: const Icon(Icons.book_outlined),
                title: Text(study.title),
                trailing: Chip(
                  label: Text('${_studyDueCounts[study.id] ?? 0}'),
                ),
                selected: _scopedStudyId == study.id,
                onTap: () {
                  Navigator.of(context).pop();
                  setState(() => _scopedStudyId = study.id);
                  _loadInitialDecision();
                },
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Import Study'),
              onTap: () {
                Navigator.of(context).pop();
                _showImportDialog();
              },
            ),
          ],
        ),
      ),
      endDrawer: Drawer(
        child: StudyTreeSidebar(
          studies: _allStudies,
          selectedStudyId: _scopedStudyId,
          currentNodeId: _currentNode?.id,
          previewNodeId: _previewNode?.id,
          onStudySelected: (id) {
            setState(() => _scopedStudyId = id);
          },
          onNodeSelected: (node) {
            setState(() {
              _previewNode = node;
              _selectedSquare = null;
            });
            Navigator.of(context).pop();
          },
          repository: widget.repository,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentDecision == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_outline, size: 64, color: Color(0xFF629924)),
                      const SizedBox(height: 16),
                      const Text(
                        "You're up to date!",
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _scopedStudyId != null
                            ? 'No positions currently due for this study.'
                            : 'No positions currently due for review.',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Import Study PGN'),
                        onPressed: _showImportDialog,
                      ),
                    ],
                  ),
                )
                : Column(
                   children: [
                     const SizedBox(height: 12),
                     if (_previewNode != null) ...[
                       FutureBuilder<List<PositionNode>>(
                         future: _getPreviewPath(),
                         builder: (context, snapshot) {
                           final path = snapshot.data ?? [];
                           // Exclude root itself (which has no incoming move)
                           final moves = path.where((n) => n.incomingMove != null).toList();
                           final canGoBack = path.length > 1;
                           final canGoForward = _previewNode!.children.length == 1;

                           return Container(
                             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                             color: const Color(0xFF262421),
                             child: Row(
                               children: [
                                 IconButton(
                                   icon: const Icon(Icons.chevron_left, size: 18),
                                   color: canGoBack ? Colors.white : Colors.white24,
                                   padding: EdgeInsets.zero,
                                   constraints: const BoxConstraints(),
                                   tooltip: 'Previous position',
                                   onPressed: canGoBack ? () => _navigatePreview(false) : null,
                                 ),
                                 const SizedBox(width: 4),
                                 IconButton(
                                   icon: const Icon(Icons.chevron_right, size: 18),
                                   color: canGoForward ? Colors.white : Colors.white24,
                                   padding: EdgeInsets.zero,
                                   constraints: const BoxConstraints(),
                                   tooltip: 'Next position',
                                   onPressed: canGoForward ? () => _navigatePreview(true) : null,
                                 ),
                                 const SizedBox(width: 8),
                                 const Text('Line: ', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                 Expanded(
                                   child: SingleChildScrollView(
                                     scrollDirection: Axis.horizontal,
                                     child: Row(
                                       children: [
                                         for (var i = 0; i < moves.length; i++) ...[
                                           if (i > 0) const SizedBox(width: 4),
                                           Container(
                                             padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                             decoration: BoxDecoration(
                                               color: moves[i].id == _previewNode?.id
                                                   ? const Color(0xFFE5C07B).withValues(alpha: 0.3)
                                                   : Colors.transparent,
                                               borderRadius: BorderRadius.circular(3),
                                             ),
                                             child: Text(
                                               i % 2 == 0
                                                   ? '${(i ~/ 2) + 1}. ${moves[i].incomingMove!.san}'
                                                   : moves[i].incomingMove!.san,
                                               style: TextStyle(
                                                 fontSize: 12,
                                                 color: moves[i].id == _previewNode?.id ? Colors.white : Colors.white70,
                                                 fontWeight: moves[i].id == _previewNode?.id ? FontWeight.bold : FontWeight.normal,
                                               ),
                                             ),
                                           ),
                                         ],
                                       ],
                                     ),
                                   ),
                                 ),
                                 const SizedBox(width: 8),
                                 ElevatedButton(
                                   style: ElevatedButton.styleFrom(
                                     backgroundColor: const Color(0xFF3E3B38),
                                     foregroundColor: Colors.white,
                                     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                     minimumSize: Size.zero,
                                     tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                   ),
                                   onPressed: () {
                                     setState(() {
                                       _previewNode = null;
                                     });
                                   },
                                   child: const Text('Return to Review', style: TextStyle(fontSize: 11)),
                                 ),
                               ],
                             ),
                           );
                         },
                       ),
                     ] else ...[
                       Padding(
                         padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                         child: Row(
                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
                           children: [
                             Text(
                               _scopedStudyId != null ? 'Study Review' : 'All Studies Review',
                               style: const TextStyle(fontSize: 13, color: Colors.grey),
                             ),
                             Text(
                               '$_dueCount remaining',
                               style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF81B64C)),
                             ),
                           ],
                         ),
                       ),
                     ],
                      if (_feedback.isNotEmpty && _previewNode == null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Text(
                            _feedback,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: _feedback.startsWith('✓') ? const Color(0xFF81B64C) : const Color(0xFFE06C75),
                            ),
                          ),
                        ),
                      if (_expectedMove != null && _previewNode == null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Text(
                            'Expected repertoire move: ${_expectedMove!.san}',
                            style: const TextStyle(color: Colors.amber, fontStyle: FontStyle.italic, fontSize: 13),
                          ),
                        ),
                      Expanded(
                        child: Center(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final boardSize = constraints.maxWidth < constraints.maxHeight
                                  ? constraints.maxWidth
                                  : constraints.maxHeight;
                              final clampedSize = boardSize.clamp(320.0, 720.0);
                              final squareSize = clampedSize / 8.0;

                              return SizedBox(
                                width: clampedSize,
                                height: clampedSize,
                                child: _buildBoard(squareSize: squareSize),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                   ],
                 ),
    );
  }

  Widget _buildBoard({required double squareSize}) {
    final activeNode = _previewNode ?? _currentNode;
    final fen = activeNode?.fen ?? ChessService.initialFen;
    final board = _getBoardAsStrings(fen);
    final pieceSize = squareSize * 0.85;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black45, width: 2),
      ),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 8,
        ),
        itemCount: 64,
        itemBuilder: (context, index) {
          final row = index ~/ 8;
          final col = index % 8;
          final isDark = (row + col) % 2 == 1;

          // Rank is 8 - row, file is a + col
          final rank = 8 - row;
          final file = String.fromCharCode('a'.codeUnitAt(0) + col);
          final square = '$file$rank';
          final isSelected = _selectedSquare == square;
          final isLastMove = _lastMoveFrom == square || _lastMoveTo == square;
          final piece = board[row][col];

          Color squareColor;
          if (isSelected) {
            squareColor = const Color(0xFFBACA44);
          } else if (isLastMove) {
            squareColor = isDark ? const Color(0xFF829763) : const Color(0xFFD6DB75);
          } else {
            squareColor = isDark ? const Color(0xFF769656) : const Color(0xFFEEEED2);
          }

          return DragTarget<String>(
            onWillAcceptWithDetails: (details) => details.data != square,
            onAcceptWithDetails: (details) {
              final from = details.data;
              if (from != square) {
                setState(() => _selectedSquare = null);
                _submitMove(from, square, null);
              }
            },
            builder: (context, candidateData, rejectedData) {
              final squareWidget = GestureDetector(
                onTap: () => _onSquareTapped(square),
                child: Container(
                  color: squareColor,
                  alignment: Alignment.center,
                      child: piece.isEmpty
                          ? const SizedBox.shrink()
                          : SvgPicture.asset(
                              _getPieceAssetPath(piece),
                              width: pieceSize,
                              height: pieceSize,
                              fit: BoxFit.contain,
                            ),
                ),
              );

              if (piece.isEmpty) {
                return squareWidget;
              }

              return Draggable<String>(
                data: square,
                feedback: Material(
                  color: Colors.transparent,
                  child: SizedBox(
                    width: squareSize,
                    height: squareSize,
                    child: SvgPicture.asset(
                      _getPieceAssetPath(piece),
                      width: pieceSize,
                      height: pieceSize,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                childWhenDragging: Container(
                  color: squareColor,
                ),
                child: squareWidget,
              );
            },
          );
        },
      ),
    );
  }

  String _getPieceAssetPath(String piece) {
    switch (piece) {
      case '♙': return PieceImages.assetPath(5, chess.Color.WHITE);
      case '♘': return PieceImages.assetPath(4, chess.Color.WHITE);
      case '♗': return PieceImages.assetPath(3, chess.Color.WHITE);
      case '♖': return PieceImages.assetPath(2, chess.Color.WHITE);
      case '♕': return PieceImages.assetPath(1, chess.Color.WHITE);
      case '♔': return PieceImages.assetPath(0, chess.Color.WHITE);
      case '♟': return PieceImages.assetPath(5, chess.Color.BLACK);
      case '♞': return PieceImages.assetPath(4, chess.Color.BLACK);
      case '♝': return PieceImages.assetPath(3, chess.Color.BLACK);
      case '♜': return PieceImages.assetPath(2, chess.Color.BLACK);
      case '♛': return PieceImages.assetPath(1, chess.Color.BLACK);
      case '♚': return PieceImages.assetPath(0, chess.Color.BLACK);
      default: return '';
    }
  }

  List<List<String>> _getBoardAsStrings(String fen) {
    final rows = fen.trim().split(' ')[0].split('/');
    final grid = <List<String>>[];
    for (final row in rows) {
      final rank = <String>[];
      for (var i = 0; i < row.length; i++) {
        final char = row[i];
        if (RegExp(r'[1-8]').hasMatch(char)) {
          final count = int.parse(char);
          for (var j = 0; j < count; j++) {
            rank.add('');
          }
        } else {
          switch (char) {
            case 'P': rank.add('♙'); break;
            case 'N': rank.add('♘'); break;
            case 'B': rank.add('♗'); break;
            case 'R': rank.add('♖'); break;
            case 'Q': rank.add('♕'); break;
            case 'K': rank.add('♔'); break;
            case 'p': rank.add('♟'); break;
            case 'n': rank.add('♞'); break;
            case 'b': rank.add('♝'); break;
            case 'r': rank.add('♜'); break;
            case 'q': rank.add('♛'); break;
            case 'k': rank.add('♚'); break;
            default: rank.add(''); break;
          }
        }
      }
      grid.add(rank);
    }
    return grid;
  }
}