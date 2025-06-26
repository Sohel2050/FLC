import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:squares/squares.dart';
import 'package:bishop/bishop.dart' as bishop;
import 'package:square_bishop/square_bishop.dart';
import 'package:stockfish/stockfish.dart';
import 'package:squares/squares.dart';

// Custom game result for timeout
class WonGameTimeout extends bishop.WonGame {
  const WonGameTimeout({required super.winner});
}

class GameProvider extends ChangeNotifier {
  late bishop.Game _game = bishop.Game(variant: bishop.Variant.standard());
  late SquaresState _state = SquaresState.initial(0);
  bool _aiThinking = false;
  bool _flipBoard = false;

  bool _vsCPU = false;
  bool _isLoading = false;
  bool _playWhitesTimer = true;
  bool _playBlacksTimer = true;
  int _gameLevel = 1;
  int _incrementalValue = 0;
  int _player = Squares.white;
  Timer? _whitesTimer;
  Timer? _blacksTimer;
  int _whitesScore = 0;
  int _blacksScore = 0;
  String _gameId = '';
  String _selectedTimeControl = '';

  Duration _whitesTime = Duration.zero;
  Duration _blacksTime = Duration.zero;

  // saved time
  Duration _savedWhitesTime = Duration.zero;
  Duration _savedBlacksTime = Duration.zero;

  // Game over notifier
  final ValueNotifier<bishop.GameResult?> _gameResultNotifier = ValueNotifier(
    null,
  );

  // Getters
  bishop.Game get game => _game;
  SquaresState get state => _state;
  bool get aiThinking => _aiThinking;
  bool get flipBoard => _flipBoard;

  bool get vsCPU => _vsCPU;
  bool get isLoading => _isLoading;
  bool get playWhitesTimer => _playWhitesTimer;
  bool get playBlacksTimer => _playBlacksTimer;
  int get gameLevel => _gameLevel;
  int get incrementalValue => _incrementalValue;
  int get player => _player;
  Timer? get whitesTimer => _whitesTimer;
  Timer? get blacksTimer => _blacksTimer;
  int get whitesScore => _whitesScore;
  int get blacksScore => _blacksScore;
  String get gameId => _gameId;
  String get selectedTimeControl => _selectedTimeControl;

  Duration get whitesTime => _whitesTime;
  Duration get blacksTime => _blacksTime;
  Duration get savedWhitesTime => _savedWhitesTime;
  Duration get savedBlacksTime => _savedBlacksTime;

  bishop.GameResult? get gameResult => _gameResultNotifier.value;
  ValueNotifier<bishop.GameResult?> get gameResultNotifier =>
      _gameResultNotifier;

  bool get isGameOver => _game.gameOver || _gameResultNotifier.value != null;

  void setVsCPU(bool value) {
    _vsCPU = value;
    notifyListeners();
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setGameLevel(int level) {
    _gameLevel = level;
    notifyListeners();
  }

  void setPlayer(int playerColor) {
    _player = playerColor;
    notifyListeners();
  }

  void setTimeControl(String timeControl) {
    _selectedTimeControl = timeControl;
    _parseTimeControl(timeControl);
    notifyListeners();
  }

  void _parseTimeControl(String timeControl) {
    // Parse different time control formats
    if (timeControl.contains('sec/move')) {
      // Format: "60 sec/move"
      final seconds = int.tryParse(timeControl.split(' ')[0]) ?? 60;
      _whitesTime = Duration(seconds: seconds);
      _blacksTime = Duration(seconds: seconds);
      _incrementalValue = 0;
    } else if (timeControl.contains('min + ') && timeControl.contains('sec')) {
      // Format: "5 min + 3 sec"
      final parts = timeControl.split(' ');
      final minutes = int.tryParse(parts[0]) ?? 5;
      final increment = int.tryParse(parts[4]) ?? 3;
      _whitesTime = Duration(minutes: minutes);
      _blacksTime = Duration(minutes: minutes);
      _incrementalValue = increment;
    } else if (timeControl.contains('min')) {
      // Format: "3 min"
      final minutes = int.tryParse(timeControl.split(' ')[0]) ?? 3;
      _whitesTime = Duration(minutes: minutes);
      _blacksTime = Duration(minutes: minutes);
      _incrementalValue = 0;
    }

    // Save initial times
    _savedWhitesTime = _whitesTime;
    _savedBlacksTime = _blacksTime;
  }

  String getFormattedTime(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}:${(duration.inMinutes % 60).toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
    } else {
      return '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
    }
  }

