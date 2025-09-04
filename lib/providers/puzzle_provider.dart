import 'dart:async';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../models/puzzle_model.dart';
import '../models/puzzle_progress.dart';
import '../services/puzzle_service.dart';

/// Enum representing the current state of a puzzle session
enum PuzzleSessionState {
  /// No puzzle is currently active
  idle,

  /// Puzzle is loaded and ready to be solved
  active,

  /// Puzzle has been successfully solved
  solved,

  /// Puzzle attempt failed (incorrect moves)
  failed,

  /// Puzzle session was abandoned by the user
  abandoned,
}

/// Model representing the current puzzle session
class PuzzleSession {
  /// The current puzzle being solved
  final PuzzleModel puzzle;

  /// List of moves made by the user so far
  final List<String> userMoves;

  /// Current move index in the solution sequence
  final int currentMoveIndex;

  /// Number of hints used in this session
  final int hintsUsed;

  /// When the puzzle session started
  final DateTime startTime;

  /// Current state of the puzzle session
  final PuzzleSessionState state;

  /// Current hint text being displayed (if any)
  final String? currentHint;

  const PuzzleSession({
    required this.puzzle,
    required this.userMoves,
    required this.currentMoveIndex,
    required this.hintsUsed,
    required this.startTime,
    required this.state,
    this.currentHint,
  });

  /// Create a new puzzle session
  factory PuzzleSession.start(PuzzleModel puzzle) {
    return PuzzleSession(
      puzzle: puzzle,
      userMoves: [],
      currentMoveIndex: 0,
      hintsUsed: 0,
      startTime: DateTime.now(),
      state: PuzzleSessionState.active,
    );
  }

  /// Create a copy of this session with updated fields
  PuzzleSession copyWith({
    PuzzleModel? puzzle,
    List<String>? userMoves,
    int? currentMoveIndex,
    int? hintsUsed,
    DateTime? startTime,
    PuzzleSessionState? state,
    String? currentHint,
  }) {
    return PuzzleSession(
      puzzle: puzzle ?? this.puzzle,
      userMoves: userMoves ?? this.userMoves,
      currentMoveIndex: currentMoveIndex ?? this.currentMoveIndex,
      hintsUsed: hintsUsed ?? this.hintsUsed,
      startTime: startTime ?? this.startTime,
      state: state ?? this.state,
      currentHint: currentHint ?? this.currentHint,
    );
  }

  /// Get the solve time for this session
  Duration get solveTime => DateTime.now().difference(startTime);

  /// Check if the puzzle is completed
  bool get isCompleted => state == PuzzleSessionState.solved;

  /// Check if hints are available
  bool get hasMoreHints => hintsUsed < puzzle.hints.length;
}

/// Provider for managing puzzle state and user interactions
class PuzzleProvider extends ChangeNotifier {
  final PuzzleService _puzzleService = PuzzleService();
  final Logger _logger = Logger();

  // Current session state
  PuzzleSession? _currentSession;

  // Available puzzles by difficulty
  final Map<PuzzleDifficulty, List<PuzzleModel>> _puzzlesByDifficulty = {};

  // Progress tracking by difficulty
  final Map<PuzzleDifficulty, List<PuzzleProgress>> _progressByDifficulty = {};

  // Current user ID
  String? _currentUserId;

  // Loading states
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  PuzzleSession? get currentSession => _currentSession;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasPuzzleActive =>
      _currentSession != null &&
      _currentSession!.state == PuzzleSessionState.active;

  /// Get available puzzles for a difficulty level
  List<PuzzleModel> getPuzzlesForDifficulty(PuzzleDifficulty difficulty) {
    return _puzzlesByDifficulty[difficulty] ?? [];
  }

  /// Get progress for a difficulty level
  List<PuzzleProgress> getProgressForDifficulty(PuzzleDifficulty difficulty) {
    return _progressByDifficulty[difficulty] ?? [];
  }

  /// Set the current user ID
  void setUserId(String userId) {
    if (_currentUserId != userId) {
      _currentUserId = userId;
      _loadUserProgress();
    }
  }

