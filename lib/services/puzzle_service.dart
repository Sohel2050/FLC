import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/puzzle_model.dart';
import '../models/puzzle_progress.dart';
import '../models/puzzle_solution_model.dart';
import '../utils/fallback_puzzles.dart';
import 'stockfish_puzzle_service.dart';

/// Service for managing chess puzzles data and progress
class PuzzleService {
  static const String _puzzleProgressPrefix = 'puzzle_progress_';
  static const String _puzzleAssetPath = 'assets/puzzles/puzzles.json';
  static const String _puzzleSolutionsCollection = 'puzzle_solutions';

  final Logger _logger = Logger();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final StockfishPuzzleService _stockfishService = StockfishPuzzleService();

  List<PuzzleModel>? _cachedPuzzles;
  final Map<String, PuzzleSolution> _cachedSolutions = {};
  bool _stockfishInitialized = false;

  /// Load all puzzles from assets JSON file
  Future<List<PuzzleModel>> loadPuzzles() async {
    if (_cachedPuzzles != null) {
      return _cachedPuzzles!;
    }

    try {
      _logger.i('Loading puzzles from assets');
      final String jsonString = await rootBundle.loadString(_puzzleAssetPath);

      if (jsonString.isEmpty) {
        throw Exception('Puzzle file is empty');
      }

      final Map<String, dynamic> jsonData = json.decode(jsonString);

      if (!jsonData.containsKey('puzzles')) {
        throw Exception('Invalid puzzle file format: missing puzzles array');
      }

      final List<dynamic> puzzlesJson = jsonData['puzzles'] as List<dynamic>;

      if (puzzlesJson.isEmpty) {
        _logger.w('No puzzles found in assets file');
        _cachedPuzzles = [];
        return _cachedPuzzles!;
      }

      final List<PuzzleModel> validPuzzles = [];
      int invalidCount = 0;

      // Parse puzzles with error handling for individual puzzle validation
      for (int i = 0; i < puzzlesJson.length; i++) {
        try {
          final puzzleJson = puzzlesJson[i] as Map<String, dynamic>;
          final puzzle = PuzzleModel.fromJson(puzzleJson);

          // Validate puzzle data
          if (_validatePuzzleData(puzzle)) {
            validPuzzles.add(puzzle);
          } else {
            invalidCount++;
            _logger.w('Skipping invalid puzzle at index $i: ${puzzle.id}');
          }
        } catch (e) {
          invalidCount++;
          _logger.w('Error parsing puzzle at index $i: $e');
        }
      }

      if (validPuzzles.isEmpty) {
        _logger.w(
          'No valid puzzles found in puzzle file, using fallback puzzles',
        );
        _cachedPuzzles = FallbackPuzzles.getFallbackPuzzles();
        return _cachedPuzzles!;
      }

      if (invalidCount > 0) {
        _logger.w(
          'Skipped $invalidCount invalid puzzles out of ${puzzlesJson.length}',
        );
      }

      _cachedPuzzles = validPuzzles;
      _logger.i('Successfully loaded ${_cachedPuzzles!.length} valid puzzles');
      return _cachedPuzzles!;
    } on FormatException catch (e) {
      _logger.e('JSON parsing error: $e, using fallback puzzles');
      _cachedPuzzles = FallbackPuzzles.getFallbackPuzzles();
      return _cachedPuzzles!;
    } on Exception catch (e) {
      _logger.e(
        'Error loading puzzles from assets: $e, using fallback puzzles',
      );
      _cachedPuzzles = FallbackPuzzles.getFallbackPuzzles();
      return _cachedPuzzles!;
    } catch (e) {
      _logger.e('Unexpected error loading puzzles: $e, using fallback puzzles');
      _cachedPuzzles = FallbackPuzzles.getFallbackPuzzles();
      return _cachedPuzzles!;
    }
  }

  /// Validate puzzle data integrity
  bool _validatePuzzleData(PuzzleModel puzzle) {
    try {
      // Check required fields
      if (puzzle.id.isEmpty) {
        _logger.w('Puzzle has empty ID');
        return false;
      }

      if (puzzle.fen.isEmpty) {
        _logger.w('Puzzle ${puzzle.id} has empty FEN');
        return false;
      }

      if (puzzle.solution.isEmpty) {
        _logger.w('Puzzle ${puzzle.id} has empty solution');
        return false;
      }

      if (puzzle.objective.isEmpty) {
        _logger.w('Puzzle ${puzzle.id} has empty objective');
        return false;
      }

      // Validate FEN format (basic check)
      final fenParts = puzzle.fen.split(' ');
      if (fenParts.length < 4) {
        _logger.w('Puzzle ${puzzle.id} has invalid FEN format');
        return false;
      }

      // Validate solution moves are not empty
      for (final move in puzzle.solution) {
        if (move.trim().isEmpty) {
          _logger.w('Puzzle ${puzzle.id} has empty move in solution');
          return false;
        }
      }

      return true;
    } catch (e) {
      _logger.w('Error validating puzzle ${puzzle.id}: $e');
      return false;
    }
  }

