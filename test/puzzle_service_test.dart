import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_chess_app/services/puzzle_service.dart';
import 'package:flutter_chess_app/models/puzzle_model.dart';
import 'package:flutter_chess_app/models/puzzle_progress.dart';

void main() {
  group('PuzzleService Tests', () {
    late PuzzleService puzzleService;

    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    setUp(() {
      puzzleService = PuzzleService();
      SharedPreferences.setMockInitialValues({});
    });

    test('should load puzzles from assets', () async {
      // Skip this test for now as it requires complex asset mocking
      // The actual asset loading will be tested in integration tests
    }, skip: true);

    test('should validate moves correctly', () async {
      const puzzle = PuzzleModel(
        id: 'test_001',
        fen: 'test_fen',
        solution: ['e4', 'e5', 'Nf3'],
        objective: 'Test objective',
        difficulty: PuzzleDifficulty.beginner,
        rating: 800,
        hints: ['hint1', 'hint2'],
        tags: ['test'],
        opponentPlaysFirst: false,
      );

      // Test correct first move
      expect(puzzleService.validateMove(puzzle, [], 'e4'), true);

      // Test incorrect first move
      expect(puzzleService.validateMove(puzzle, [], 'd4'), false);

      // Test correct second move
      expect(puzzleService.validateMove(puzzle, ['e4'], 'e5'), true);

      // Test move beyond solution length
      expect(
        puzzleService.validateMove(puzzle, ['e4', 'e5', 'Nf3'], 'Nc3'),
        false,
      );
    });

    test('should check puzzle completion correctly', () async {
      const puzzle = PuzzleModel(
        id: 'test_001',
        fen: 'test_fen',
        solution: ['e4', 'e5'],
        objective: 'Test objective',
        difficulty: PuzzleDifficulty.beginner,
        rating: 800,
        hints: ['hint1'],
        tags: ['test'],
        opponentPlaysFirst: false,
      );

      // Test incomplete puzzle
      expect(puzzleService.isPuzzleSolved(puzzle, ['e4']), false);

      // Test complete puzzle
      expect(puzzleService.isPuzzleSolved(puzzle, ['e4', 'e5']), true);

      // Test incorrect moves
      expect(puzzleService.isPuzzleSolved(puzzle, ['d4', 'e5']), false);
    });

    test('should provide hints correctly', () async {
      const puzzle = PuzzleModel(
        id: 'test_001',
        fen: 'test_fen',
        solution: ['e4'],
        objective: 'Test objective',
        difficulty: PuzzleDifficulty.beginner,
        rating: 800,
        hints: ['First hint', 'Second hint'],
        tags: ['test'],
        opponentPlaysFirst: false,
      );

      expect(puzzleService.getNextHint(puzzle, 0), 'First hint');
      expect(puzzleService.getNextHint(puzzle, 1), 'Second hint');
      expect(puzzleService.getNextHint(puzzle, 2), null);
      expect(puzzleService.getNextHint(puzzle, -1), null);
    });

    test('should save and retrieve puzzle progress', () async {
      const userId = 'test_user';
      const puzzleId = 'test_puzzle';

      final progress = PuzzleProgress.newAttempt(
        userId: userId,
        puzzleId: puzzleId,
        difficulty: PuzzleDifficulty.beginner,
      );

      await puzzleService.savePuzzleProgress(progress);

      final retrievedProgress = await puzzleService.getPuzzleProgress(
        userId,
        puzzleId,
      );

      expect(retrievedProgress, isNotNull);
      expect(retrievedProgress!.userId, userId);
      expect(retrievedProgress.puzzleId, puzzleId);
      expect(retrievedProgress.completed, false);
    });

    test('should get completion statistics', () async {
      const userId = 'test_user';

      // Save some completed progress
      final progress1 = PuzzleProgress.newAttempt(
        userId: userId,
        puzzleId: 'puzzle1',
        difficulty: PuzzleDifficulty.beginner,
      ).markCompleted(solveTime: const Duration(seconds: 30), hintsUsed: 0);

      final progress2 = PuzzleProgress.newAttempt(
        userId: userId,
        puzzleId: 'puzzle2',
        difficulty: PuzzleDifficulty.beginner,
      ).markCompleted(solveTime: const Duration(seconds: 45), hintsUsed: 1);

      final progress3 = PuzzleProgress.newAttempt(
        userId: userId,
        puzzleId: 'puzzle3',
        difficulty: PuzzleDifficulty.easy,
      ); // Not completed

      await puzzleService.savePuzzleProgress(progress1);
      await puzzleService.savePuzzleProgress(progress2);
      await puzzleService.savePuzzleProgress(progress3);

      final stats = await puzzleService.getCompletionStats(userId);

      expect(stats[PuzzleDifficulty.beginner], 2);
      expect(stats[PuzzleDifficulty.easy], 0);
      expect(stats[PuzzleDifficulty.medium], 0);
    });
  });
}