  // Start the timer for the current player
  void _startTimer() {
    _stopTimers(); // Stop any existing timers
    if (_game.state.turn == Squares.white) {
      _playWhitesTimer = true;
      _playBlacksTimer = false;
      _whitesTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_whitesTime.inSeconds > 0) {
          _whitesTime = _whitesTime - const Duration(seconds: 1);
        } else {
          _whitesTime = Duration.zero;
          _gameResultNotifier.value = WonGameTimeout(winner: Squares.black);
          _stopTimers();
          // Use post-frame callback to avoid build-time issues
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _checkGameOver();
          });
        }
        notifyListeners();
      });
    } else {
      _playBlacksTimer = true;
      _playWhitesTimer = false;
      _blacksTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_blacksTime.inSeconds > 0) {
          _blacksTime = _blacksTime - const Duration(seconds: 1);
        } else {
          _blacksTime = Duration.zero;
          _gameResultNotifier.value = WonGameTimeout(winner: Squares.white);
          _stopTimers();
          // Use post-frame callback to avoid build-time issues
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _checkGameOver();
          });
        }
        notifyListeners();
      });
    }
    notifyListeners();
  }

  // Stop both timers
  void _stopTimers() {
    _whitesTimer?.cancel();
    _blacksTimer?.cancel();
    _whitesTimer = null;
    _blacksTimer = null;
    _playWhitesTimer = false;
    _playBlacksTimer = false;
  }

  // Reset the game state
  void resetGame(bool isNewGame) {
    // Change player color if it's a new game
    if (isNewGame) {
      _player = _player == Squares.white ? Squares.black : Squares.white;
      notifyListeners();
    }
    _whitesTime = _savedWhitesTime;
    _blacksTime = _savedBlacksTime;
    _stopTimers(); // Ensure timers are stopped on reset
    _game = bishop.Game(variant: bishop.Variant.standard());
    _state = game.squaresState(player);
    _gameResultNotifier.value = null; // Reset game result
    notifyListeners();
    _startTimer(); // Start timer for the new game
  }

  // Flip the board
  void flipTheBoard() {
    _flipBoard = !_flipBoard;
    notifyListeners();
  }

  // Set AI thinking state
  void setAiThinking(bool thinking) {
    _aiThinking = thinking;
    notifyListeners();
  }

  // Check for game over conditions
  void _checkGameOver() {
    if (_game.gameOver) {
      _stopTimers();
      _gameResultNotifier.value = _game.result;
      notifyListeners();
    } else if (_gameResultNotifier.value != null) {
      // Handle timeout case - game result is set but chess game doesn't know it's over
      _stopTimers();
      notifyListeners();
    }
  }

  // Make squares move
  Future<bool> makeSquaresMove(Move move) async {
    bool result = _game.makeSquaresMove(move);
    if (result) {
      _state = _game.squaresState(_player);
      // Add increment time after a successful move
      if (_incrementalValue > 0) {
        if (_game.state.turn == Squares.white) {
          _blacksTime += Duration(seconds: _incrementalValue);
        } else {
          _whitesTime += Duration(seconds: _incrementalValue);
        }
      }
      _checkGameOver();
      if (!_game.gameOver) {
        _startTimer(); // Restart timer for the next player
      }
      notifyListeners();
    }
    return result;
  }

  // Make a random move for AI
  Future<void> makeRandomMove() async {
    // Check if it's AI's turn and not already thinking
    if (_state.state == PlayState.theirTurn && !_aiThinking) {
      setAiThinking(true);
      await Future.delayed(
        Duration(milliseconds: Random().nextInt(4750) + 250),
      );
      _game.makeRandomMove();
      _state = _game.squaresState(_player);
      // Add increment time after a successful move
      if (_incrementalValue > 0) {
        if (_game.state.turn == Squares.white) {
          _blacksTime += Duration(seconds: _incrementalValue);
        } else {
          _whitesTime += Duration(seconds: _incrementalValue);
        }
      }
      setAiThinking(false);
      _checkGameOver();
      if (!_game.gameOver) {
        _startTimer(); // Restart timer for the next player
      }
      notifyListeners();
    }
  }
}