  /// Get puzzles filtered by difficulty level
  Future<List<PuzzleModel>> getPuzzlesByDifficulty(
    PuzzleDifficulty difficulty,
  ) async {
    try {
      final allPuzzles = await loadPuzzles();
      final filteredPuzzles = allPuzzles
          .where((puzzle) => puzzle.difficulty == difficulty)
          .toList();

      _logger.i(
        'Found ${filteredPuzzles.length} puzzles for difficulty: ${difficulty.displayName}',
      );

      // Return empty list instead of throwing if no puzzles found
      return filteredPuzzles;
    } catch (e) {
      _logger.e('Error getting puzzles by difficulty $difficulty: $e');
      // Return empty list as fallback instead of rethrowing
      return [];
    }
  }

  /// Get a specific puzzle by its ID
  Future<PuzzleModel?> getPuzzleById(String puzzleId) async {
    try {
      final allPuzzles = await loadPuzzles();
      final puzzle = allPuzzles.where((p) => p.id == puzzleId).firstOrNull;

      if (puzzle != null) {
        _logger.i('Found puzzle: $puzzleId');
      } else {
        _logger.w('Puzzle not found: $puzzleId');
      }

      return puzzle;
    } catch (e) {
      _logger.e('Error getting puzzle by ID $puzzleId: $e');
      return null;
    }
  }

  /// Initialize Stockfish service for puzzle solving
  Future<void> initializeStockfish() async {
    if (_stockfishInitialized) return;

    try {
      await _stockfishService.initialize();
      _stockfishInitialized = true;
      _logger.i('Stockfish puzzle service initialized');
    } catch (e) {
      _logger.e('Failed to initialize Stockfish puzzle service: $e');
      _stockfishInitialized = false;
    }
  }

  /// Get or calculate puzzle solution using engine
  Future<PuzzleSolution?> getPuzzleSolution(PuzzleModel puzzle) async {
    try {
      // Check cached solution first
      if (_cachedSolutions.containsKey(puzzle.id)) {
        _logger.i('Using cached solution for puzzle ${puzzle.id}');
        return _cachedSolutions[puzzle.id];
      }

      // Check Firestore for existing solution
      final firestoreSolution = await _getFirestoreSolution(puzzle.id);
      if (firestoreSolution != null) {
        _cachedSolutions[puzzle.id] = firestoreSolution;
        _logger.i('Found Firestore solution for puzzle ${puzzle.id}');
        return firestoreSolution;
      }

      // Calculate new solution using engine
      await initializeStockfish();
      if (!_stockfishInitialized) {
        _logger.w(
          'Stockfish not available, using predefined solution for ${puzzle.id}',
        );
        return null;
      }

      _logger.i('Calculating new engine solution for puzzle ${puzzle.id}');
      final engineSolution = await _stockfishService.calculatePuzzleSolution(
        puzzle,
      );

      // Save solution to Firestore for global access
      await _saveSolutionToFirestore(engineSolution);

      // Cache the solution
      _cachedSolutions[puzzle.id] = engineSolution;

      return engineSolution;
    } catch (e) {
      _logger.e('Error getting puzzle solution for ${puzzle.id}: $e');
      return null;
    }
  }

  /// Validate if a move is correct using engine solution or fallback to predefined
  Future<bool> validateMove(
    PuzzleModel puzzle,
    List<String> userMoves,
    String newMove,
  ) async {
    try {
      final int moveIndex = userMoves.length;

      // Try to get engine solution first
      final engineSolution = await getPuzzleSolution(puzzle);

      List<String> solutionMoves;
      if (engineSolution != null && engineSolution.engineMoves.isNotEmpty) {
        solutionMoves = engineSolution.engineMoves;
        _logger.i(
          'Using engine solution for validation: ${solutionMoves.join(', ')}',
        );
      } else {
        // Fallback to predefined solution
        solutionMoves = puzzle.solution;
        _logger.i(
          'Using predefined solution for validation: ${solutionMoves.join(', ')}',
        );
      }

      // Check if we have more moves in the solution
      if (moveIndex >= solutionMoves.length) {
        _logger.w('No more moves expected in solution for puzzle ${puzzle.id}');
        return false;
      }

      // Check if the move matches the expected solution move
      final bool isCorrect = solutionMoves[moveIndex] == newMove;

      _logger.i(
        'Move validation for puzzle ${puzzle.id}: $newMove ${isCorrect ? 'correct' : 'incorrect'}',
      );
      return isCorrect;
    } catch (e) {
      _logger.e('Error validating move for puzzle ${puzzle.id}: $e');
      // Fallback to original validation
      return _validateMoveWithPredefinedSolution(puzzle, userMoves, newMove);
    }
  }

