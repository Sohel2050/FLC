import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import '../models/puzzle_model.dart';
import '../models/puzzle_progress.dart';
import '../utils/fallback_puzzles.dart';

/// Service for managing chess puzzles data and progress
class PuzzleService {
  static const String _puzzleProgressPrefix = 'puzzle_progress_';
  static const String _puzzleAssetPath = 'assets/puzzles/puzzles.json';

  final Logger _logger = Logger();
  List<PuzzleModel>? _cachedPuzzles;

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

  /// Validate if a move is correct for the current puzzle state
  bool validateMove(
    PuzzleModel puzzle,
    List<String> userMoves,
    String newMove, {
    bool hasOpponentFirstMove = false,
  }) {
    try {
      // Calculate the expected move index in the solution
      // If opponent played first move automatically, offset by 1
      int moveIndex = userMoves.length;
      if (hasOpponentFirstMove) {
        moveIndex += 1; // Account for the opponent's automatic first move
      }

      // Check if we have more moves in the solution
      if (moveIndex >= puzzle.solution.length) {
        _logger.w('No more moves expected in solution for puzzle ${puzzle.id}');
        return false;
      }

      // Check if the move matches the expected solution move
      final bool isCorrect = puzzle.solution[moveIndex] == newMove;

      _logger.i(
        'Move validation for puzzle ${puzzle.id}: $newMove ${isCorrect ? 'correct' : 'incorrect'} (moveIndex: $moveIndex, hasOpponentFirstMove: $hasOpponentFirstMove)',
      );
      return isCorrect;
    } catch (e) {
      _logger.e('Error validating move for puzzle ${puzzle.id}: $e');
      return false;
    }
  }

  /// Check if the puzzle is completely solved
  bool isPuzzleSolved(PuzzleModel puzzle, List<String> userMoves) {
    try {
      final bool solved =
          userMoves.length == puzzle.solution.length &&
          _areMovesCorrect(puzzle, userMoves);

      _logger.i('Puzzle ${puzzle.id} solved status: $solved');
      return solved;
    } catch (e) {
      _logger.e('Error checking if puzzle ${puzzle.id} is solved: $e');
      return false;
    }
  }

  /// Helper method to check if all user moves match the solution
  bool _areMovesCorrect(PuzzleModel puzzle, List<String> userMoves) {
    if (userMoves.length > puzzle.solution.length) {
      return false;
    }

    for (int i = 0; i < userMoves.length; i++) {
      if (userMoves[i] != puzzle.solution[i]) {
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
}
