import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:chess_repertoire_srs/application/review_service.dart';
import 'package:chess_repertoire_srs/chess/chess_service.dart';
import 'package:chess_repertoire_srs/chess/pgn_converter.dart';
import 'package:chess_repertoire_srs/domain/clock.dart';
import 'package:chess_repertoire_srs/domain/entities/position_node.dart';
import 'package:chess_repertoire_srs/domain/entities/repertoire_move.dart';
import 'package:chess_repertoire_srs/domain/entities/study.dart';
import 'package:chess_repertoire_srs/domain/repertoire_decision.dart';
import 'package:chess_repertoire_srs/domain/srs/simple_scheduler.dart';
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
  String? _selectedSquare;
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

  void _onSquareTapped(String square) {
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

    final outcome = await widget.reviewService.validateMove(
      _currentDecision!.id,
      from,
      to,
      promotion,
    );

    if (outcome.correct) {
      setState(() {
        _feedback = '✓ Correct';
        _expectedMove = null;
      });
      await widget.reviewService.processReviewResult(_currentDecision!.id, true);
      await Future.delayed(const Duration(milliseconds: 250));
      await _loadInitialDecision();
    } else {
      setState(() {
        _feedback = '✗ Not in repertoire';
        _expectedMove = outcome.expectedMove;
      });
      await widget.reviewService.processReviewResult(_currentDecision!.id, false);
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
        title: Text(activeStudyTitle.isNotEmpty ? activeStudyTitle : 'Review'),
        actions: [
          if (_dueCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Center(
                child: Chip(
                  label: Text('$_dueCount due'),
                  backgroundColor: const Color(0xFF629924),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.file_upload_outlined),
            tooltip: 'Import PGN',
            onPressed: _showImportDialog,
          ),
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
                    if (_feedback.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          _feedback,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _feedback.startsWith('✓') ? const Color(0xFF81B64C) : const Color(0xFFE06C75),
                          ),
                        ),
                      ),
                    if (_expectedMove != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          'Expected repertoire move: ${_expectedMove!.san}',
                          style: const TextStyle(color: Colors.amber, fontStyle: FontStyle.italic),
                        ),
                      ),
                    Expanded(
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: 1.0,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: _buildBoard(),
                          ),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12.0),
                      child: Text(
                        'Tap piece to select, tap square to move',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildBoard() {
    final fen = _currentNode?.fen ?? ChessService.initialFen;
    final board = _getBoardAsStrings(fen);

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
          final piece = board[row][col];

          return GestureDetector(
            onTap: () => _onSquareTapped(square),
            child: Container(
              color: isSelected
                  ? const Color(0xFFBACA44)
                  : isDark
                      ? const Color(0xFF769656)
                      : const Color(0xFFEEEED2),
              alignment: Alignment.center,
              child: Text(
                piece,
                style: TextStyle(
                  fontSize: 34,
                  color: _isWhitePiece(piece) ? Colors.white : Colors.black,
                  shadows: [
                    Shadow(
                      color: _isWhitePiece(piece) ? Colors.black87 : Colors.white70,
                      blurRadius: 1.5,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  bool _isWhitePiece(String piece) {
    return '♙♘♗♖♕♔'.contains(piece);
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