  /// Fallback validation using predefined solution
  bool _validateMoveWithPredefinedSolution(
    PuzzleModel puzzle,
    List<String> userMoves,
    String newMove,
  ) {
    try {
      final int moveIndex = userMoves.length;

      // Check if we have more moves in the solution
      if (moveIndex >= puzzle.solution.length) {
        _logger.w('No more moves expected in solution for puzzle ${puzzle.id}');
        return false;
      }

      // Check if the move matches the expected solution move
      final bool isCorrect = puzzle.solution[moveIndex] == newMove;

      _logger.i(
        'Move validation for puzzle ${puzzle.id}: $newMove ${isCorrect ? 'correct' : 'incorrect'}',
      );
      return isCorrect;
    } catch (e) {
      _logger.e('Error validating move for puzzle ${puzzle.id}: $e');
      return false;
    }
  }

  /// Check if the puzzle is completely solved using engine solution or fallback
  Future<bool> isPuzzleSolved(
    PuzzleModel puzzle,
    List<String> userMoves,
  ) async {
    try {
      // Try to get engine solution first
      final engineSolution = await getPuzzleSolution(puzzle);

      List<String> solutionMoves;
      if (engineSolution != null && engineSolution.engineMoves.isNotEmpty) {
        solutionMoves = engineSolution.engineMoves;
      } else {
        // Fallback to predefined solution
        solutionMoves = puzzle.solution;
      }

      final bool solved =
          userMoves.length == solutionMoves.length &&
          _areMovesCorrect(solutionMoves, userMoves);

      _logger.i('Puzzle ${puzzle.id} solved status: $solved');
      return solved;
    } catch (e) {
      _logger.e('Error checking if puzzle ${puzzle.id} is solved: $e');
      // Fallback to predefined solution check
      return _isPuzzleSolvedWithPredefinedSolution(puzzle, userMoves);
    }
  }

  /// Fallback check using predefined solution
  bool _isPuzzleSolvedWithPredefinedSolution(
    PuzzleModel puzzle,
    List<String> userMoves,
  ) {
    try {
      final bool solved =
          userMoves.length == puzzle.solution.length &&
          _areMovesCorrect(puzzle.solution, userMoves);

      _logger.i('Puzzle ${puzzle.id} solved status: $solved');
      return solved;
    } catch (e) {
      _logger.e('Error checking if puzzle ${puzzle.id} is solved: $e');
      return false;
    }
  }

  /// Helper method to check if all user moves match the solution
  bool _areMovesCorrect(List<String> solutionMoves, List<String> userMoves) {
    if (userMoves.length > solutionMoves.length) {
      return false;
    }

    for (int i = 0; i < userMoves.length; i++) {
      if (userMoves[i] != solutionMoves[i]) {
        return false;
      }
    }

    return true;
  }

  /// Get the next hint for a puzzle
  String? getNextHint(PuzzleModel puzzle, int hintIndex) {
    try {
      if (hintIndex < 0 || hintIndex >= puzzle.hints.length) {
        _logger.w('Invalid hint index $hintIndex for puzzle ${puzzle.id}');
        return null;
      }

      final hint = puzzle.hints[hintIndex];
      _logger.i('Providing hint $hintIndex for puzzle ${puzzle.id}');
      return hint;
    } catch (e) {
      _logger.e('Error getting hint for puzzle ${puzzle.id}: $e');
      return null;
    }
  }

  /// Save puzzle progress to local storage
  Future<void> savePuzzleProgress(PuzzleProgress progress) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key =
          '$_puzzleProgressPrefix${progress.userId}_${progress.puzzleId}';
      final jsonString = json.encode(progress.toJson());

      final success = await prefs.setString(key, jsonString);
      if (!success) {
        throw Exception('Failed to save progress to local storage');
      }

