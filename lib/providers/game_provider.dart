import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chess_app/models/game_room_model.dart';
import 'package:flutter_chess_app/models/saved_game_model.dart';
import 'package:flutter_chess_app/models/user_model.dart';
import 'package:flutter_chess_app/services/captured_piece_tracker.dart';
import 'package:flutter_chess_app/services/chat_service.dart';
import 'package:flutter_chess_app/services/friend_service.dart';
import 'package:flutter_chess_app/services/game_service.dart';
import 'package:flutter_chess_app/services/saved_game_service.dart';
import 'package:flutter_chess_app/services/user_service.dart';
import 'package:flutter_chess_app/stockfish/uci_commands.dart';
import 'package:flutter_chess_app/utils/constants.dart';
import 'package:flutter_chess_app/widgets/loading_dialog.dart';
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

// Custom game result for draw by agreement
class DrawnGameAgreement extends bishop.DrawnGame {
  const DrawnGameAgreement();

  @override
  String toString() => 'DrawnGameAgreement';

  @override
  String get readable => '${super.readable} by agreement';
}

// Custom game result for aborted game
class WonGameAborted extends bishop.WonGame {
  const WonGameAborted({required super.winner});
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
  final SavedGameService _savedGameService = SavedGameService();
  final UserService _userService = UserService();
  final ChatService _chatService = ChatService();
  final FriendService _friendService = FriendService();

  bool _vsCPU = false;
  bool _localMultiplayer = false;
  bool _isOnlineGame = false;
  bool _isHost = false; // True if this player created the game room
  bool _isLoading = false;
  bool _isOpponentFriend = false;
  bool _playWhitesTimer = true;
  bool _playBlacksTimer = true;
  int _gameLevel = 1;
  int _incrementalValue = 0;
  int _player = Squares.white;
  Timer? _whitesTimer;
  Timer? _blacksTimer;
  Timer? _firstMoveCountdownTimer;
  int _whitesScore = 0;
  int _blacksScore = 0;
  String _gameId = '';
  String _selectedTimeControl = '';
  GameRoom? _onlineGameRoom;
  StreamSubscription<GameRoom>? gameRoomSubscription;
  StreamSubscription<List<ChessUser>>? _friendRequestSubscription;

  bool _drawOfferReceived = false;
  bool _friendRequestReceived = false;
  String? _friendRequestSenderId;
  bool _scoresUpdatedForCurrentGame = false;

  Duration _whitesTime = Duration.zero;
  Duration _blacksTime = Duration.zero;

  // saved time
  Duration _savedWhitesTime = Duration.zero;
  Duration _savedBlacksTime = Duration.zero;

  // Time control variables
  Duration? _timePerMove;
  Duration? _bonusTime;
  Duration? _bonusThreshold;
  DateTime? _turnStartTime;

  // Online game scores
  int _player1OnlineScore = 0;
  int _player2OnlineScore = 0;

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
  Logger get logger => _logger;

  bool get vsCPU => _vsCPU;
  bool get localMultiplayer => _localMultiplayer;
  bool get isOnlineGame => _isOnlineGame;
  bool get isHost => _isHost;
  bool get isLoading => _isLoading;
  bool get isOpponentFriend => _isOpponentFriend;
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

  int get player1OnlineScore => _player1OnlineScore;
  int get player2OnlineScore => _player2OnlineScore;

  List<String> get whiteCapturedPieces => _whiteCapturedPieces;
  List<String> get blackCapturedPieces => _blackCapturedPieces;
  List<String> get moveHistory => _moveHistory;

  ChatService get chatService => _chatService;

  GameService get gameService => _gameService;

  bool get drawOfferReceived => _drawOfferReceived;
  bool get friendRequestReceived => _friendRequestReceived;
  String? get friendRequestSenderId => _friendRequestSenderId;

  StreamSubscription<GameRoom>? get geGgameRoomSubscription =>
      gameRoomSubscription;

  bishop.GameResult? get gameResult => _gameResultNotifier.value;
  ValueNotifier<bishop.GameResult?> get gameResultNotifier =>
      _gameResultNotifier;

  bool get isGameOver => _game.gameOver || _gameResultNotifier.value != null;

  // First move countdown getters - now handled by the widget

  int get firstMoveCountdownPlayer {
    if (!_isOnlineGame || _onlineGameRoom == null) return Squares.white;

    if (_onlineGameRoom!.moves.isEmpty) {
      return Squares.white; // White's turn for first move
    } else if (_onlineGameRoom!.moves.length == 1) {
      return Squares.black; // Black's turn for first move
    }
    return Squares.white; // Default
  }

  // Helper to check if we should show first move countdown
  bool get shouldShowFirstMoveCountdown {
    if (!_isOnlineGame || _onlineGameRoom == null) return false;

    return _onlineGameRoom!.status == Constants.statusActive &&
        _onlineGameRoom!.moves.length <= 1;
  }

  // Calculate material advantage
  int get materialAdvantage {
    int whitePoints = _calculateMaterialPoints(_whiteCapturedPieces);
    int blackPoints = _calculateMaterialPoints(_blackCapturedPieces);
    return whitePoints - blackPoints;
  }

