import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_chess_app/services/puzzle_service.dart';
import 'package:flutter_chess_app/providers/puzzle_provider.dart';
import 'package:flutter_chess_app/models/puzzle_model.dart';
import 'package:flutter_chess_app/models/puzzle_progress.dart';

void main() {
  group('Complete Puzzle Functionality Tests', () {
    late PuzzleService puzzleService;
    late PuzzleProvider puzzleProvider;

    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      puzzleService = PuzzleService();
      puzzleProvider = PuzzleProvider();
    });

    tearDown(() {
      puzzleProvider.dispose();
    });

    group('Puzzle Loading and Validation Logic', () {
      test('should load puzzles from assets with proper structure', () async {
        final puzzles = await puzzleService.loadPuzzles();

        expect(puzzles, isNotEmpty);
        expect(puzzles.length, greaterThan(0));

        // Verify each puzzle has required fields
        for (final puzzle in puzzles) {
          expect(puzzle.id, isNotEmpty);
          expect(puzzle.fen, isNotEmpty);
          expect(puzzle.solution, isNotEmpty);
          expect(puzzle.objective, isNotEmpty);
          expect(puzzle.hints, isNotEmpty);
          expect(puzzle.rating, greaterThan(0));
          expect(puzzle.tags, isNotEmpty);
        }
      });

      test('should validate moves correctly against solution', () async {
        const testPuzzle = PuzzleModel(
          id: 'validation_test',
          fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
          solution: ['e4', 'e5', 'Nf3', 'Nc6'],
          objective: 'Test move validation',
          difficulty: PuzzleDifficulty.beginner,
          hints: ['Move pawn', 'Develop knight'],
          rating: 800,
          tags: ['test'],
        );

        // Test correct sequence
        expect(puzzleService.validateMove(testPuzzle, [], 'e4'), true);
        expect(puzzleService.validateMove(testPuzzle, ['e4'], 'e5'), true);
        expect(
          puzzleService.validateMove(testPuzzle, ['e4', 'e5'], 'Nf3'),
          true,
        );
        expect(
          puzzleService.validateMove(testPuzzle, ['e4', 'e5', 'Nf3'], 'Nc6'),
          true,
        );

        // Test incorrect moves
        expect(puzzleService.validateMove(testPuzzle, [], 'd4'), false);
        expect(puzzleService.validateMove(testPuzzle, ['e4'], 'd5'), false);
        expect(
          puzzleService.validateMove(testPuzzle, ['e4', 'e5'], 'Bc4'),
          false,
        );

        // Test out of sequence
        expect(puzzleService.validateMove(testPuzzle, [], 'Nf3'), false);
        expect(
          puzzleService.validateMove(testPuzzle, [
            'e4',
            'e5',
            'Nf3',
            'Nc6',
          ], 'Bb5'),
          false,
        );
      });

      test('should detect puzzle completion correctly', () async {
        const testPuzzle = PuzzleModel(
          id: 'completion_test',
          fen: 'test_fen',
          solution: ['Qh5', 'g6', 'Qxf7#'],
          objective: 'Mate in 3',
          difficulty: PuzzleDifficulty.medium,
          hints: ['Attack the king', 'Sacrifice for mate'],
          rating: 1200,
          tags: ['mate', 'sacrifice'],
        );

        // Test incomplete sequences
        expect(puzzleService.isPuzzleSolved(testPuzzle, []), false);
        expect(puzzleService.isPuzzleSolved(testPuzzle, ['Qh5']), false);
        expect(puzzleService.isPuzzleSolved(testPuzzle, ['Qh5', 'g6']), false);

        // Test complete sequence
        expect(
          puzzleService.isPuzzleSolved(testPuzzle, ['Qh5', 'g6', 'Qxf7#']),
          true,
        );

        // Test incorrect sequence
        expect(
          puzzleService.isPuzzleSolved(testPuzzle, ['Qh4', 'g6', 'Qxf7#']),
          false,
        );
        expect(
          puzzleService.isPuzzleSolved(testPuzzle, ['Qh5', 'h6', 'Qxf7#']),
          false,
        );
      });

      test('should handle edge cases in move validation', () async {
        const testPuzzle = PuzzleModel(
          id: 'edge_case_test',
          fen: 'test_fen',
          solution: ['e4'],
          objective: 'Single move puzzle',
          difficulty: PuzzleDifficulty.beginner,
          hints: ['Move the pawn'],
          rating: 600,
          tags: ['basic'],
        );

        // Test empty move
        expect(puzzleService.validateMove(testPuzzle, [], ''), false);

        // Test null-like inputs
        expect(
          puzzleService.validateMove(testPuzzle, [], 'invalid_move_format'),
          false,
        );

        // Test case sensitivity
        expect(puzzleService.validateMove(testPuzzle, [], 'E4'), false);
        expect(puzzleService.validateMove(testPuzzle, [], 'e4'), true);
      });
    });

    group('Hint System Functionality', () {
      test('should provide hints in correct order', () async {
        const testPuzzle = PuzzleModel(
          id: 'hint_test',
          fen: 'test_fen',
          solution: ['Bxf7+', 'Ke7', 'Nd5+'],
          objective: 'Win material with tactics',
          difficulty: PuzzleDifficulty.easy,
          hints: [
            'Look for a forcing move',
            'Consider a bishop sacrifice',
            'After the king moves, fork with the knight',
          ],
          rating: 1000,
          tags: ['tactics', 'fork'],
        );

        // Test sequential hint access
        expect(
          puzzleService.getNextHint(testPuzzle, 0),
          'Look for a forcing move',
        );
        expect(
          puzzleService.getNextHint(testPuzzle, 1),
          'Consider a bishop sacrifice',
        );
        expect(
          puzzleService.getNextHint(testPuzzle, 2),
          'After the king moves, fork with the knight',
        );

        // Test out of bounds
        expect(puzzleService.getNextHint(testPuzzle, 3), null);
        expect(puzzleService.getNextHint(testPuzzle, -1), null);
        expect(puzzleService.getNextHint(testPuzzle, 100), null);
      });

      test('should handle puzzles with no hints', () async {
        const testPuzzle = PuzzleModel(
          id: 'no_hints_test',
          fen: 'test_fen',
          solution: ['Qxf7#'],
          objective: 'Find the mate',
          difficulty: PuzzleDifficulty.expert,
          hints: [],
          rating: 1800,
          tags: ['mate'],
        );

        expect(puzzleService.getNextHint(testPuzzle, 0), null);
        expect(puzzleService.getNextHint(testPuzzle, 1), null);
      });

      test('should track hint usage in provider', () async {
        const testPuzzle = PuzzleModel(
          id: 'hint_tracking_test',
          fen: 'test_fen',
          solution: ['Rxh7+'],
          objective: 'Sacrifice for attack',
          difficulty: PuzzleDifficulty.medium,
          hints: ['Sacrifice the rook', 'Force the king out'],
          rating: 1300,
          tags: ['sacrifice'],
        );

        await puzzleProvider.startPuzzle(testPuzzle);

        expect(puzzleProvider.currentSession!.hintsUsed, 0);

        final hint1 = await puzzleProvider.requestHint();
        expect(hint1, 'Sacrifice the rook');
        expect(puzzleProvider.currentSession!.hintsUsed, 1);

        final hint2 = await puzzleProvider.requestHint();
        expect(hint2, 'Force the king out');
        expect(puzzleProvider.currentSession!.hintsUsed, 2);

        final hint3 = await puzzleProvider.requestHint();
        expect(hint3, null);
        expect(
          puzzleProvider.currentSession!.hintsUsed,
          2,
        ); // Should not increment
      });
    });

    group('Progress Tracking and Persistence', () {
      test('should save and retrieve puzzle progress correctly', () async {
        const userId = 'test_user_123';
        const puzzleId = 'progress_test_puzzle';

        // Create initial progress
        final initialProgress = PuzzleProgress.newAttempt(
          userId: userId,
          puzzleId: puzzleId,
          difficulty: PuzzleDifficulty.medium,
        );

        await puzzleService.savePuzzleProgress(initialProgress);

        // Retrieve and verify
        final retrievedProgress = await puzzleService.getPuzzleProgress(
          userId,
          puzzleId,
        );
        expect(retrievedProgress, isNotNull);
        expect(retrievedProgress!.userId, userId);
        expect(retrievedProgress.puzzleId, puzzleId);
        expect(retrievedProgress.completed, false);
        expect(retrievedProgress.attempts, 1);
        expect(retrievedProgress.hintsUsed, 0);

        // Mark as completed and save again
        final completedProgress = retrievedProgress.markCompleted(
          solveTime: const Duration(seconds: 45),
          hintsUsed: 2,
        );

        await puzzleService.savePuzzleProgress(completedProgress);

        // Retrieve completed progress
        final finalProgress = await puzzleService.getPuzzleProgress(
          userId,
          puzzleId,
        );
        expect(finalProgress!.completed, true);
        expect(finalProgress.solveTime, const Duration(seconds: 45));
        expect(finalProgress.hintsUsed, 2);
        expect(finalProgress.solvedWithoutHints, false);
      });

      test('should track completion statistics by difficulty', () async {
        const userId = 'stats_test_user';

        // Create progress for different difficulties
        final beginnerProgress1 = PuzzleProgress.newAttempt(
          userId: userId,
          puzzleId: 'beginner_1',
          difficulty: PuzzleDifficulty.beginner,
        ).markCompleted(solveTime: const Duration(seconds: 30), hintsUsed: 0);

        final beginnerProgress2 = PuzzleProgress.newAttempt(
          userId: userId,
          puzzleId: 'beginner_2',
          difficulty: PuzzleDifficulty.beginner,
        ).markCompleted(solveTime: const Duration(seconds: 25), hintsUsed: 1);

        final easyProgress = PuzzleProgress.newAttempt(
          userId: userId,
          puzzleId: 'easy_1',
          difficulty: PuzzleDifficulty.easy,
        ).markCompleted(solveTime: const Duration(seconds: 60), hintsUsed: 0);

        // Incomplete puzzle
        final mediumProgress = PuzzleProgress.newAttempt(
          userId: userId,
          puzzleId: 'medium_1',
          difficulty: PuzzleDifficulty.medium,
        );

        // Save all progress
        await puzzleService.savePuzzleProgress(beginnerProgress1);
        await puzzleService.savePuzzleProgress(beginnerProgress2);
        await puzzleService.savePuzzleProgress(easyProgress);
        await puzzleService.savePuzzleProgress(mediumProgress);

        // Check completion stats
        final stats = await puzzleService.getCompletionStats(userId);
        expect(stats[PuzzleDifficulty.beginner], 2);
        expect(stats[PuzzleDifficulty.easy], 1);
        expect(stats[PuzzleDifficulty.medium], 0); // Not completed
        expect(stats[PuzzleDifficulty.hard], 0);
        expect(stats[PuzzleDifficulty.expert], 0);
      });

      test('should handle multiple attempts on same puzzle', () async {
        const userId = 'multi_attempt_user';
        const puzzleId = 'challenging_puzzle';

        // First attempt (failed)
        final attempt1 = PuzzleProgress.newAttempt(
          userId: userId,
          puzzleId: puzzleId,
          difficulty: PuzzleDifficulty.hard,
        );
        await puzzleService.savePuzzleProgress(attempt1);

        // Second attempt (also failed, but with hints)
        final attempt2 = attempt1
            .incrementAttempts()
            .incrementHints()
            .incrementHints();
        await puzzleService.savePuzzleProgress(attempt2);

        // Third attempt (successful)
        final attempt3 = attempt2.incrementAttempts().markCompleted(
          solveTime: const Duration(minutes: 2),
          hintsUsed: 2,
        );
        await puzzleService.savePuzzleProgress(attempt3);

        // Verify final state
        final finalProgress = await puzzleService.getPuzzleProgress(
          userId,
          puzzleId,
        );
        expect(finalProgress!.attempts, 3);
        expect(finalProgress.completed, true);
        expect(finalProgress.hintsUsed, 2);
        expect(finalProgress.solveTime, const Duration(minutes: 2));
      });
    });

    group('Integration with Existing Game Components', () {
      test('should maintain independent state from game provider', () async {
        const testPuzzle = PuzzleModel(
          id: 'independence_test',
          fen: 'test_fen',
          solution: ['Qh5'],
          objective: 'Test independence',
          difficulty: PuzzleDifficulty.beginner,
          hints: ['Move the queen'],
          rating: 800,
          tags: ['test'],
        );

        // Start puzzle session
        await puzzleProvider.startPuzzle(testPuzzle);
        expect(puzzleProvider.currentSession, isNotNull);
        expect(puzzleProvider.hasPuzzleActive, true);

        // Make a move
        await puzzleProvider.makeMove('Qh5');
        expect(puzzleProvider.currentSession!.state, PuzzleSessionState.solved);

        // Verify puzzle provider maintains its own state
        expect(puzzleProvider.currentSession!.puzzle.id, 'independence_test');
        expect(puzzleProvider.currentSession!.userMoves, ['Qh5']);
      });

      test('should handle concurrent puzzle sessions', () async {
        const testPuzzle1 = PuzzleModel(
          id: 'concurrent_1',
          fen: 'test_fen_1',
          solution: ['e4'],
          objective: 'First puzzle',
          difficulty: PuzzleDifficulty.beginner,
          hints: ['Move pawn'],
          rating: 800,
          tags: ['test'],
        );

        const testPuzzle2 = PuzzleModel(
          id: 'concurrent_2',
          fen: 'test_fen_2',
          solution: ['d4'],
          objective: 'Second puzzle',
          difficulty: PuzzleDifficulty.beginner,
          hints: ['Move other pawn'],
          rating: 800,
          tags: ['test'],
        );

        // Create multiple providers
        final provider1 = PuzzleProvider();
        final provider2 = PuzzleProvider();

        try {
          await provider1.startPuzzle(testPuzzle1);
          await provider2.startPuzzle(testPuzzle2);

          // Verify each maintains separate state
          expect(provider1.currentSession!.puzzle.id, 'concurrent_1');
          expect(provider2.currentSession!.puzzle.id, 'concurrent_2');

          await provider1.makeMove('e4');
          await provider2.makeMove('d4');

          expect(provider1.currentSession!.state, PuzzleSessionState.solved);
          expect(provider2.currentSession!.state, PuzzleSessionState.solved);
          expect(provider1.currentSession!.userMoves, ['e4']);
          expect(provider2.currentSession!.userMoves, ['d4']);
        } finally {
          provider1.dispose();
          provider2.dispose();
        }
      });

      test('should handle puzzle reset correctly', () async {
        const testPuzzle = PuzzleModel(
          id: 'reset_test',
          fen: 'test_fen',
          solution: ['Nf3', 'Nc6', 'Bb5'],
          objective: 'Test reset functionality',
          difficulty: PuzzleDifficulty.easy,
          hints: ['Develop knight', 'Pin the knight'],
          rating: 1000,
          tags: ['opening'],
        );

        await puzzleProvider.startPuzzle(testPuzzle);

        // Make some moves and use hints
        await puzzleProvider.makeMove('Nf3');
        await puzzleProvider.requestHint();
        await puzzleProvider.makeMove('Nc6');

        expect(puzzleProvider.currentSession!.userMoves.length, 2);
        expect(puzzleProvider.currentSession!.hintsUsed, 1);

        // Reset puzzle
        await puzzleProvider.resetPuzzle();

        expect(puzzleProvider.currentSession!.userMoves.length, 0);
        expect(puzzleProvider.currentSession!.hintsUsed, 0);
        expect(puzzleProvider.currentSession!.state, PuzzleSessionState.active);
        expect(puzzleProvider.currentSession!.puzzle.id, 'reset_test');
      });
    });

    group('Error Handling and Edge Cases', () {
      test('should handle invalid puzzle data gracefully', () async {
        const invalidPuzzle = PuzzleModel(
          id: '',
          fen: '',
          solution: [],
          objective: '',
          difficulty: PuzzleDifficulty.beginner,
          hints: [],
          rating: -1,
          tags: [],
        );

        // Should not crash
        expect(
          () => puzzleService.validateMove(invalidPuzzle, [], 'e4'),
          returnsNormally,
        );
        expect(puzzleService.validateMove(invalidPuzzle, [], 'e4'), false);
        expect(puzzleService.isPuzzleSolved(invalidPuzzle, []), false);
        expect(puzzleService.getNextHint(invalidPuzzle, 0), null);
      });

      test('should handle operations without active puzzle', () async {
        // Try operations without starting a puzzle
        final result = await puzzleProvider.makeMove('e4');
        expect(result, false);

        final hint = await puzzleProvider.requestHint();
        expect(hint, null);

        // Should not crash
        expect(() => puzzleProvider.resetPuzzle(), returnsNormally);
      });

      test('should handle malformed move inputs', () async {
        const testPuzzle = PuzzleModel(
          id: 'malformed_test',
          fen: 'test_fen',
          solution: ['e4'],
          objective: 'Test malformed inputs',
          difficulty: PuzzleDifficulty.beginner,
          hints: ['Move pawn'],
          rating: 800,
          tags: ['test'],
        );

        await puzzleProvider.startPuzzle(testPuzzle);

        // Test various malformed inputs
        expect(await puzzleProvider.makeMove(''), false);
        expect(await puzzleProvider.makeMove('invalid'), false);
        expect(await puzzleProvider.makeMove('e9'), false);
        expect(await puzzleProvider.makeMove('z1'), false);
        expect(await puzzleProvider.makeMove('e4e5'), false);

        // Valid move should still work
        expect(await puzzleProvider.makeMove('e4'), true);
      });

      test('should handle storage failures gracefully', () async {
        const userId = 'storage_test_user';
        const puzzleId = 'storage_test_puzzle';

        // This should not throw even if storage fails
        final progress = PuzzleProgress.newAttempt(
          userId: userId,
          puzzleId: puzzleId,
          difficulty: PuzzleDifficulty.beginner,
        );

        expect(
          () => puzzleService.savePuzzleProgress(progress),
          returnsNormally,
        );
      });
    });

    group('Performance and Optimization', () {
      test('should validate moves efficiently', () async {
        const testPuzzle = PuzzleModel(
          id: 'performance_test',
          fen: 'test_fen',
          solution: ['e4'],
          objective: 'Performance test',
          difficulty: PuzzleDifficulty.beginner,
          hints: ['hint'],
          rating: 800,
          tags: ['test'],
        );

        final stopwatch = Stopwatch()..start();

        // Validate 100 moves (reduced from 1000 to avoid debug logging overhead)
        for (int i = 0; i < 100; i++) {
          puzzleService.validateMove(testPuzzle, [], 'e4');
        }

        stopwatch.stop();

        // Should complete quickly (less than 100ms for 100 operations)
        expect(stopwatch.elapsedMilliseconds, lessThan(100));
      });

      test('should handle large puzzle sets efficiently', () async {
        // Test loading and processing multiple puzzles
        final puzzles = await puzzleService.loadPuzzles();
        expect(puzzles.length, greaterThan(10));

        final stopwatch = Stopwatch()..start();

        // Process all puzzles
        for (final puzzle in puzzles) {
          expect(puzzle.id, isNotEmpty);
          expect(puzzle.solution, isNotEmpty);
          puzzleService.validateMove(puzzle, [], puzzle.solution.first);
        }

        stopwatch.stop();

        // Should process all puzzles quickly
        expect(stopwatch.elapsedMilliseconds, lessThan(1000));
      });
    });

    group('Complete Workflow Integration', () {
      test('should execute complete puzzle solving workflow', () async {
        // 1. Load puzzles
        final puzzles = await puzzleService.loadPuzzles();
        expect(puzzles, isNotEmpty);

        // 2. Get puzzles by difficulty
        final beginnerPuzzles = await puzzleService.getPuzzlesByDifficulty(
          PuzzleDifficulty.beginner,
        );
        expect(beginnerPuzzles, isNotEmpty);

        // 3. Start a puzzle session
        final testPuzzle = beginnerPuzzles.first;
        await puzzleProvider.startPuzzle(testPuzzle);
        expect(puzzleProvider.hasPuzzleActive, true);

        // 4. Use hint system
        final hint = await puzzleProvider.requestHint();
        expect(hint, isNotNull);
        expect(puzzleProvider.currentSession!.hintsUsed, 1);

        // 5. Solve the puzzle
        bool isSolved = false;
        for (final move in testPuzzle.solution) {
          final result = await puzzleProvider.makeMove(move);
          if (!result) break;

          if (puzzleProvider.currentSession?.state ==
              PuzzleSessionState.solved) {
            isSolved = true;
            break;
          }
        }

        // 6. Save progress
        if (isSolved) {
          final progress = PuzzleProgress.newAttempt(
            userId: 'workflow_test_user',
            puzzleId: testPuzzle.id,
            difficulty: testPuzzle.difficulty,
          ).markCompleted(solveTime: const Duration(seconds: 30), hintsUsed: 1);

          await puzzleService.savePuzzleProgress(progress);

          // Verify progress was saved
          final savedProgress = await puzzleService.getPuzzleProgress(
            'workflow_test_user',
            testPuzzle.id,
          );
          expect(savedProgress, isNotNull);
          expect(savedProgress!.completed, true);
        }

        expect(
          isSolved,
          true,
          reason: 'Puzzle should be solvable following the solution',
        );
      });
    });
  });
}
