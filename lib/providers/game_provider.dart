import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chess_app/models/game_room_model.dart';
import 'package:flutter_chess_app/services/captured_piece_tracker.dart';
import 'package:flutter_chess_app/services/game_service.dart';
import 'package:flutter_chess_app/stockfish/uci_commands.dart';
import 'package:flutter_chess_app/utils/constants.dart';
import 'package:squares/squares.dart';
import 'package:bishop/bishop.dart' as bishop;
import 'package:square_bishop/square_bishop.dart';
import 'package:stockfish/stockfish.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

// Custom game result for timeout
class WonGameTimeout extends bishop.WonGame {
  const WonGameTimeout({required super.winner});
}

// Custom game result for resignation
class WonGameResignation extends bishop.WonGame {
  const WonGameResignation({required super.winner});
}

class GameProvider extends ChangeNotifier {
  late bishop.Game _game = bishop.Game(variant: bishop.Variant.standard());
  late SquaresState _state = SquaresState.initial(0);
  Stockfish? _stockfish;
  bool _aiThinking = false;
  bool _flipBoard = false;
  bool _stockfishInitialized = false;
  final Logger _logger = Logger();

  final GameService _gameService = GameService();
  final Uuid _uuid = const Uuid();

  bool _vsCPU = false;
  bool _localMultiplayer = false;
  bool _isOnlineGame = false;
  bool _isHost = false; // True if this player created the game room
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
  GameRoom? _onlineGameRoom;
  StreamSubscription<GameRoom>? _gameRoomSubscription;

  Duration _whitesTime = Duration.zero;
  Duration _blacksTime = Duration.zero;

  // saved time
  Duration _savedWhitesTime = Duration.zero;
  Duration _savedBlacksTime = Duration.zero;

  // Captured pieces
  // These lists will hold the captured pieces for each player
  // They will be used to display captured pieces in the UI
  // and calculate material advantage
  // They will be updated whenever a piece is captured
  List<String> _whiteCapturedPieces = [];
  List<String> _blackCapturedPieces = [];
  List<String> _moveHistory = [];

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
  bool get localMultiplayer => _localMultiplayer;
  bool get isOnlineGame => _isOnlineGame;
  bool get isHost => _isHost;
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
  GameRoom? get onlineGameRoom => _onlineGameRoom;

  Duration get whitesTime => _whitesTime;
  Duration get blacksTime => _blacksTime;
  Duration get savedWhitesTime => _savedWhitesTime;
  Duration get savedBlacksTime => _savedBlacksTime;

  List<String> get whiteCapturedPieces => _whiteCapturedPieces;
  List<String> get blackCapturedPieces => _blackCapturedPieces;
  List<String> get moveHistory => _moveHistory;

  bishop.GameResult? get gameResult => _gameResultNotifier.value;
  ValueNotifier<bishop.GameResult?> get gameResultNotifier =>
      _gameResultNotifier;

  bool get isGameOver => _game.gameOver || _gameResultNotifier.value != null;

  // Calculate material advantage
  int get materialAdvantage {
    int whitePoints = _calculateMaterialPoints(_whiteCapturedPieces);
    int blackPoints = _calculateMaterialPoints(_blackCapturedPieces);
    return whitePoints - blackPoints;
  }

  // Get material advantage from player's perspective
  int getMaterialAdvantageForPlayer(int playerColor) {
    int advantage = materialAdvantage;
    return playerColor == Squares.white ? advantage : -advantage;
  }

  int _calculateMaterialPoints(List<String> pieces) {
    int points = 0;
    for (String piece in pieces) {
      switch (piece.toLowerCase()) {
        case 'p':
          points += 1;
          break;
        case 'n':
        case 'b':
          points += 3;
          break;
        case 'r':
          points += 5;
          break;
        case 'q':
          points += 9;
          break;
        // King has no point value in material calculation
      }
    }
    return points;
  }

  /// Resigns the current game, setting the game result to a win for the opponent.
  void resignGame() {
    final winner =
        _game.state.turn == Squares.white ? Squares.black : Squares.white;
    _gameResultNotifier.value = WonGameResignation(winner: winner);
    _checkGameOver();
    notifyListeners();
  }

