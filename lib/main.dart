import 'package:flutter/material.dart';
import 'package:chess_repertoire_srs/application/review_service.dart';
import 'package:chess_repertoire_srs/chess/chess_service.dart';
import 'package:chess_repertoire_srs/domain/entities/position.dart';
import 'package:chess_repertoire_srs/domain/entities/position_node.dart';
import 'package:chess_repertoire_srs/domain/entities/repertoire_move.dart';
import 'package:chess_repertoire_srs/domain/repertoire_decision.dart';
import 'package:chess_repertoire_srs/persistence/study_repository.dart';
import 'package:chess_repertoire_srs/persistence/in_memory_study_repository.dart';
import 'package:chess_repertoire_srs/domain/srs/simple_scheduler.dart';
import 'package:chess_repertoire_srs/domain/clock.dart';

void main() {
  runApp(const ChessRepertoireApp());
}

class ChessRepertoireApp extends StatefulWidget {
  const ChessRepertoireApp({super.key});

  @override
  State<ChessRepertoireApp> createState() => _ChessRepertoireAppState();
}

class _ChessRepertoireAppState extends State<ChessRepertoireApp> {
  late final StudyRepository repository;
  late final ReviewService reviewService;
  late final Clock clock = SystemClock();

  @override
  void initState() {
    super.initState();
    repository = InMemoryStudyRepository();
    reviewService = ReviewService(
      studyRepository: repository,
      chessService: ChessService(),
      scheduler: SimpleScheduler(),
      clock: clock,
    );
    _ensureMockStudy();
  }

