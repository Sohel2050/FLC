import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:squares/squares.dart';
import 'package:bishop/bishop.dart' as bishop;
import 'package:square_bishop/square_bishop.dart';
import '../models/puzzle_model.dart';
import '../providers/puzzle_provider.dart';
import '../providers/settings_provoder.dart';

class PuzzleBoardScreen extends StatefulWidget {
  final PuzzleModel puzzle;

  const PuzzleBoardScreen({super.key, required this.puzzle});

  @override
  State<PuzzleBoardScreen> createState() => _PuzzleBoardScreenState();
}

class _PuzzleBoardScreenState extends State<PuzzleBoardScreen> {
  late bishop.Game _game;
  late SquaresState _state;
  late PuzzleProvider _puzzleProvider;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _puzzleProvider = context.read<PuzzleProvider>();
    _initializePuzzle();
  }

  void _initializePuzzle() {
    try {
      // Create game from FEN position
      _game = bishop.Game(
        variant: bishop.Variant.standard(),
        fen: widget.puzzle.fen,
      );

      // Create squares state for the puzzle
      // For puzzles, we always play as the side to move
      final playerColor = _game.state.turn;
      _state = _game.squaresState(playerColor);

      setState(() {
        _isInitialized = true;
      });

      // Start the puzzle session
      _puzzleProvider.startPuzzle(widget.puzzle);
    } catch (e) {
      // Handle FEN parsing error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load puzzle: $e'),
          backgroundColor: Colors.red,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  void _onMove(Move move) async {
    if (!_isInitialized) return;

    // Make the move in the game
    final success = _game.makeSquaresMove(move);
    if (!success) return;

    // Update the squares state
    final playerColor = _game.state.turn == Squares.white
        ? Squares.black
        : Squares.white;
    _state = _game.squaresState(playerColor);

    // Notify the puzzle provider about the move
    final moveString = move.toString();
    final isValidMove = await _puzzleProvider.makeMove(moveString);

    if (isValidMove) {
      // Check if puzzle is solved
      final session = _puzzleProvider.currentSession;
      if (session != null && session.isCompleted) {
        _showPuzzleCompletedDialog();
      } else {
        // Make the opponent's response move if there is one
        _makeOpponentMove();
      }
    } else {
      // Invalid move - reset the board state
      _resetBoardState();
      _showIncorrectMoveMessage();
    }

    setState(() {});
  }

  void _makeOpponentMove() {
    final session = _puzzleProvider.currentSession;
    if (session == null) return;

    final solution = session.puzzle.solution;
    final userMoves = session.userMoves;

    // Check if there's an opponent response move
    if (userMoves.length < solution.length) {
      final nextMoveIndex = userMoves.length;
      if (nextMoveIndex < solution.length) {
        final opponentMoveString = solution[nextMoveIndex];

        // Make the opponent move using the move string
        try {
          // Try to make the move using the move string
          final success = _game.makeMoveString(opponentMoveString);

          if (success) {
            // Update state after opponent move
            final playerColor = _game.state.turn;
            _state = _game.squaresState(playerColor);
            setState(() {});
          }
        } catch (e) {
          // Handle move parsing error
          debugPrint('Error making opponent move: $e');
        }
      }
    }
  }

  void _resetBoardState() {
    // Reset the game to the original FEN position
    _game = bishop.Game(
      variant: bishop.Variant.standard(),
      fen: widget.puzzle.fen,
    );

    final playerColor = _game.state.turn;
    _state = _game.squaresState(playerColor);
  }

  void _showIncorrectMoveMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Incorrect move. Try again!'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showPuzzleCompletedDialog() {
    final session = _puzzleProvider.currentSession;
    if (session == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 8),
            Text('Puzzle Solved!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Congratulations! You solved the puzzle.'),
            const SizedBox(height: 8),
            Text('Time: ${_formatDuration(session.solveTime)}'),
            if (session.hintsUsed > 0) Text('Hints used: ${session.hintsUsed}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              _resetPuzzle();
            },
            child: const Text('Retry'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop(); // Close dialog
              await _nextPuzzle();
            },
            child: const Text('Next Puzzle'),
          ),
        ],
      ),
    );
  }

  void _resetPuzzle() {
    _puzzleProvider.resetPuzzle();
    _resetBoardState();
    setState(() {});
  }

  Future<void> _nextPuzzle() async {
    final nextPuzzle = await _puzzleProvider.nextPuzzle();
    if (nextPuzzle != null) {
      // Replace current screen with new puzzle
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => PuzzleBoardScreen(puzzle: nextPuzzle),
          ),
        );
      }
    } else {
      // No more puzzles, go back to difficulty selection
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Congratulations! You completed all puzzles in this difficulty.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _requestHint() async {
    final hint = await _puzzleProvider.requestHint();
    if (hint != null && mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.lightbulb, color: Colors.amber),
              SizedBox(width: 8),
              Text('Hint'),
            ],
          ),
          content: Text(hint),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Got it'),
            ),
          ],
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No more hints available for this puzzle.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading Puzzle...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final settingsProvider = context.read<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.puzzle.difficulty.displayName} Puzzle'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        actions: [
          Consumer<PuzzleProvider>(
            builder: (context, puzzleProvider, child) {
              final session = puzzleProvider.currentSession;
              final hasMoreHints = session?.hasMoreHints ?? false;

              return IconButton(
                onPressed: hasMoreHints ? _requestHint : null,
                icon: Icon(
                  Icons.lightbulb,
                  color: hasMoreHints ? null : Colors.grey,
                ),
                tooltip: hasMoreHints ? 'Get Hint' : 'No more hints',
              );
            },
          ),
          IconButton(
            onPressed: _resetPuzzle,
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset Puzzle',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Puzzle info section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Objective
                  Text(
                    widget.puzzle.objective,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Puzzle metadata
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          widget.puzzle.difficulty.displayName,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.onPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Rating: ${widget.puzzle.rating}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      Consumer<PuzzleProvider>(
                        builder: (context, puzzleProvider, child) {
                          final session = puzzleProvider.currentSession;
                          final hintsUsed = session?.hintsUsed ?? 0;
                          final totalHints = widget.puzzle.hints.length;

                          return Row(
                            children: [
                              Icon(
                                Icons.lightbulb,
                                size: 16,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$hintsUsed/$totalHints',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Chess board
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: BoardController(
                    state: _state.board,
                    playState: _state.state,
                    pieceSet: settingsProvider.getPieceSet(),
                    theme: settingsProvider.boardTheme,
                    animatePieces: settingsProvider.animatePieces,
                    labelConfig: settingsProvider.showLabels
                        ? LabelConfig.standard
                        : LabelConfig.disabled,
                    moves: _state.moves,
                    onMove: _onMove,
                    onPremove: _onMove,
                    markerTheme: MarkerTheme(
                      empty: MarkerTheme.dot,
                      piece: MarkerTheme.corners(),
                    ),
                    promotionBehaviour: PromotionBehaviour.autoPremove,
                  ),
                ),
              ),
            ),

            // Bottom action buttons
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _resetPuzzle,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reset'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Consumer<PuzzleProvider>(
                      builder: (context, puzzleProvider, child) {
                        final session = puzzleProvider.currentSession;
                        final hasMoreHints = session?.hasMoreHints ?? false;

                        return ElevatedButton.icon(
                          onPressed: hasMoreHints ? _requestHint : null,
                          icon: const Icon(Icons.lightbulb),
                          label: const Text('Hint'),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