  /// Initialize the provider and load puzzles
  Future<void> initialize({String? userId}) async {
    _setLoading(true);
    _clearError();

    try {
      _logger.i('Initializing PuzzleProvider');

      if (userId != null) {
        _currentUserId = userId;
      }

      // Load all puzzles and organize by difficulty
      await _loadPuzzlesByDifficulty();

      // Load user progress if user ID is available
      if (_currentUserId != null) {
        await _loadUserProgress();
      }

      _logger.i('PuzzleProvider initialized successfully');
    } catch (e) {
      _logger.e('Error initializing PuzzleProvider: $e');
      _setError('Failed to initialize puzzles: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Start a new puzzle session
  Future<void> startPuzzle(PuzzleModel puzzle) async {
    try {
      _logger.i('Starting puzzle: ${puzzle.id}');
      _clearError();

      // End current session if active
      if (_currentSession != null) {
        await _endCurrentSession(abandoned: true);
      }

      // Create new session
      _currentSession = PuzzleSession.start(puzzle);

      // Create or update progress record
      if (_currentUserId != null) {
        await _initializePuzzleProgress(puzzle);
      }

      notifyListeners();
      _logger.i('Puzzle session started: ${puzzle.id}');
    } catch (e) {
      _logger.e('Error starting puzzle ${puzzle.id}: $e');
      _setError('Failed to start puzzle: $e');
    }
  }

  /// Make a move in the current puzzle
  Future<bool> makeMove(String move) async {
    if (_currentSession == null ||
        _currentSession!.state != PuzzleSessionState.active) {
      _logger.w('No active puzzle session to make move');
      return false;
    }

    try {
      _logger.i('Making move: $move for puzzle ${_currentSession!.puzzle.id}');
      _clearError();

      final puzzle = _currentSession!.puzzle;
      final currentMoves = List<String>.from(_currentSession!.userMoves);

      // Validate the move
      final isValidMove = _puzzleService.validateMove(
        puzzle,
        currentMoves,
        move,
      );

      if (!isValidMove) {
        _logger.w('Invalid move: $move');
        await _incrementAttempts();
        return false;
      }

      // Add the move to user moves
      currentMoves.add(move);

      // Update session with new move
      _currentSession = _currentSession!.copyWith(
        userMoves: currentMoves,
        currentMoveIndex: currentMoves.length,
      );

      // Check if puzzle is solved
      final isSolved = _puzzleService.isPuzzleSolved(puzzle, currentMoves);

      if (isSolved) {
        // Update session state to solved before completing
        _currentSession = _currentSession!.copyWith(
          state: PuzzleSessionState.solved,
        );
        await _completePuzzle();
      }

      notifyListeners();
      _logger.i('Move processed successfully: $move');
      return true;
    } catch (e) {
      _logger.e('Error making move $move: $e');
      _setError('Failed to process move: $e');
      return false;
    }
  }

  /// Request a hint for the current puzzle
  Future<String?> requestHint() async {
    if (_currentSession == null ||
        _currentSession!.state != PuzzleSessionState.active) {
      _logger.w('No active puzzle session to request hint');
      return null;
    }

    try {
      _logger.i('Requesting hint for puzzle ${_currentSession!.puzzle.id}');
      _clearError();

      final puzzle = _currentSession!.puzzle;
      final currentHints = _currentSession!.hintsUsed;

      // Check if more hints are available
      if (currentHints >= puzzle.hints.length) {
        _logger.w('No more hints available for puzzle ${puzzle.id}');
        return null;
      }

      // Get the next hint
      final hint = _puzzleService.getNextHint(puzzle, currentHints);

      if (hint != null) {
        // Update session with incremented hint count
        _currentSession = _currentSession!.copyWith(
          hintsUsed: currentHints + 1,
          currentHint: hint,
        );

        // Update progress
        if (_currentUserId != null) {
          await _incrementHints();
        }

        notifyListeners();
        _logger.i('Hint provided for puzzle ${puzzle.id}');
      }

      return hint;
    } catch (e) {
      _logger.e('Error requesting hint: $e');
      _setError('Failed to get hint: $e');
      return null;
    }
  }

  /// Reset the current puzzle to its initial state
  Future<void> resetPuzzle() async {
    if (_currentSession == null) {
      _logger.w('No puzzle session to reset');
      return;
    }

    try {
      _logger.i('Resetting puzzle: ${_currentSession!.puzzle.id}');
      _clearError();

      final puzzle = _currentSession!.puzzle;

      // Create new session with same puzzle
      _currentSession = PuzzleSession.start(puzzle);

      // Reset progress if needed
      if (_currentUserId != null) {
        await _initializePuzzleProgress(puzzle);
      }

      notifyListeners();
      _logger.i('Puzzle reset: ${puzzle.id}');
    } catch (e) {
      _logger.e('Error resetting puzzle: $e');
      _setError('Failed to reset puzzle: $e');
    }
  }

  /// Navigate to the next puzzle in the current difficulty level
  Future<PuzzleModel?> nextPuzzle() async {
    if (_currentSession == null) {
      _logger.w('No current session to get next puzzle');
      return null;
    }

    try {
      _logger.i('Getting next puzzle after ${_currentSession!.puzzle.id}');
      _clearError();

      final currentPuzzle = _currentSession!.puzzle;

      // End current session
      await _endCurrentSession();

      // Get next puzzle
      if (_currentUserId != null) {
        final nextPuzzle = await _puzzleService.getNextPuzzle(
          _currentUserId!,
          currentPuzzle.difficulty,
          currentPuzzle.id,
        );

        if (nextPuzzle != null) {
          await startPuzzle(nextPuzzle);
          return nextPuzzle;
        } else {
          _logger.i(
            'No more puzzles in difficulty ${currentPuzzle.difficulty.displayName}',
          );
        }
      }

      return null;
    } catch (e) {
      _logger.e('Error getting next puzzle: $e');
      _setError('Failed to get next puzzle: $e');
      return null;
    }
  }

  /// Get completion percentage for a difficulty level
  int getCompletionPercentage(PuzzleDifficulty difficulty) {
    final puzzles = getPuzzlesForDifficulty(difficulty);
    final progress = getProgressForDifficulty(difficulty);

    if (puzzles.isEmpty) return 0;

    final completedCount = progress.where((p) => p.completed).length;
    return ((completedCount / puzzles.length) * 100).round();
  }

  /// Get the first unsolved puzzle for a difficulty level
  Future<PuzzleModel?> getFirstUnsolvedPuzzle(
    PuzzleDifficulty difficulty,
  ) async {
    if (_currentUserId == null) {
      final puzzles = getPuzzlesForDifficulty(difficulty);
      return puzzles.isNotEmpty ? puzzles.first : null;
    }

    try {
      return await _puzzleService.getFirstUnsolvedPuzzle(
        _currentUserId!,
        difficulty,
      );
    } catch (e) {
      _logger.e('Error getting first unsolved puzzle: $e');
      return null;
    }
  }

  /// End the current puzzle session
  Future<void> endCurrentSession({bool abandoned = false}) async {
    await _endCurrentSession(abandoned: abandoned);
  }

  // Private helper methods

  /// Load puzzles organized by difficulty
  Future<void> _loadPuzzlesByDifficulty() async {
    _puzzlesByDifficulty.clear();

    for (final difficulty in PuzzleDifficulty.values) {
      final puzzles = await _puzzleService.getPuzzlesByDifficulty(difficulty);
      _puzzlesByDifficulty[difficulty] = puzzles;
    }
  }

  /// Load user progress for all difficulties
  Future<void> _loadUserProgress() async {
    if (_currentUserId == null) return;

    _progressByDifficulty.clear();

    try {
      final allProgress = await _puzzleService.getAllUserProgress(
        _currentUserId!,
      );

      // Organize progress by difficulty
      for (final progress in allProgress) {
        final difficulty = progress.difficulty;
        _progressByDifficulty[difficulty] ??= [];
        _progressByDifficulty[difficulty]!.add(progress);
      }

      _logger.i('Loaded progress for ${allProgress.length} puzzles');
    } catch (e) {
      _logger.e('Error loading user progress: $e');
    }
  }

  /// Initialize or get existing progress for a puzzle
  Future<void> _initializePuzzleProgress(PuzzleModel puzzle) async {
    if (_currentUserId == null) return;

    try {
      var progress = await _puzzleService.getPuzzleProgress(
        _currentUserId!,
        puzzle.id,
      );

      if (progress == null) {
        // Create new progress record
        progress = PuzzleProgress.newAttempt(
          userId: _currentUserId!,
          puzzleId: puzzle.id,
          difficulty: puzzle.difficulty,
        );
        await _puzzleService.savePuzzleProgress(progress);

        // Add to local cache
        _progressByDifficulty[puzzle.difficulty] ??= [];
        _progressByDifficulty[puzzle.difficulty]!.add(progress);
      }
    } catch (e) {
      _logger.e('Error initializing puzzle progress: $e');
    }
  }

  /// Complete the current puzzle
  Future<void> _completePuzzle() async {
    if (_currentSession == null || _currentUserId == null) return;

    try {
      final session = _currentSession!;

      // Session state should already be set to solved by the caller

      // Update progress
      final progress = await _puzzleService.getPuzzleProgress(
        _currentUserId!,
        session.puzzle.id,
      );
      if (progress != null) {
        final completedProgress = progress.markCompleted(
          solveTime: session.solveTime,
          hintsUsed: session.hintsUsed,
        );

        await _puzzleService.savePuzzleProgress(completedProgress);

        // Update local cache
        final difficulty = session.puzzle.difficulty;
        final progressList = _progressByDifficulty[difficulty] ?? [];
        final index = progressList.indexWhere(
          (p) => p.puzzleId == session.puzzle.id,
        );
        if (index != -1) {
          progressList[index] = completedProgress;
        }
      }

      _logger.i('Puzzle completed: ${session.puzzle.id}');
    } catch (e) {
      _logger.e('Error completing puzzle: $e');
    }
  }

  /// Increment attempts for current puzzle
  Future<void> _incrementAttempts() async {
    if (_currentSession == null || _currentUserId == null) return;

    try {
      final progress = await _puzzleService.getPuzzleProgress(
        _currentUserId!,
        _currentSession!.puzzle.id,
      );
      if (progress != null) {
        final updatedProgress = progress.incrementAttempts();
        await _puzzleService.savePuzzleProgress(updatedProgress);

        // Update local cache
        final difficulty = _currentSession!.puzzle.difficulty;
        final progressList = _progressByDifficulty[difficulty] ?? [];
        final index = progressList.indexWhere(
          (p) => p.puzzleId == _currentSession!.puzzle.id,
        );
        if (index != -1) {
          progressList[index] = updatedProgress;
        }
      }
    } catch (e) {
      _logger.e('Error incrementing attempts: $e');
    }
  }

  /// Increment hints used for current puzzle
  Future<void> _incrementHints() async {
    if (_currentSession == null || _currentUserId == null) return;

    try {
      final progress = await _puzzleService.getPuzzleProgress(
        _currentUserId!,
        _currentSession!.puzzle.id,
      );
      if (progress != null) {
        final updatedProgress = progress.incrementHints();
        await _puzzleService.savePuzzleProgress(updatedProgress);

        // Update local cache
        final difficulty = _currentSession!.puzzle.difficulty;
        final progressList = _progressByDifficulty[difficulty] ?? [];
        final index = progressList.indexWhere(
          (p) => p.puzzleId == _currentSession!.puzzle.id,
        );
        if (index != -1) {
          progressList[index] = updatedProgress;
        }
      }
    } catch (e) {
      _logger.e('Error incrementing hints: $e');
    }
  }

  /// End the current session
  Future<void> _endCurrentSession({bool abandoned = false}) async {
    if (_currentSession == null) return;

    try {
      final state = abandoned
          ? PuzzleSessionState.abandoned
          : PuzzleSessionState.idle;
      _currentSession = _currentSession!.copyWith(state: state);

      // Clear session after a brief delay to allow UI to react
      Future.delayed(const Duration(milliseconds: 100), () {
        _currentSession = null;
        notifyListeners();
      });

      _logger.i('Puzzle session ended');
    } catch (e) {
      _logger.e('Error ending session: $e');
    }
  }

  /// Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Set error message
  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  /// Clear error message
  void _clearError() {
    _errorMessage = null;
  }

  @override
  void dispose() {
    _currentSession = null;
    _puzzlesByDifficulty.clear();
    _progressByDifficulty.clear();
    super.dispose();
  }
}