  // Get material advantage from player's perspective
  int getMaterialAdvantageForPlayer(int? playerColor) {
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
  Future<void> resignGame({String? userId}) async {
    final winnerColor =
        _game.state.turn == Squares.white ? Squares.black : Squares.white;
    final winnerId =
        _isOnlineGame && _onlineGameRoom != null
            ? (_isHost
                ? _onlineGameRoom!.player2Id
                : _onlineGameRoom!.player1Id)
            : null; // For local/CPU, winnerId is not relevant for Firestore

    _gameResultNotifier.value = WonGameResignation(winner: winnerColor);
    _stopTimers(); // Stop timers immediately on resignation

    if (_isOnlineGame && _onlineGameRoom != null && winnerId != null) {
      await _gameService.resignGame(_onlineGameRoom!.gameId, winnerId);
    }

    // Ensure the game is saved when resigned
    if (userId != null) {
      checkGameOver(userId: userId);
    }

    notifyListeners();
  }

  /// Ends the game as a draw. This is used for local multiplayer draw agreements.
  void endGameAsDraw() {
    _gameResultNotifier.value = const DrawnGameAgreement();
    _stopTimers();
    checkGameOver();
    notifyListeners();
  }

  /// Offers a draw in the current game.
  Future<void> offerDraw() async {
    // For local multiplayer, the draw is handled in the UI (_showDrawOfferDialog)
    // and calls endGameAsDraw() directly.
    // This method is now only for online games.
    if (_localMultiplayer) {
      return;
    }
    if (!_isOnlineGame || _onlineGameRoom == null) {
      _logger.w('Draw offer only available in online games.');
      return;
    }

    final String offeringPlayerId =
        _isHost ? _onlineGameRoom!.player1Id : _onlineGameRoom!.player2Id!;

    await _gameService.offerDraw(_onlineGameRoom!.gameId, offeringPlayerId);
    _logger.i('Draw offer initiated by $offeringPlayerId');
    notifyListeners();
  }

  /// Handles a draw offer (accept or decline).
  Future<void> handleDrawOffer(bool accepted) async {
    if (!_isOnlineGame || _onlineGameRoom == null) {
      _logger.w('Cannot handle draw offer: Not an online game.');
      return;
    }
    // When an offer is handled, the widget should disappear.
    _drawOfferReceived = false;

    if (accepted) {
      // Set the game result to draw by agreement
      _gameResultNotifier.value = DrawnGameAgreement();
    }

    await _gameService.handleDrawOffer(_onlineGameRoom!.gameId, accepted);
    if (!accepted) {
      // If declined, ensure the timer for the current player continues.
      _startTimer();
    }
    notifyListeners();
  }

  /// Offers a rematch after a game.
  Future<void> offerRematch() async {
    if (!_isOnlineGame || _onlineGameRoom == null) {
      _logger.w('Rematch offer only available in online games.');
      return;
    }

    final String offeringPlayerId =
        _isHost ? _onlineGameRoom!.player1Id : _onlineGameRoom!.player2Id!;

    await _gameService.offerRematch(_onlineGameRoom!.gameId, offeringPlayerId);
    _logger.i('Rematch offer initiated by $offeringPlayerId');
    notifyListeners();
  }

  /// Handles a rematch offer (accept or decline).
  Future<void> handleRematch(bool accepted) async {
    if (!_isOnlineGame || _onlineGameRoom == null) {
      _logger.w('Cannot handle rematch offer: Not an online game.');
      return;
    }

    // Pass the most up-to-date local scores.
    await _gameService.handleRematch(
      _onlineGameRoom!.gameId,
      accepted,
      _player1OnlineScore,
      _player2OnlineScore,
    );
    //notifyListeners();
  }

  /// Handles a friend request (accept or decline).
  Future<void> handleFriendRequest(
    String currentUserId,
    String friendUserId,
    bool accepted,
  ) async {
    if (accepted) {
      await _friendService.acceptFriendRequest(
        currentUserId: currentUserId,
        friendUserId: friendUserId,
      );
      _isOpponentFriend = true;
    } else {
      await _friendService.declineFriendRequest(
        currentUserId: currentUserId,
        friendUserId: friendUserId,
      );
    }
    _friendRequestReceived = false;
    _friendRequestSenderId = null;
    notifyListeners();
  }

  // Audio Room Management Methods

  /// Invites the opponent to join the audio room
  Future<void> inviteToAudioRoom(String currentUserId) async {
    if (!_isOnlineGame || _onlineGameRoom == null) {
      _logger.w('Audio room invitation only available in online games.');
      return;
    }

    await _gameService.inviteToAudioRoom(
      _onlineGameRoom!.gameId,
      currentUserId,
    );
    _logger.i('Audio room invitation sent by $currentUserId');
    notifyListeners();
  }

  /// Handles an audio room invitation (accept or decline)
  Future<void> handleAudioRoomInvitation(
    String currentUserId,
    bool accepted,
  ) async {
    if (!_isOnlineGame || _onlineGameRoom == null) {
      _logger.w('Cannot handle audio room invitation: Not an online game.');
      return;
    }

    await _gameService.handleAudioRoomInvitation(
      _onlineGameRoom!.gameId,
      currentUserId,
      accepted,
    );
    _logger.i(
      'Audio room invitation ${accepted ? 'accepted' : 'declined'} by $currentUserId',
    );
    notifyListeners();
  }

  /// Joins the audio room
  Future<void> joinAudioRoom(String currentUserId) async {
    if (!_isOnlineGame || _onlineGameRoom == null) {
      _logger.w('Cannot join audio room: Not an online game.');
      return;
    }

    await _gameService.joinAudioRoom(_onlineGameRoom!.gameId, currentUserId);
    _logger.i('User $currentUserId joined audio room');
    notifyListeners();
  }

  /// Leaves the audio room
  Future<void> leaveAudioRoom(String currentUserId) async {
    if (!_isOnlineGame || _onlineGameRoom == null) {
      _logger.w('Cannot leave audio room: Not an online game.');
      return;
    }

    await _gameService.leaveAudioRoom(_onlineGameRoom!.gameId, currentUserId);
    _logger.i('User $currentUserId left audio room');
    notifyListeners();
  }

  /// Ends the audio room for all participants
  Future<void> endAudioRoom(String currentUserId) async {
    if (!_isOnlineGame || _onlineGameRoom == null) {
      _logger.w('Cannot end audio room: Not an online game.');
      return;
    }

    await _gameService.endAudioRoom(_onlineGameRoom!.gameId, currentUserId);
    _logger.i('Audio room ended by $currentUserId');
    notifyListeners();
  }

  /// Checks if the current user is in the audio room
  bool isUserInAudioRoom(String userId) {
    if (_onlineGameRoom == null) return false;
    return _onlineGameRoom!.audioRoomParticipants.contains(userId);
  }

  /// Checks if there's a pending audio room invitation for the current user
  bool hasAudioRoomInvitation(String userId) {
    if (_onlineGameRoom == null) return false;
    return _onlineGameRoom!.audioRoomStatus ==
            Constants.audioStatusInvitePending &&
        _onlineGameRoom!.audioRoomInvitedBy != userId;
  }

  /// Gets the user who invited to the audio room
  String? getAudioRoomInviter() {
    if (_onlineGameRoom == null) return null;
    return _onlineGameRoom!.audioRoomInvitedBy;
  }

  /// Gets the current audio room status
  String getAudioRoomStatus() {
    if (_onlineGameRoom == null) return Constants.audioStatusNone;
    return _onlineGameRoom!.audioRoomStatus;
  }

  /// Gets the list of audio room participants
  List<String> getAudioRoomParticipants() {
    if (_onlineGameRoom == null) return [];
    return _onlineGameRoom!.audioRoomParticipants;
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
    gameRoomSubscription?.cancel();
    _friendRequestSubscription?.cancel();
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

  Future<void> setVsCPU(bool value) async {
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
    // Reset all time control variables
    _timePerMove = null;
    _bonusTime = null;
    _bonusThreshold = null;
    _incrementalValue = 0;

    if (timeControl.contains('sec/move')) {
      // Format: "60 sec/move"
      final seconds = int.tryParse(timeControl.split(' ')[0]) ?? 60;
      _timePerMove = Duration(seconds: seconds);
      _whitesTime = _timePerMove!;
      _blacksTime = _timePerMove!;
    } else if (timeControl.contains('bonus')) {
      // Format: "3 min + 5s bonus 3s"
      final parts = timeControl.replaceAll('s', '').split(' ');
      final minutes = int.tryParse(parts[0]) ?? 3;
      final bonusSeconds = int.tryParse(parts[3]) ?? 5;
      final thresholdSeconds = int.tryParse(parts[5]) ?? 3;
      _whitesTime = Duration(minutes: minutes);
      _blacksTime = Duration(minutes: minutes);
      _bonusTime = Duration(seconds: bonusSeconds);
      _bonusThreshold = Duration(seconds: thresholdSeconds);
    } else if (timeControl.contains('min + ') && timeControl.contains('sec')) {
      // Format: "5 min + 3 sec" - Legacy increment
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
    _turnStartTime = DateTime.now();

    if (_timePerMove != null) {
      if (_game.state.turn == Squares.white) {
        _whitesTime = _timePerMove!;
      } else {
        _blacksTime = _timePerMove!;
      }
    }

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
            final String? userId =
                _isOnlineGame && _onlineGameRoom != null
                    ? (_isHost
                        ? _onlineGameRoom!.player1Id
                        : _onlineGameRoom!.player2Id)
                    : null;
            checkGameOver(userId: userId);
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
            final String? userId =
                _isOnlineGame && _onlineGameRoom != null
                    ? (_isHost
                        ? _onlineGameRoom!.player1Id
                        : _onlineGameRoom!.player2Id)
                    : null;
            checkGameOver(userId: userId);
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
    _firstMoveCountdownTimer?.cancel();
    _whitesTimer = null;
    _blacksTimer = null;
    _firstMoveCountdownTimer = null;
    _playWhitesTimer = false;
    _playBlacksTimer = false;
  }

  // Reset the game state
  void resetGame(bool isNewGame) {
    _scoresUpdatedForCurrentGame = false; // Reset for the new game
    _stopTimers();
    _gameResultNotifier.value = null;
    // For online games, the subscription should persist to receive updates.
    // It is cancelled in dispose() or cancelOnlineGameSearch().

    // Clear captured pieces and move history
    _whiteCapturedPieces.clear();
    _blackCapturedPieces.clear();
    _moveHistory.clear();

    // Reset scores only if it's a completely new game, not a rematch
    if (isNewGame) {
      if (_isOnlineGame) {
        _player1OnlineScore = 0;
        _player2OnlineScore = 0;
      } else {
        _whitesScore = 0;
        _blacksScore = 0;
      }
    }

    // For a rematch or new game, swap sides.
    if (isNewGame) {
      _player = _player == Squares.white ? Squares.black : Squares.white;
    }

    // For online games, times are set from the GameRoom update
    if (!_isOnlineGame) {
      if (_timePerMove != null) {
        _whitesTime = _timePerMove!;
        _blacksTime = _timePerMove!;
      } else {
        _whitesTime = _savedWhitesTime;
        _blacksTime = _savedBlacksTime;
      }
    }

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
  void checkGameOver({String? userId}) {
    if (isGameOver) {
      _stopTimers();
      if (_gameResultNotifier.value == null) {
        _gameResultNotifier.value = _game.result;
      }

      // Update scores for online games when the game officially ends.
      if (_isOnlineGame && _onlineGameRoom != null) {
        _updateOnlineScoresOnGameOver();
      }

      notifyListeners();

      // Save game and update user stats for all game types (not just online)
      // For local games, we'll use a placeholder userId if none provided
      String gameUserId = userId ?? 'local_user';
      if (gameUserId.isNotEmpty && gameUserId != 'local_user') {
        _saveCurrentGame(gameUserId);
      } else if (_vsCPU || _localMultiplayer) {
        // For CPU and local multiplayer games, save with a generic user ID
        // This ensures all games are tracked in the saved games collection
        _saveCurrentGame('local_user');
      }
    }
  }

  // Make squares move
  Future<bool> makeSquaresMove(Move move, {String userId = ''}) async {
    // In online games, ensure it's the player's turn to move.
    if (_isOnlineGame) {
      final isOurTurn = _game.state.turn == _player;

      // Prevent non-white players from making the first move when no moves have been made
      if (_onlineGameRoom!.moves.isEmpty && _player != Squares.white) {
        _logger.w(
          'Only white can make the first move. Current player color: $_player',
        );
        return false;
      }

      if (!isOurTurn) {
        _logger.w('Not your turn to move.');
        return false; // Prevent move if it's not our turn
      }
    }

    // First move countdown is now handled by the widget

    bool result = _game.makeSquaresMove(move);
    if (result) {
      // Track move in algebraic notation
      if (_game.history.isNotEmpty) {
        String moveNotation = _getMoveNotation(move);
        if (moveNotation.isNotEmpty) {
          _moveHistory.add(moveNotation);
        }
      }

      // Update state based on game type
      if (_localMultiplayer) {
        // For local multiplayer, dynamically create state based on current turn
        final currentTurn = _game.state.turn;
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
      } else if (_isOnlineGame) {
        // For online games, update state from our player's perspective
        _state = _game.squaresState(_player);
      } else {
        // For other modes, use the standard approach
        _state = _game.squaresState(_player);
      }

      // Add increment/bonus time after a successful move
      if (_timePerMove != null) {
        // For per-move modes, the timer is reset in _startTimer for the next player
      } else if (_bonusTime != null &&
          _bonusThreshold != null &&
          _turnStartTime != null) {
        final moveDuration = DateTime.now().difference(_turnStartTime!);
        if (moveDuration <= _bonusThreshold!) {
          if (_game.state.turn == Squares.white) {
            // Bonus for black who just moved
            _blacksTime += _bonusTime!;
          } else {
            // Bonus for white who just moved
            _whitesTime += _bonusTime!;
          }
        }
      } else if (_incrementalValue > 0) {
        if (_game.state.turn == Squares.white) {
          _blacksTime += Duration(seconds: _incrementalValue);
        } else {
          _whitesTime += Duration(seconds: _incrementalValue);
        }
      }

      //debugPieceSymbols(); // Debugging piece symbols after the move
      // Update captured pieces after the move
      updateCapturedPieces();

      // If online game, update Firestore
      if (_isOnlineGame && _onlineGameRoom != null) {
        final updatedMoves = List<String>.from(_onlineGameRoom!.moves);
        updatedMoves.add(move.toString()); // Store move as string

        // First move countdown transitions are now handled by the widget

        final Map<String, dynamic> updateData = {
          Constants.fieldFen: _game.fen,
          Constants.fieldMoves: updatedMoves,
          Constants.fieldLastMoveAt: Timestamp.now(),
          Constants.fieldWhitesTimeRemaining: _whitesTime.inMilliseconds,
          Constants.fieldBlacksTimeRemaining: _blacksTime.inMilliseconds,
        };

        if (_game.gameOver) {
          updateData[Constants.fieldStatus] = Constants.statusCompleted;
          final winner = (_game.result as bishop.WonGame).winner;
          updateData[Constants.fieldWinnerId] =
              (winner == _onlineGameRoom!.player1Color)
                  ? _onlineGameRoom!.player1Id
                  : _onlineGameRoom!.player2Id;
        }

        await _gameService.updateGameRoom(_onlineGameRoom!.gameId, updateData);

        _logger.i(
          'Online game updated: ${_onlineGameRoom!.gameId}, '
          'moves: $updatedMoves, '
          'fen: ${_game.fen}',
        );
      }

      // Check game over after all updates, passing userId if available
      final String? userId =
          _isOnlineGame && _onlineGameRoom != null
              ? (_isHost
                  ? _onlineGameRoom!.player1Id
                  : _onlineGameRoom!.player2Id)
              : null;
      checkGameOver(userId: userId);

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

        // Add increment/bonus time after a successful move
        if (_timePerMove != null) {
          // For per-move modes, the timer is reset in _startTimer for the next player
        } else if (_bonusTime != null &&
            _bonusThreshold != null &&
            _turnStartTime != null) {
          final moveDuration = DateTime.now().difference(_turnStartTime!);
          if (moveDuration <= _bonusThreshold!) {
            if (_game.state.turn == Squares.white) {
              // Bonus for black who just moved
              _blacksTime += _bonusTime!;
            } else {
              // Bonus for white who just moved
              _whitesTime += _bonusTime!;
            }
          }
        } else if (_incrementalValue > 0) {
          if (_game.state.turn == Squares.white) {
            _blacksTime += Duration(seconds: _incrementalValue);
          } else {
            _whitesTime += Duration(seconds: _incrementalValue);
          }
        }

        _logger.i('Move made: $bestMove');

        // For CPU games, we need to pass a user ID to ensure the game is saved
        checkGameOver(userId: 'cpu_game_user');
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
    required String playerFlag,
    required int userRating,
    required String gameMode,
    required bool ratingBasedSearch,
    BuildContext? context,
  }) async {
    setLoading(true);
    setIsOnlineGame(true); // Set online game mode

    setTimeControl(gameMode);

    try {
      if (context != null) {
        updateLoadingMessage(
          context,
          'Searching for available games...',
          showCancelButton: true,
        );
      }

      // Try to find an available game
      GameRoom? foundGame = await _gameService.findAvailableGame(
        gameMode: gameMode,
        userRating: userRating,
        ratingBasedSearch: ratingBasedSearch,
        currentUserId: userId,
      );

      if (foundGame != null) {
        // Check if the opponent is a friend before joining
        _isOpponentFriend = await _friendService.isFriend(
          userId,
          foundGame.player1Id,
        );
        // Update message when joining
        if (context != null) {
          updateLoadingMessage(
            context,
            'Joining game...',
            showCancelButton: false,
          );
        }

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
          player2Flag: playerFlag,
          player2Rating: userRating,
        );
        _logger.i('Joined game: ${foundGame.gameId}');

        // Update message when game is ready
        if (context != null) {
          updateLoadingMessage(
            context,
            'Game ready! Starting...',
            showCancelButton: false,
          );
        }
      } else {
        // Update message when creating
        if (context != null) {
          updateLoadingMessage(
            context,
            'Creating new game...',
            showCancelButton: true,
          );
        }

        // No game found, create a new one
        _isHost = true;
        _player = Squares.white; // Creating player is White
        _isOpponentFriend = false; // No opponent yet, so they can't be a friend

        _onlineGameRoom = await _gameService.createGameRoom(
          gameMode: gameMode,
          player1Id: userId,
          player1DisplayName: displayName,
          player1PhotoUrl: photoUrl,
          player1Flag: playerFlag,
          player2Flag: '',
          player1Rating: userRating,
          ratingBasedSearch: ratingBasedSearch,
          initialWhitesTime: _savedWhitesTime.inMilliseconds,
          initialBlacksTime: _savedBlacksTime.inMilliseconds,
          player1Score: _player1OnlineScore, // Pass current scores
          player2Score: _player2OnlineScore, // Pass current scores
        );
        _gameId = _onlineGameRoom!.gameId;
        _logger.i('Created new game: ${_onlineGameRoom!.gameId}');

        // Update message when waiting for opponent
        if (context != null) {
          updateLoadingMessage(
            context,
            'Waiting for opponent to join...',
            showCancelButton: true,
          );
        }
      }

      // Set up real-time listener for the game room
      gameRoomSubscription = _gameService
          .streamGameRoom(_gameId)
          .listen(
            onOnlineGameRoomUpdate,
            onError: (error) {
              _logger.e('Error streaming game room $_gameId: $error');
              // Handle error, e.g., show a snackbar
            },
            onDone: () {
              _logger.i('Game room $_gameId stream closed.');
            },
          );

      // Set up friend request listener if not already friends
      if (!_isOpponentFriend) {
        _friendRequestSubscription = _friendService
            .getFriendRequests(userId)
            .listen((requests) {
              final opponentId =
                  _isHost
                      ? _onlineGameRoom?.player2Id
                      : _onlineGameRoom?.player1Id;
              if (opponentId != null) {
                final requestExists = requests.any(
                  (req) => req.uid == opponentId,
                );
                _friendRequestReceived = requestExists;
                _friendRequestSenderId = requestExists ? opponentId : null;
                notifyListeners();
              }
            });
      }

      // Initialize game state based on the online game room
      _whitesTime = Duration(milliseconds: _onlineGameRoom!.initialWhitesTime);
      _blacksTime = Duration(milliseconds: _onlineGameRoom!.initialBlacksTime);
      // Initialize game state based on the online game room
      _whitesTime = Duration(
        milliseconds: _onlineGameRoom!.whitesTimeRemaining,
      ); // Use remaining time
      _blacksTime = Duration(
        milliseconds: _onlineGameRoom!.blacksTimeRemaining,
      ); // Use remaining time
      _player1OnlineScore = _onlineGameRoom!.player1Score;
      _player2OnlineScore = _onlineGameRoom!.player2Score;

      _game = bishop.Game(fen: _onlineGameRoom!.fen);
      _state = _game.squaresState(_player);

      // Apply historical moves if any
      for (var moveString in _onlineGameRoom!.moves) {
        _game.makeSquaresMove(_convertMoveStringToMove(moveString: moveString));
      }

      // Start timer if game is active and it's our turn
      if (_onlineGameRoom!.status == Constants.statusActive &&
          ((_isHost && _game.state.turn == Squares.white) ||
              (!_isHost && _game.state.turn == Squares.black))) {
        _startTimer();
      }

      // If it's the start of an online game, begin the 30-second countdown for White.
      if (_isOnlineGame &&
          _onlineGameRoom!.moves.isEmpty &&
          _onlineGameRoom!.status == Constants.statusActive) {
        _startFirstMoveCountdown(forPlayer: Squares.white);
      }
      // If White has already moved but Black hasn't, start countdown for Black
      else if (_isOnlineGame &&
          _onlineGameRoom!.moves.length == 1 &&
          _onlineGameRoom!.status == Constants.statusActive) {
        _startFirstMoveCountdown(forPlayer: Squares.black);
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

  Future<void> createPrivateGameRoom({
    required String gameMode,
    required String player1Id,
    required String player2Id,
    required String player1DisplayName,
    String? player1PhotoUrl,
    required String playerFlag,
    required int player1Rating,
  }) async {
    setLoading(true);
    setIsOnlineGame(true); // Set online game mode

    setTimeControl(gameMode);

    _isHost = true;
    _player = Squares.white; // Current user will be white
    _isOpponentFriend = await _friendService.isFriend(player1Id, player2Id);

    _onlineGameRoom = await _gameService.createPrivateGameRoom(
      gameMode: gameMode,
      player1Id: player1Id,
      player2Id: player2Id,
      player1DisplayName: player1DisplayName,
      player1PhotoUrl: player1PhotoUrl,
      playerFlag: playerFlag,
      player1Rating: player1Rating,
      initialWhitesTime: _savedWhitesTime.inMilliseconds,
      initialBlacksTime: _savedBlacksTime.inMilliseconds,
    );
    _gameId = _onlineGameRoom!.gameId;
    _logger.i('Created new game: ${_onlineGameRoom!.gameId}');

    // Send game notification for friends notification collection
    _gameService.sendGameNotification(gameRoom: _onlineGameRoom!);

    // Set up real-time listener for the game room
    gameRoomSubscription = _gameService
        .streamGameRoom(_gameId)
        .listen(
          onOnlineGameRoomUpdate,
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
    // Initialize game state based on the online game room
    _whitesTime = Duration(
      milliseconds: _onlineGameRoom!.whitesTimeRemaining,
    ); // Use remaining time
    _blacksTime = Duration(
      milliseconds: _onlineGameRoom!.blacksTimeRemaining,
    ); // Use remaining time
    _player1OnlineScore = _onlineGameRoom!.player1Score;
    _player2OnlineScore = _onlineGameRoom!.player2Score;

    _game = bishop.Game(fen: _onlineGameRoom!.fen);
    _state = _game.squaresState(_player);

    // Apply historical moves if any
    for (var moveString in _onlineGameRoom!.moves) {
      _game.makeSquaresMove(_convertMoveStringToMove(moveString: moveString));
    }

    // Start timer if game is active and it's our turn
    if (_onlineGameRoom!.status == Constants.statusActive &&
        ((_isHost && _game.state.turn == Squares.white) ||
            (!_isHost && _game.state.turn == Squares.black))) {
      _startTimer();
    }

    setLoading(false);
    notifyListeners();
  }

  Future<bool> joinPrivateGameRoom({
    required String userId,
    required String displayName,
    String? photoUrl,
    required String playerFlag,
    required int userRating,
    required String gameMode,
  }) async {
    // Set loading
    setLoading(true);
    setIsOnlineGame(true);
    setTimeControl(gameMode);

    try {
      _logger.i('Checking for available games...');

      // We check if the game is still available
      GameRoom? isAvailable = await _gameService.findAvailableGame(
        gameMode: gameMode,
        userRating: userRating,
        isPrivate: true,
        currentUserId: userId,
      );

      if (isAvailable != null) {
        _logger.i('Game found: ${isAvailable.gameId}');

        // Check if the host is a friend
        _isOpponentFriend = await _friendService.isFriend(
          userId,
          isAvailable.player1Id,
        );

        // Join existing game
        _isHost = false;
        _onlineGameRoom = isAvailable;
        _gameId = isAvailable.gameId;
        _player = Squares.black; // Joining player is Black

        await _gameService.joinGameRoom(
          gameId: isAvailable.gameId,
          player2Id: userId,
          player2DisplayName: displayName,
          player2PhotoUrl: photoUrl,
          player2Flag: playerFlag,
          player2Rating: userRating,
        );

        // Delete the notification
        await _gameService.deleteGameNotification(userId, _gameId);

        _logger.i('Game notification deleted: $_gameId');

        // Set up real-time listener for the game room
        gameRoomSubscription = _gameService
            .streamGameRoom(_gameId)
            .listen(
              onOnlineGameRoomUpdate,
              onError: (error) {
                _logger.e('Error streaming game room $_gameId: $error');
                // Handle error, e.g., show a snackbar
              },
              onDone: () {
                _logger.i('Game room $_gameId stream closed.');
              },
            );

        // Initialize game state based on the online game room
        _whitesTime = Duration(
          milliseconds: _onlineGameRoom!.initialWhitesTime,
        );
        _blacksTime = Duration(
          milliseconds: _onlineGameRoom!.initialBlacksTime,
        );
        // Initialize game state based on the online game room
        _whitesTime = Duration(
          milliseconds: _onlineGameRoom!.whitesTimeRemaining,
        ); // Use remaining time
        _blacksTime = Duration(
          milliseconds: _onlineGameRoom!.blacksTimeRemaining,
        ); // Use remaining time
        _player1OnlineScore = _onlineGameRoom!.player1Score;
        _player2OnlineScore = _onlineGameRoom!.player2Score;

        _game = bishop.Game(fen: _onlineGameRoom!.fen);
        _state = _game.squaresState(_player);

        // Apply historical moves if any
        for (var moveString in _onlineGameRoom!.moves) {
          _game.makeSquaresMove(
            _convertMoveStringToMove(moveString: moveString),
          );
        }

        // Start timer if game is active and it's our turn
        if (_onlineGameRoom!.status == Constants.statusActive &&
            ((_isHost && _game.state.turn == Squares.white) ||
                (!_isHost && _game.state.turn == Squares.black))) {
          _startTimer();
        }

        setLoading(false);
        notifyListeners();

        _logger.i('Stream set up, initializing game state...');

        return true;
      } else {
        // Update message game not found and return
        setLoading(false);
        return false;
      }
    } catch (e) {
      _logger.e('Error during online game joining: $e');
      setLoading(false);
      // Handle error, e.g., show a snackbar
      return false;
    }
  }

  Future<void> declineGameInvite(String gameId, String userId) async {
    try {
      // Delete the game room and notification
      await _gameService.declineGameInvite(gameId, userId);

      notifyListeners();
    } catch (e) {
      _logger.e('Error declining game invite: $e');
      rethrow;
    }
  }

  // Future<void> startOnlineGameWithRoom(GameRoom room, ChessUser user) async {
  //   setLoading(true);
  //   setIsOnlineGame(true);
  //   _onlineGameRoom = room;
  //   _gameId = room.gameId;
  //   _isHost = room.player1Id == user.uid;
  //   _player = _isHost ? room.player1Color : room.player2Color!;

  //   // Set up real-time listener for the game room
  //   gameRoomSubscription = _gameService
  //       .streamGameRoom(_gameId)
  //       .listen(onOnlineGameRoomUpdate);

  //   _whitesTime = Duration(milliseconds: room.initialWhitesTime);
  //   _blacksTime = Duration(milliseconds: room.initialBlacksTime);
  //   _player1OnlineScore = room.player1Score;
  //   _player2OnlineScore = room.player2Score;

  //   _game = bishop.Game(fen: room.fen);
  //   _state = _game.squaresState(_player);

  //   setLoading(false);
  //   notifyListeners();
  // }

  /// Handles updates received from the online game room stream.
  void onOnlineGameRoomUpdate(GameRoom updatedRoom) {
    // If the game room is null or the ID doesn't match, ignore the update
    if (_onlineGameRoom == null ||
        _onlineGameRoom!.gameId != updatedRoom.gameId) {
      return;
    }

    final bool wasGameOver = isGameOver;
    _onlineGameRoom = updatedRoom;
    _gameId = updatedRoom.gameId;

    // Update local game state based on Firestore updates
    // Always update times and scores, even if FEN hasn't changed (e.g., draw offer)
    _whitesTime = Duration(milliseconds: updatedRoom.whitesTimeRemaining);
    _blacksTime = Duration(milliseconds: updatedRoom.blacksTimeRemaining);
    _player1OnlineScore = updatedRoom.player1Score;
    _player2OnlineScore = updatedRoom.player2Score;

    // --- Rematch Logic ---
    // If the game was over and now it's active, it's a rematch
    if (wasGameOver &&
        updatedRoom.status == Constants.statusActive &&
        updatedRoom.rematchOfferedBy == null) {
      _logger.i(
        'REMATCH DEBUG: Rematch detected - game was over: $wasGameOver, status: ${updatedRoom.status}, rematchOfferedBy: ${updatedRoom.rematchOfferedBy}',
      );

      // Explicitly reset timers for the rematch
      _whitesTime = Duration(milliseconds: updatedRoom.initialWhitesTime);
      _blacksTime = Duration(milliseconds: updatedRoom.initialBlacksTime);

      // Swap player color for the new game based on the updated room
      _player =
          updatedRoom.player1Id ==
                  (_isHost
                      ? _onlineGameRoom!.player1Id
                      : _onlineGameRoom!.player2Id)
              ? updatedRoom.player1Color
              : updatedRoom.player2Color!;

      _logger.i(
        'REMATCH DEBUG: About to reset game and clear game result. Current game result: ${_gameResultNotifier.value}',
      );
      resetGame(false); // false because it's a rematch, not a brand new game
      _logger.i(
        'REMATCH DEBUG: Game reset completed. New game result: ${_gameResultNotifier.value}',
      );
      notifyListeners();
      return; // Exit early to avoid conflicting logic below
    }

    // Only update game board if the FEN has changed (meaning a move was made by opponent)
    if (_game.fen != updatedRoom.fen) {
      _logger.i('Updating game FEN from Firestore: ${updatedRoom.fen}');
      // Check if there's a new move (opponent's move)
      if (updatedRoom.moves.length > _moveHistory.length) {
        // Get the latest move from the opponent
        final latestMoveString = updatedRoom.moves.last;
        _logger.i('Latest move from Firestore: $latestMoveString');
        final latestMove = _convertMoveStringToMove(
          moveString: latestMoveString,
        );

        _logger.i(
          'Converted latest move: from ${latestMove.from} to ${latestMove.to}, '
          'promo: ${latestMove.promo}, piece: ${latestMove.piece}',
        );

        // Apply only the new move to our local game
        _game.makeSquaresMove(latestMove);
        _state = _game.squaresState(_player);

        // Update move history with the new move
        _moveHistory.add(_getMoveNotation(latestMove));

        // Update captured pieces and check game over
        updateCapturedPieces();
        checkGameOver();

        // Handle timer switching
        _stopTimers();

        // Start timer for the current player if game is not over
        if (!_game.gameOver &&
            ((_isHost && _game.state.turn == Squares.white) ||
                (!_isHost && _game.state.turn == Squares.black))) {
          _startTimer();
        }
      }
    }

    // Handle status changes (e.g., opponent joined, game ended)
    if (updatedRoom.status == Constants.statusActive && !_game.gameOver) {
      // If the game is just starting, initiate the first move countdown for White.
      if (updatedRoom.moves.isEmpty) {
        _startFirstMoveCountdown(forPlayer: Squares.white);
      }
      // If White has made a move, but Black hasn't, start countdown for Black.
      else if (updatedRoom.moves.length == 1) {
        _startFirstMoveCountdown(forPlayer: Squares.black);
      }
      // If both players have made their first moves, the widget will handle hiding itself

      // Ensure timer is running if game becomes active and it's our turn
      if (((_isHost && _game.state.turn == Squares.white) ||
          (!_isHost && _game.state.turn == Squares.black))) {
        _startTimer();
      }
    } else if (updatedRoom.status == Constants.statusCompleted ||
        updatedRoom.status == Constants.statusAborted) {
      _stopTimers();
      if (updatedRoom.status == Constants.statusAborted) {
        _gameResultNotifier.value = WonGameAborted(
          winner:
              updatedRoom.player1Color == Squares.white
                  ? Squares.black
                  : Squares.white,
        );
      }
      // Set game result based on winnerId or status
      else if (updatedRoom.winnerId != null) {
        final winnerColor =
            updatedRoom.player1Id == updatedRoom.winnerId
                ? updatedRoom.player1Color
                : updatedRoom.player2Color;
        if (winnerColor != null) {
          _gameResultNotifier.value = WonGameResignation(winner: winnerColor);
        }
      } else if (updatedRoom.status == Constants.statusCompleted) {
        // If game is completed and there's no winner, it's a draw.
        _gameResultNotifier.value = const DrawnGameAgreement();
      }
      checkGameOver();
    }

    // Handle draw offers from opponent
    _drawOfferReceived =
        updatedRoom.drawOfferedBy != null &&
        updatedRoom.drawOfferedBy !=
            (_isHost ? _onlineGameRoom!.player1Id : _onlineGameRoom!.player2Id);

    // Handle rematch offers from opponent
    if (updatedRoom.rematchOfferedBy != null &&
        updatedRoom.rematchOfferedBy !=
            (_isHost
                ? _onlineGameRoom!.player1Id
                : _onlineGameRoom!.player2Id)) {
      // Show rematch offer dialog
      // This will be handled in GameScreen, just notify listeners
    }

    notifyListeners();
  }

  /// Waits for the game to become active (opponent joined)
  Future<void> waitForGameToStart() async {
    // If game is already active, return immediately
    if (_onlineGameRoom?.status == Constants.statusActive) {
      return;
    }

    // Create a completer to wait for the game to start
    final completer = Completer<void>();

    // Listen for status changes
    late StreamSubscription<GameRoom> subscription;
    subscription = _gameService
        .streamGameRoom(_gameId)
        .listen(
          (gameRoom) {
            if (gameRoom.status == Constants.statusActive) {
              subscription.cancel();
              completer.complete();
            } else if (gameRoom.status == Constants.statusAborted ||
                gameRoom.status == Constants.statusCompleted ||
                gameRoom.status == Constants.statusDeclined) {
              subscription.cancel();
              completer.completeError(
                'Game was aborted, declined or completed',
              );
            }
          },
          onError: (error) {
            subscription.cancel();
            completer.completeError(error);
          },
        );

    // Wait for the game to start with a timeout
    await completer.future.timeout(
      const Duration(minutes: 5), // 5 minute timeout
      onTimeout: () {
        subscription.cancel();
        // delete the game room if it was created and still waiting
        if (_isHost &&
            _onlineGameRoom != null &&
            _onlineGameRoom!.status == Constants.statusWaiting) {
          _gameService.deleteGameRoom(_onlineGameRoom!.gameId);
        }
        // delete the game room if it was created and still waiting
        if (_isHost &&
            _onlineGameRoom != null &&
            _onlineGameRoom!.isPrivate == true) {
          _gameService.deleteGameNotification(
            onlineGameRoom!.player1Id,
            _onlineGameRoom!.gameId,
          );
        }
        _logger.w('Timed out waiting for opponent to join');
        // Show a timeout exception
        throw TimeoutException(
          'Timed out waiting for opponent',
          const Duration(minutes: 5),
        );
      },
    );
  }

  /// Starts a 30-second countdown for the first move in an online game.
  /// This is now handled by the FirstMoveCountdownWidget itself.
  void _startFirstMoveCountdown({required int forPlayer}) {
    // The countdown is now handled by the FirstMoveCountdownWidget
    // This method is kept for compatibility but doesn't start a timer
    _logger.i(
      'First move countdown should be shown for ${forPlayer == Squares.white ? 'White' : 'Black'}',
    );
  }

  /// Handles the timeout for the first move.
  Future<void> handleFirstMoveTimeout({required int winner}) async {
    if (!_isOnlineGame || _onlineGameRoom == null) return;

    _gameResultNotifier.value = WonGameTimeout(winner: winner);
    _stopTimers();

    final winnerId =
        winner == _onlineGameRoom!.player1Color
            ? _onlineGameRoom!.player1Id
            : _onlineGameRoom!.player2Id;

    // Both players should be able to update the game status to prevent
    // other players from joining abandoned games
    try {
      if (winnerId != null) {
        await _gameService.updateGameRoom(_onlineGameRoom!.gameId, {
          Constants.fieldStatus: Constants.statusCompleted,
          Constants.fieldWinnerId: winnerId,
          Constants.fieldLastMoveAt: Timestamp.now(),
        });
        _logger.i('Game status updated to completed due to first move timeout');
      }
    } catch (e) {
      _logger.e('Error updating game status on first move timeout: $e');
      // Continue with game over handling even if Firestore update fails
    }

    // Determine the current user's ID for saving the game
    final currentUserId =
        _isHost ? _onlineGameRoom!.player1Id : _onlineGameRoom!.player2Id;

    if (currentUserId != null) {
      checkGameOver(userId: currentUserId);
    } else {
      checkGameOver();
    }
    notifyListeners();
  }

  /// Aborts the game.
  Future<void> _abortGame() async {
    if (!_isOnlineGame || _onlineGameRoom == null) return;

    // Black wins by abortion
    final winnerColor =
        _onlineGameRoom!.player1Color == Squares.white
            ? Squares.black
            : Squares.white;
    _gameResultNotifier.value = WonGameAborted(winner: winnerColor);
    _stopTimers();

    await _gameService.abortGame(_onlineGameRoom!.gameId);
    checkGameOver();
    notifyListeners();
  }

  Future<void> cancelOnlineGameSearch({bool isFriend = false}) async {
    try {
      // Cancel the game room subscription
      await gameRoomSubscription?.cancel();
      gameRoomSubscription = null;

      // If we created a game (we're the host), delete it
      if (_isHost && _onlineGameRoom != null) {
        await _gameService.deleteGameRoom(_onlineGameRoom!.gameId);
        // If it was a friend invite we also need to delete the notification
        if (isFriend) {
          await _gameService.deleteGameNotification(
            _onlineGameRoom!.player2Id!,
            _onlineGameRoom!.gameId,
          );
        }
        _logger.i('Deleted game room: ${_onlineGameRoom!.gameId}');
      }

      // Reset game state
      _onlineGameRoom = null;
      _gameId = '';
      _isHost = false;
      setIsOnlineGame(false);
      setLoading(false);

      notifyListeners();
    } catch (e) {
      _logger.e('Error canceling online game search: $e');
      setLoading(false);
    }
  }

  void updateLoadingMessage(
    BuildContext context,
    String message, {
    bool showCancelButton = false,
  }) {
    if (context.mounted) {
      LoadingDialog.updateMessage(
        context,
        message,
        showOnlineCount: true,
        showCancelButton: showCancelButton,
        onCancel: showCancelButton ? () => cancelOnlineGameSearch() : null,
      );
    }
  }

  /// Saves the current game to Firestore and updates user statistics.
  /// This method should be called when a game concludes (win, loss, draw).
  Future<void> _saveCurrentGame(String userId) async {
    if (_gameResultNotifier.value == null) {
      _logger.w('Attempted to save game, but gameResult is null.');
      return;
    }

    String result = 'unknown';
    String winnerColor = Constants.none;
    String opponentId = '';
    String opponentDisplayName = 'CPU'; // Default for CPU games

    if (_isOnlineGame && _onlineGameRoom != null) {
      if (_isHost) {
        opponentId = _onlineGameRoom!.player2Id ?? '';
        opponentDisplayName = _onlineGameRoom!.player2DisplayName ?? 'Opponent';
      } else {
        opponentId = _onlineGameRoom!.player1Id;
        opponentDisplayName = _onlineGameRoom!.player1DisplayName;
      }
    } else if (_vsCPU) {
      opponentId = 'stockfish_ai'; // A placeholder ID for AI
      opponentDisplayName = 'CPU (Level $_gameLevel)';
    } else if (_localMultiplayer) {
      opponentId = 'local_player'; // A placeholder ID for local multiplayer
      opponentDisplayName = 'Local Player';
    }

    if (_gameResultNotifier.value is bishop.WonGame) {
      final winner = (_gameResultNotifier.value as bishop.WonGame).winner;
      winnerColor = winner == Squares.white ? Constants.white : Constants.black;
      if ((winner == Squares.white && _player == Squares.white) ||
          (winner == Squares.black && _player == Squares.black)) {
        result = Constants.win;
      } else {
        result = Constants.loss;
      }
    } else if (_gameResultNotifier.value is bishop.DrawnGame) {
      result = Constants.draw;
      winnerColor = Constants.none;
    }

    final savedGame = SavedGame(
      gameId: _gameId.isNotEmpty ? _gameId : const Uuid().v4(),
      userId: userId,
      opponentId: opponentId,
      opponentDisplayName: opponentDisplayName,
      initialFen: _game.variant.startPosition!,
      moves: _moveHistory,
      result: result,
      winnerColor: winnerColor,
      gameMode: _selectedTimeControl,
      initialWhitesTime: _savedWhitesTime.inMilliseconds,
      initialBlacksTime: _savedBlacksTime.inMilliseconds,
      finalWhitesTime: _whitesTime.inMilliseconds,
      finalBlacksTime: _blacksTime.inMilliseconds,
      createdAt: Timestamp.now(),
    );

    try {
      await _savedGameService.saveGame(savedGame);
      _logger.i('Game saved successfully to Firestore.');

      // Update user statistics only for real users (not local/CPU placeholders)
      if (userId != 'local_user' && userId != 'cpu_game_user') {
        await _userService.updateUserStatsAfterGame(
          userId: userId,
          gameResult: result,
          gameMode: _selectedTimeControl,
          gameId: savedGame.gameId,
          opponentId: opponentId,
        );
        _logger.i('User statistics updated successfully.');
      } else {
        _logger.i('Skipped user stats update for local/CPU game.');
      }
    } catch (e) {
      _logger.e('Failed to save game or update user stats: $e');
    }
  }

  void _updateOnlineScoresOnGameOver() {
    if (_scoresUpdatedForCurrentGame || _gameResultNotifier.value == null) {
      return; // Ensure scores are updated only once per game
    }

    int newP1Score = _onlineGameRoom!.player1Score;
    int newP2Score = _onlineGameRoom!.player2Score;

    if (_gameResultNotifier.value is bishop.WonGame) {
      final winner = (_gameResultNotifier.value as bishop.WonGame).winner;
      if (winner == _onlineGameRoom!.player1Color) {
        newP1Score++;
      } else {
        newP2Score++;
      }
    }
    // No score change for a draw

    // Update local state immediately for UI responsiveness
    _player1OnlineScore = newP1Score;
    _player2OnlineScore = newP2Score;

    // Call the service to update Firestore
    _gameService.updateGameScores(
      _onlineGameRoom!.gameId,
      newP1Score,
      newP2Score,
    );

    _scoresUpdatedForCurrentGame = true;
    _logger.i('Updated scores on game over: P1: $newP1Score, P2: $newP2Score');
  }

  /// Deletes all chat messages between two users.
  Future<void> deleteChatMessages(
    String currentUserId,
    String otherUserId,
  ) async {
    try {
      await _chatService.deleteChatMessages(currentUserId, otherUserId);
      _logger.i(
        'Chat messages between $currentUserId and $otherUserId deleted.',
      );
    } catch (e) {
      _logger.e('Error deleting chat messages: $e');
    }
  }
}