      _logger.i(
        'Saved progress for puzzle ${progress.puzzleId} for user ${progress.userId}',
      );
    } catch (e) {
      _logger.e('Error saving puzzle progress: $e');
      // Don't rethrow for progress saving failures - log and continue
      // This prevents the app from crashing if storage is full or unavailable
    }
  }

  /// Get puzzle progress from local storage
  Future<PuzzleProgress?> getPuzzleProgress(
    String userId,
    String puzzleId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_puzzleProgressPrefix${userId}_$puzzleId';
      final jsonString = prefs.getString(key);

      if (jsonString != null) {
        final jsonData = json.decode(jsonString) as Map<String, dynamic>;
        final progress = PuzzleProgress.fromJson(jsonData);
        _logger.i('Retrieved progress for puzzle $puzzleId for user $userId');
        return progress;
      }

      _logger.i('No progress found for puzzle $puzzleId for user $userId');
      return null;
    } catch (e) {
      _logger.e('Error getting puzzle progress for $userId/$puzzleId: $e');
      return null;
    }
  }

  /// Get completion statistics by difficulty level for a user
  Future<Map<PuzzleDifficulty, int>> getCompletionStats(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      final userProgressKeys = allKeys
          .where((key) => key.startsWith('$_puzzleProgressPrefix$userId'))
          .toList();

      final Map<PuzzleDifficulty, int> stats = {};

      // Initialize all difficulties with 0
      for (final difficulty in PuzzleDifficulty.values) {
        stats[difficulty] = 0;
      }

      // Count completed puzzles by difficulty
      int corruptedRecords = 0;
      for (final key in userProgressKeys) {
        final jsonString = prefs.getString(key);
        if (jsonString != null && jsonString.isNotEmpty) {
          try {
            final jsonData = json.decode(jsonString) as Map<String, dynamic>;
            final progress = PuzzleProgress.fromJson(jsonData);

            if (progress.completed) {
              stats[progress.difficulty] =
                  (stats[progress.difficulty] ?? 0) + 1;
            }
          } catch (e) {
            corruptedRecords++;
            _logger.w('Error parsing progress data for key $key: $e');
            // Remove corrupted record
            try {
              await prefs.remove(key);
            } catch (removeError) {
              _logger.w('Failed to remove corrupted record $key: $removeError');
            }
          }
        }
      }

      if (corruptedRecords > 0) {
        _logger.w(
          'Removed $corruptedRecords corrupted progress records for user $userId',
        );
      }

      _logger.i('Completion stats for user $userId: $stats');
      return stats;
    } catch (e) {
      _logger.e('Error getting completion stats for user $userId: $e');
      // Return empty stats as fallback
      final Map<PuzzleDifficulty, int> fallbackStats = {};
      for (final difficulty in PuzzleDifficulty.values) {
        fallbackStats[difficulty] = 0;
      }
      return fallbackStats;
    }
  }

  /// Get total puzzle count by difficulty level
  Future<Map<PuzzleDifficulty, int>> getPuzzleCountsByDifficulty() async {
    try {
      final allPuzzles = await loadPuzzles();
      final Map<PuzzleDifficulty, int> counts = {};

      // Initialize all difficulties with 0
      for (final difficulty in PuzzleDifficulty.values) {
        counts[difficulty] = 0;
      }

      // Count puzzles by difficulty
      for (final puzzle in allPuzzles) {
        counts[puzzle.difficulty] = (counts[puzzle.difficulty] ?? 0) + 1;
      }

      _logger.i('Puzzle counts by difficulty: $counts');
      return counts;
    } catch (e) {
      _logger.e('Error getting puzzle counts by difficulty: $e');
      return {};
    }
  }

  /// Get all puzzle progress for a user
  Future<List<PuzzleProgress>> getAllUserProgress(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      final userProgressKeys = allKeys
          .where((key) => key.startsWith('$_puzzleProgressPrefix$userId'))
          .toList();

      final List<PuzzleProgress> progressList = [];

      for (final key in userProgressKeys) {
        final jsonString = prefs.getString(key);
        if (jsonString != null) {
          try {
            final jsonData = json.decode(jsonString) as Map<String, dynamic>;
            final progress = PuzzleProgress.fromJson(jsonData);
            progressList.add(progress);
          } catch (e) {
            _logger.w('Error parsing progress data for key $key: $e');
          }
        }
      }

      _logger.i(
        'Retrieved ${progressList.length} progress records for user $userId',
      );
      return progressList;
    } catch (e) {
      _logger.e('Error getting all user progress for $userId: $e');
      return [];
    }
  }

  /// Clear all puzzle progress for a user (useful for testing or reset)
  Future<void> clearUserProgress(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      final userProgressKeys = allKeys
          .where((key) => key.startsWith('$_puzzleProgressPrefix$userId'))
          .toList();

      for (final key in userProgressKeys) {
        await prefs.remove(key);
      }

      _logger.i(
        'Cleared all progress for user $userId (${userProgressKeys.length} records)',
      );
    } catch (e) {
      _logger.e('Error clearing user progress for $userId: $e');
      rethrow;
    }
  }

  /// Get the next puzzle in a difficulty level
  Future<PuzzleModel?> getNextPuzzle(
    String userId,
    PuzzleDifficulty difficulty,
    String currentPuzzleId,
  ) async {
    try {
      final puzzles = await getPuzzlesByDifficulty(difficulty);
      final currentIndex = puzzles.indexWhere((p) => p.id == currentPuzzleId);

      if (currentIndex == -1) {
        _logger.w(
          'Current puzzle $currentPuzzleId not found in difficulty ${difficulty.displayName}',
        );
        return puzzles.isNotEmpty ? puzzles.first : null;
      }

      if (currentIndex + 1 < puzzles.length) {
        final nextPuzzle = puzzles[currentIndex + 1];
        _logger.i('Next puzzle for user $userId: ${nextPuzzle.id}');
        return nextPuzzle;
      }

      _logger.i(
        'No more puzzles available in difficulty ${difficulty.displayName}',
      );
      return null;
    } catch (e) {
      _logger.e('Error getting next puzzle: $e');
      return null;
    }
  }

  /// Get the first unsolved puzzle in a difficulty level
  Future<PuzzleModel?> getFirstUnsolvedPuzzle(
    String userId,
    PuzzleDifficulty difficulty,
  ) async {
    try {
      final puzzles = await getPuzzlesByDifficulty(difficulty);

      for (final puzzle in puzzles) {
        final progress = await getPuzzleProgress(userId, puzzle.id);
        if (progress == null || !progress.completed) {
          _logger.i(
            'First unsolved puzzle for user $userId in ${difficulty.displayName}: ${puzzle.id}',
          );
          return puzzle;
        }
      }

      _logger.i(
        'All puzzles completed in difficulty ${difficulty.displayName} for user $userId',
      );
      return null;
    } catch (e) {
      _logger.e('Error getting first unsolved puzzle: $e');
      return null;
    }
  }

  /// Get solution from Firestore
  Future<PuzzleSolution?> _getFirestoreSolution(String puzzleId) async {
    try {
      final doc = await _firestore
          .collection(_puzzleSolutionsCollection)
          .doc(puzzleId)
          .get();

      if (doc.exists && doc.data() != null) {
        return PuzzleSolution.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      _logger.e('Error getting Firestore solution for $puzzleId: $e');
      return null;
    }
  }

  /// Save solution to Firestore
  Future<void> _saveSolutionToFirestore(PuzzleSolution solution) async {
    try {
      await _firestore
          .collection(_puzzleSolutionsCollection)
          .doc(solution.puzzleId)
          .set(solution.toJson());

      _logger.i('Saved solution to Firestore for puzzle ${solution.puzzleId}');
    } catch (e) {
      _logger.e(
        'Error saving solution to Firestore for ${solution.puzzleId}: $e',
      );
      // Don't rethrow - this is not critical for puzzle solving
    }
  }

  /// Check if a puzzle has an engine solution available
  Future<bool> hasEngineSolution(String puzzleId) async {
    try {
      if (_cachedSolutions.containsKey(puzzleId)) {
        return true;
      }

      final solution = await _getFirestoreSolution(puzzleId);
      return solution != null;
    } catch (e) {
      _logger.e('Error checking engine solution for $puzzleId: $e');
      return false;
    }
  }

  /// Get all puzzle solutions from Firestore (for admin purposes)
  Future<List<PuzzleSolution>> getAllSolutions() async {
    try {
      final querySnapshot = await _firestore
          .collection(_puzzleSolutionsCollection)
          .get();

      return querySnapshot.docs
          .map((doc) => PuzzleSolution.fromJson(doc.data()))
          .toList();
    } catch (e) {
      _logger.e('Error getting all solutions: $e');
      return [];
    }
  }

  /// Dispose of resources
  void dispose() {
    _stockfishService.dispose();
    _cachedSolutions.clear();
    _logger.i('PuzzleService disposed');
  }
}
