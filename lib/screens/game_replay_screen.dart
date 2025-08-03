import 'package:flutter/material.dart';
import 'package:flutter_chess_app/models/saved_game_model.dart';
import 'package:squares/squares.dart';
import 'package:bishop/bishop.dart' as bishop;
import 'package:square_bishop/square_bishop.dart';

class GameReplayScreen extends StatefulWidget {
  final SavedGame game;

  const GameReplayScreen({super.key, required this.game});

  @override
  State<GameReplayScreen> createState() => _GameReplayScreenState();
}

class _GameReplayScreenState extends State<GameReplayScreen> {
  late bishop.Game _game;
  late List<bishop.Move> _moves;
  int _currentMoveIndex = -1;

  @override
  void initState() {
    super.initState();
    _loadGame();
  }

  void _loadGame() {
    final initialGame = bishop.Game(fen: widget.game.initialFen);
    _moves = <bishop.Move>[];
    var currentGame = bishop.Game(fen: initialGame.fen);
    for (String moveStr in widget.game.moves) {
      final move = currentGame.getMove(moveStr);
      if (move != null) {
        _moves.add(move);
        currentGame.makeMove(move);
      }
    }
    _game = initialGame;
    // Start the game at last move position
    setState(() {
      _goToMove(_moves.length - 1);
    });
  }

  void _resetGame() {
    setState(() {
      _currentMoveIndex = -1;
    });
  }

  void _goToMove(int index) {
    if (index < -1 || index >= _moves.length) return;

    setState(() {
      _currentMoveIndex = index;
      _game = bishop.Game(fen: widget.game.initialFen);
      for (int i = 0; i <= index; i++) {
        _game.makeMove(_moves[i]);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Replay: vs ${widget.game.opponentDisplayName}'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: BoardController(
                state: _game.squaresState(Squares.white).board,
                playState: PlayState.theirTurn,
                pieceSet: PieceSet.merida(),
              ),
            ),
          ),
          _buildControls(),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.first_page),
            onPressed: _currentMoveIndex > -1 ? () => _goToMove(-1) : null,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed:
                _currentMoveIndex > -1
                    ? () => _goToMove(_currentMoveIndex - 1)
                    : null,
          ),
          Text(
            'Move ${_currentMoveIndex + 1}/${_moves.length}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed:
                _currentMoveIndex < _moves.length - 1
                    ? () => _goToMove(_currentMoveIndex + 1)
                    : null,
          ),
          IconButton(
            icon: const Icon(Icons.last_page),
            onPressed:
                _currentMoveIndex < _moves.length - 1
                    ? () => _goToMove(_moves.length - 1)
                    : null,
          ),
        ],
      ),
    );
  }
}