  /// Offers a draw in the current game.
  /// This is a placeholder for future multiplayer implementation.
  void offerDraw() {
    // TODO: Implement draw offer logic for local multiplayer and online play
    _logger.i('Draw offer initiated (placeholder)');
    // For now, we can simulate a draw or do nothing
    // _gameResultNotifier.value = bishop.DrawnGame(reason: bishop.DrawReason.agreement);
    // _checkGameOver();
    // notifyListeners();
  }

  // Initialize Stockfish safely
  Future<void> initializeStockfish() async {
    if (_stockfishInitialized || _localMultiplayer || _isOnlineGame) return;

    try {
      // Initialize Stockfish
      _stockfish = Stockfish();

      // Load Stockfish binary
      await waitForStockfish();

      // Set Stockfish options
      _setupStockfishListener();

      // Set Stockfish to use the default engine
      _stockfishInitialized = true;
    } catch (e) {
      _stockfish = null;
      _stockfishInitialized = false;
    }
  }

  @override
  void dispose() {
    disposeStockfish();
    _stopTimers();
    _gameRoomSubscription?.cancel();
    super.dispose();
  }

  // Disposes the Stockfish engine instance and resets the initialization flag.
  // This is useful for cleaning up when a CPU game ends and the user
  // wants to return to the main menu, without destroying the GameProvider.
  void disposeStockfish() {
    if (_stockfish != null) {
      _stockfish!.dispose();
      _stockfish = null;
      _stockfishInitialized = false;
      _logger.i('Stockfish engine disposed.');
    }
  }

  void setVsCPU(bool value) {
    _vsCPU = value;
    _isOnlineGame = false;
    _localMultiplayer = false;
    notifyListeners();
  }

  void setLocalMultiplayer(bool value) {
    _localMultiplayer = value;
    _isOnlineGame = false; // Cannot be both local and online
    _vsCPU = false;
    notifyListeners();
  }

  void setIsOnlineGame(bool value) {
    _isOnlineGame = value;
    _localMultiplayer = false; // Cannot be both local and online
    _vsCPU = false;
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
    _stopTimers();
    _gameResultNotifier.value = null;
    _gameRoomSubscription
        ?.cancel(); // Cancel any active online game subscription

    // Clear captured pieces and move history
    _whiteCapturedPieces.clear();
    _blackCapturedPieces.clear();
    _moveHistory.clear();

    // Change player color if it's a new game
    if (isNewGame) {
      _player = _player == Squares.white ? Squares.black : Squares.white;
      notifyListeners();
    }

    _whitesTime = _savedWhitesTime;
    _blacksTime = _savedBlacksTime;

    _game = bishop.Game(variant: bishop.Variant.standard());

    // Initialize state correctly for local multiplayer or online game
    if (_localMultiplayer || _isOnlineGame) {
      // Start with white's turn
      final currentTurn = _game.state.turn; // This will be white initially
      final dynamicState = _game.squaresState(currentTurn);
      final baseState = _game.squaresState(_player);

      _state = SquaresState(
        player: currentTurn,
        state: PlayState.ourTurn,
        size: dynamicState.size,
        board: baseState.board,
        moves: dynamicState.moves,
        history: dynamicState.history,
        hands: dynamicState.hands,
        gates: dynamicState.gates,
      );
    } else {
      _state = _game.squaresState(_player);
    }

    notifyListeners();

    // Lets add a delay to start timer - not starting it immediately
    // Allow white to think for a bit before starting the timer
    Future.delayed(const Duration(milliseconds: 500), () {
      _startTimer();
    });

    // If player is black and playing vs CPU, let CPU make the first move
    if (_vsCPU && _player == Squares.black && !_localMultiplayer) {
      makeStockfishMove();
    }
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
      // Track move in algebraic notation
      if (_game.history.isNotEmpty) {
        String moveNotation = _getMoveNotation(move);
        if (moveNotation.isNotEmpty) {
          _moveHistory.add(moveNotation);
        }
      }

      if (_localMultiplayer || _isOnlineGame) {
        // For local multiplayer or online, dynamically create state based on current turn
        final currentTurn = _game.state.turn;

        // Create state from the perspective of whoever's turn it is
        final dynamicState = _game.squaresState(currentTurn);

        // But we need to adjust the board orientation to match our display
        final baseState = _game.squaresState(_player);

        _state = SquaresState(
          player: currentTurn, // We set to current turn so moves work correctly
          state:
              PlayState
                  .ourTurn, // We always "our turn" since we're showing from current player's perspective
          size: dynamicState.size,
          board:
              baseState
                  .board, // We keep the board orientation consistent with display
          moves:
              dynamicState
                  .moves, // We use moves from current turn's perspective
          history: dynamicState.history,
          hands: dynamicState.hands,
          gates: dynamicState.gates,
        );
      } else {
        // For other modes, we use the standard approach
        _state = _game.squaresState(_player);
      }

      // Add increment time after a successful move
      if (_incrementalValue > 0) {
        if (_game.state.turn == Squares.white) {
          _blacksTime += Duration(seconds: _incrementalValue);
        } else {
          _whitesTime += Duration(seconds: _incrementalValue);
        }
      }
      debugPieceSymbols(); // Debugging piece symbols after the move
      // Update captured pieces after the move
      updateCapturedPieces();
      _checkGameOver();

      // If online game, update Firestore
      if (_isOnlineGame && _onlineGameRoom != null) {
        final updatedMoves = List<String>.from(_onlineGameRoom!.moves);
        updatedMoves.add(move.toString()); // Store move as string

        await _gameService.updateGameRoom(_onlineGameRoom!.gameId, {
          Constants.fieldFen: _game.fen,
          Constants.fieldMoves: updatedMoves,
          Constants.fieldLastMoveAt: Timestamp.now(),
          Constants.fieldWhitesTimeRemaining: _whitesTime.inMilliseconds,
          Constants.fieldBlacksTimeRemaining: _blacksTime.inMilliseconds,
        });
      }

      if (!_game.gameOver) {
        _startTimer(); // Restart timer for the next player
      }
      notifyListeners();
    }