  Future<void> _ensureMockStudy() async {
    final studies = await repository.getAllStudies();
    if (studies.isEmpty) {
      final study = await repository.createStudy('Mock Study');
      final chapter = await repository.createChapter(
        studyId: study.id,
        sourceOrder: 0,
        title: 'Mock Chapter',
        startingFen: ChessService.initialFen,
      );
      // Build a simple tree: e2e4
      final root = PositionNode.create(
        positionKey: PositionKey.fromFen(ChessService.initialFen),
        fen: ChessService.initialFen,
      );
      // Create a child for e2e4
      final move = RepertoireMove.fromAlgebraic('e2', 'e4');
      final childPositionKey = PositionKey.fromFen('rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1');
      final child = PositionNode.create(
        positionKey: childPositionKey,
        fen: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1',
        incomingMove: move,
      );
      root.addChild(child);
      await repository.savePositionTree(chapter.id, root);
      // Create a decision for the root node (since it's white to move and has children)
      final decision = RepertoireDecision.create(
        studyId: study.id,
        chapterId: chapter.id,
        nodeId: root.id,
        expectedMoves: [move],
      );
      await repository.saveDecision(decision);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chess Repertoire SRS',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final StudyRepository repository;
  late final ReviewService reviewService;

  @override
  void initState() {
    super.initState();
    // Note: In a real app, we would use dependency injection to get these.
    // For simplicity, we are creating them here, but this is not ideal.
    // We will fix this by using a state management solution or passing them down.
    // For now, we'll create a new instance, but note that this will not share state with the app state.
    // We'll change this later to use the same instance as in ChessRepertoireApp.
    // For the sake of time, we'll assume we are in the review page and have a study.
    // We'll show the review page directly.
    repository = InMemoryStudyRepository();
    reviewService = ReviewService(
      studyRepository: repository,
      chessService: ChessService(),
      scheduler: SimpleScheduler(),
      clock: SystemClock(),
    );
    _ensureMockStudyForHome();
  }

  Future<void> _ensureMockStudyForHome() async {
    final studies = await repository.getAllStudies();
    if (studies.isEmpty) {
      final study = await repository.createStudy('Mock Study');
      final chapter = await repository.createChapter(
        studyId: study.id,
        sourceOrder: 0,
        title: 'Mock Chapter',
        startingFen: ChessService.initialFen,
      );
      // Build a simple tree: e2e4
      final root = PositionNode.create(
        positionKey: PositionKey.fromFen(ChessService.initialFen),
        fen: ChessService.initialFen,
      );
      // Create a child for e2e4
      final move = RepertoireMove.fromAlgebraic('e2', 'e4');
      final childPositionKey = PositionKey.fromFen('rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1');
      final child = PositionNode.create(
        positionKey: childPositionKey,
        fen: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1',
        incomingMove: move,
      );
      root.addChild(child);
      await repository.savePositionTree(chapter.id, root);
      // Create a decision for the root node (since it's white to move and has children)
      final decision = RepertoireDecision.create(
        studyId: study.id,
        chapterId: chapter.id,
        nodeId: root.id,
        expectedMoves: [move],
      );
      await repository.saveDecision(decision);
    }
  }

  @override
  Widget build(BuildContext context) {
    // For now, we'll always show the review page.
    // In the future, we'll check if there are studies and show the import page if not.
    return const ReviewPage();
  }
}

class ReviewPage extends StatefulWidget {
  const ReviewPage({super.key});

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  late final StudyRepository repository;
  late final ReviewService reviewService;
  RepertoireDecision? _currentDecision;
  PositionNode? _currentNode;
  String _moveInput = '';
  String _feedback = '';
  RepertoireMove? _expectedMove;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    repository = InMemoryStudyRepository();
    reviewService = ReviewService(
      studyRepository: repository,
      chessService: ChessService(),
      scheduler: SimpleScheduler(),
      clock: const SystemClock(),
    );
    _loadInitialDecision();
  }

  Future<void> _loadInitialDecision() async {
    setState(() {
      _isLoading = true;
    });
    final decisions = await reviewService.getDueDecisions();
    if (decisions.isNotEmpty) {
      final decision = decisions.first;
      _currentDecision = decision;
      // Get the node for this decision
      final chapter = await repository.getChapter(decision.chapterId);
      if (chapter != null && chapter.root != null) {
        _currentNode = _findNodeById(chapter.root!, decision.nodeId);
      }
    }
    setState(() {
      _isLoading = false;
    });
  }

  PositionNode? _findNodeById(PositionNode root, String targetId) {
    if (root.id == targetId) return root;
    for (final child in root.children) {
      final found = _findNodeById(child, targetId);
      if (found != null) return found;
    }
    return null;
  }

  Future<void> _submitMove() async {
    if (_currentDecision == null || _currentNode == null) return;
    final from = _moveInput.substring(0, 2);
    final to = _moveInput.substring(2, 4);
    final promotion = _moveInput.length > 4 ? _moveInput.substring(4) : null;
    final outcome = await reviewService.validateMove(
      _currentDecision!.id,
      from,
      to,
      promotion,
    );
    setState(() {
      _feedback = outcome.correct ? 'Correct!' : 'Incorrect. Expected: ${_expectedMove?.san ?? '???'}';
      _expectedMove = outcome.expectedMove;
    });
    if (outcome.correct) {
      await reviewService.processReviewResult(_currentDecision!.id, true);
      // After a correct move, load the next decision
      await _loadInitialDecision();
    } else {
      // Optionally, we can show the expected move on the board
      // For now, just show feedback
    }
    // Clear the input
    _moveInput = '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chess Repertoire Review'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentDecision == null
              ? const Center(child: Text('No due reviews. Come back later!'))
              : Column(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildBoard(),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Move: $_moveInput',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _submitMove,
                              child: const Text('Submit Move'),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _feedback,
                              style: TextStyle(
                                color: _feedback.contains('Correct') ? Colors.green : Colors.red,
                              ),
                            ),
                            if (_expectedMove != null && !_feedback.contains('Correct'))
                              Text(
                                'Expected: ${_expectedMove!.san}',
                                style: const TextStyle(fontStyle: FontStyle.italic),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
      floatingActionButton: _moveInput.isNotEmpty
          ? FloatingActionButton(
              onPressed: () {
                setState(() {
                  _moveInput = _moveInput.substring(0, _moveInput.length - 1);
                });
              },
              child: const Icon(Icons.backspace),
            )
          : null,
    );
  }

  Widget _buildBoard() {
    if (_currentNode == null) {
      return const Center(child: Text('No position'));
    }
    final board = _getBoardAsStrings(_currentNode!.fen);
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 8,
      ),
      itemCount: 64,
      itemBuilder: (context, index) {
        final row = index ~/ 8;
        final col = index % 8;
        final isDark = (row + col) % 2 == 1;
        final piece = board[row][col];
        return Container(
          color: isDark ? Colors.brown[400] : Colors.brown[100],
          alignment: Alignment.center,
          child: Text(
            piece,
            style: TextStyle(
              fontSize: 32,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        );
      },
    );
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