    _logger.i('Move made: ${move.from} to ${move.to}, result: $result');
    return result;
  }

  // Helper method to convert move to algebraic notation (for local history)
  String _getMoveNotation(Move move) {
    // Use bishop's toAlgebraic for more complete notation
    return move.algebraic();
  }

  // convert move string to move format
  Move _convertMoveStringToMove({required String moveString}) {
    // Split the move string intp its components
    List<String> parts = moveString.split('-');

    // Extract 'from' and 'to'
    int from = int.parse(parts[0]);
    int to = int.parse(parts[1].split('[')[0]);

    // Extract 'promo' and 'piece' if available
    String? promo;
    String? piece;
    if (moveString.contains('[')) {
      String extras = moveString.split('[')[1].split(']')[0];
      List<String> extraList = extras.split(',');
      promo = extraList[0];
      if (extraList.length > 1) {
        piece = extraList[1];
      }
    }

    // Create and return a new Move object
    return Move(from: from, to: to, promo: promo, piece: piece);
  }

  void updateCapturedPieces() {
    try {
      // Get current FEN from your game
      String currentFEN = _game.fen;

      Map<String, List<String>> captured =
          CapturedPiecesTracker.getCapturedPieces(currentFEN);

      _whiteCapturedPieces = captured['whiteCaptured']!;
      _blackCapturedPieces = captured['blackCaptured']!;

      _logger.i(
        'Captured pieces updated: '
        'White captured: ${_whiteCapturedPieces.join(', ')}, '
        'Black captured: ${_blackCapturedPieces.join(', ')}',
      );
    } catch (e) {
      _logger.e('Error updating captured pieces: $e');
      // Fallback to empty lists if there's an error
      _whiteCapturedPieces.clear();
      _blackCapturedPieces.clear();
    }
  }

  void debugPieceSymbols() {
    final variant = _game.variant;

    _logger.i('=== DEBUG: Current board piece symbols ===');
    for (int i = 0; i < _game.board.length; i++) {
      var piece = _game.board[i];
      if (piece == 0) continue;

      String symbol = variant.pieceSymbol(piece & 7);
      int colour = (piece >> 3) & 1;
      String colourName = colour == Squares.white ? 'White' : 'Black';

      _logger.i('Square $i: $colourName $symbol (raw: $piece)');
    }
    _logger.i('=== END DEBUG ===');
  }

  // Helper method to convert square index to algebraic notation
  String _squareToAlgebraic(int square) {
    final file = square % 8;
    final rank = square ~/ 8;
    final fileChar = String.fromCharCode('a'.codeUnitAt(0) + file);
    final rankChar = (rank + 1).toString();
    return '$fileChar$rankChar';
  }

  // Wait until Stockfish is ready
  Future<void> waitForStockfish() async {
    // If Stockfish is not initialized, do nothing
    if (_stockfish == null) return;

    // Wait until Stockfish is ready
    // Add timeout to prevent infinite waiting
    int attempts = 0;
    const maxAttempts = 60; // 30 seconds max

    while (_stockfish!.state.value != StockfishState.ready &&
        attempts < maxAttempts) {
      // Wait for a short duration before checking again
      await Future.delayed(const Duration(milliseconds: 500));
      attempts++;
    }

    if (attempts >= maxAttempts) {
      throw Exception('Stockfish initialization timeout');
    }
  }

  // Make a move using Stockfish AI
  Future<void> makeStockfishMove() async {
    if (_stockfish == null || !_stockfishInitialized) {
      _logger.i('Stockfish not initialized, skipping AI move');
      return;
    }

    try {
      await waitForStockfish();

      // Check if it's AI's turn
      bool isAiTurn =
          _state.state == PlayState.theirTurn ||
          (_vsCPU && _player == Squares.black && _game.state.moveNumber == 1);

      if (isAiTurn && !_aiThinking) {
        _logger.i('AI is thinking...');
        setAiThinking(true);

        // Get current position in FEN format
        _stockfish!.stdin = '${UCICommands.position} ${_game.fen}';

        // Set Stockfish difficulty level
        _stockfish!.stdin = '${UCICommands.goMoveTime} ${_gameLevel * 1000}';
      }
    } catch (e) {
      _logger.e('Error making Stockfish move: $e');
      setAiThinking(false);
    }
  }

  void _setupStockfishListener() {
    if (_stockfish == null) return;

    _stockfish!.stdout.listen((event) {
      _logger.i('Stockfish output: $event');

      // Check if it's AI's turn and not already thinking
      bool isAiTurn =
          _state.state == PlayState.theirTurn ||
          (_vsCPU && _player == Squares.black && _game.state.moveNumber == 1);

      _logger.i('Is AI turn: $isAiTurn, AI thinking: $_aiThinking');

      if (isAiTurn && _aiThinking && event.contains(UCICommands.bestMove)) {
        // Extract the best move from Stockfish output
        final bestMove = event.split(' ')[1];
        _logger.i('Best move from Stockfish: $bestMove');

        // Make the move in the game
        _game.makeMoveString(bestMove);

        setAiThinking(false);

        _state = _game.squaresState(_player);

        // Add increment time after a successful move
        if (_incrementalValue > 0) {
          if (_game.state.turn == Squares.white) {
            _blacksTime += Duration(seconds: _incrementalValue);
          } else {
            _whitesTime += Duration(seconds: _incrementalValue);
          }
        }

        _logger.i('Move made: $bestMove');

        _checkGameOver();
        if (!_game.gameOver) {
          _startTimer(); // Restart timer for the next player
        }
        notifyListeners();
      }
    });
  }

  /// Initiates the online game search or creation process.
  Future<void> startOnlineGameSearch({
    required String userId,
    required String displayName,
    String? photoUrl,
    required int userRating,
    required String gameMode,
    required bool ratingBasedSearch,
  }) async {
    setLoading(true);
    setIsOnlineGame(true); // Set online game mode

    try {
      // Try to find an available game
      GameRoom? foundGame = await _gameService.findAvailableGame(
        gameMode: gameMode,
        userRating: userRating,
        ratingBasedSearch: ratingBasedSearch,
      );

      if (foundGame != null) {
        // Join existing game
        _isHost = false;
        _onlineGameRoom = foundGame;
        _gameId = foundGame.gameId;
        _player = Squares.black; // Joining player is Black

        await _gameService.joinGameRoom(
          gameId: foundGame.gameId,
          player2Id: userId,
          player2DisplayName: displayName,
          player2PhotoUrl: photoUrl,
          player2Rating: userRating,
        );
        _logger.i('Joined game: ${foundGame.gameId}');
      } else {
        // No game found, create a new one
        _isHost = true;
        _player = Squares.white; // Creating player is White

        _onlineGameRoom = await _gameService.createGameRoom(
          gameMode: gameMode,
          player1Id: userId,
          player1DisplayName: displayName,
          player1PhotoUrl: photoUrl,
          player1Rating: userRating,
          ratingBasedSearch: ratingBasedSearch,
          initialWhitesTime: _savedWhitesTime.inMilliseconds,
          initialBlacksTime: _savedBlacksTime.inMilliseconds,
        );
        _gameId = _onlineGameRoom!.gameId;
        _logger.i('Created new game: ${_onlineGameRoom!.gameId}');
      }

      // Set up real-time listener for the game room
      _gameRoomSubscription = _gameService
          .streamGameRoom(_gameId)
          .listen(
            _onOnlineGameRoomUpdate,
            onError: (error) {
              _logger.e('Error streaming game room $_gameId: $error');
              // Handle error, e.g., show a snackbar
            },
            onDone: () {
              _logger.i('Game room $_gameId stream closed.');
            },
          );

      // Initialize game state based on the online game room
      _whitesTime = Duration(milliseconds: _onlineGameRoom!.initialWhitesTime);
      _blacksTime = Duration(milliseconds: _onlineGameRoom!.initialBlacksTime);
      _game = bishop.Game(fen: _onlineGameRoom!.fen);
      _state = _game.squaresState(_player);

      // Apply historical moves if any
      for (var moveString in _onlineGameRoom!.moves) {
        _game.makeSquaresMove(_convertMoveStringToMove(moveString: moveString));
      }

      // Start timer if game is active
      if (_onlineGameRoom!.status == 'active') {
        _startTimer();
      }

      setLoading(false);
      notifyListeners();
    } catch (e) {
      _logger.e('Error during online game search/creation: $e');
      setLoading(false);
      // Handle error, e.g., show a snackbar
      rethrow;
    }
  }

  /// Handles updates received from the online game room stream.
  void _onOnlineGameRoomUpdate(GameRoom updatedRoom) {
    _onlineGameRoom = updatedRoom;
    _gameId = updatedRoom.gameId;

    // Update local game state based on Firestore updates
    // Only update if the FEN has changed (meaning a move was made by opponent)
    if (_game.fen != updatedRoom.fen) {
      _game = bishop.Game(fen: updatedRoom.fen);
      _state = _game.squaresState(_player);

      // Update local timers based on Firestore
      _whitesTime = Duration(milliseconds: updatedRoom.initialWhitesTime);
      _blacksTime = Duration(milliseconds: updatedRoom.initialBlacksTime);

      // Re-apply moves to ensure local history matches Firestore
      _moveHistory.clear();
      for (var moveString in updatedRoom.moves) {
        final move = _convertMoveStringToMove(moveString: moveString);
        _game.makeSquaresMove(move); // Re-apply moves to update game state
        _moveHistory.add(_getMoveNotation(move)); // Update local move history
      }

      updateCapturedPieces(); // Update captured pieces based on new FEN
      _checkGameOver(); // Check for game over conditions

      if (!_game.gameOver) {
        _startTimer(); // Restart timer for the next player
      }
    }

    // Handle status changes (e.g., opponent joined, game ended)
    if (updatedRoom.status == Constants.statusActive && !_game.gameOver) {
      _startTimer(); // Ensure timer is running if game becomes active
    } else if (updatedRoom.status == Constants.statusCompleted ||
        updatedRoom.status == Constants.statusAborted) {
      _stopTimers();
      // Potentially set game result based on winnerId or status
      if (updatedRoom.winnerId != null) {
        final winnerColor =
            updatedRoom.player1Id == updatedRoom.winnerId
                ? updatedRoom.player1Color
                : updatedRoom.player2Color;
        _gameResultNotifier.value = WonGameResignation(winner: winnerColor!);
      } else if (updatedRoom.drawOfferedBy != null) {
        _gameResultNotifier.value = bishop.DrawnGame();
      }
      _checkGameOver();
    }

    notifyListeners();
  }
}
