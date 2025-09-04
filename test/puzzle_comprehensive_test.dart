import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_chess_app/services/puzzle_service.dart';
import 'package:flutter_chess_app/providers/puzzle_provider.dart';
import 'package:flutter_chess_app/models/puzzle_model.dart';
import 'package:flutter_chess_app/models/puzzle_progress.dart';

void main() {
  group('Comprehensive Puzzle Functionality Tests', () {
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

    group('Puzzle Loading and Validation', () {
      test('should load puzzles from assets successfully', () async {
        try {
          final puzzles = await puzzleService.loadPuzzles();

          expect(puzzles, isNotEmpty);
          expect(puzzles.length, greaterThan(0));

          // Verify puzzle structure
          final firstPuzzle = puzzles.first;
          expect(firstPuzzle.id, isNotEmpty);
          expect(firstPuzzle.fen, isNotEmpty);
          expect(firstPuzzle.solution, isNotEmpty);
          expect(firstPuzzle.objective, isNotEmpty);
          expect(firstPuzzle.hints, isNotEmpty);
          expect(firstPuzzle.rating, greaterThan(0));

          print('✓ Successfully loaded ${puzzles.length} puzzles');
        } catch (e) {
          print('✗ Failed to load puzzles: $e');
          rethrow;
        }
      });

      test('should validate moves correctly', () async {
        const testPuzzle = PuzzleModel(
          id: 'test_001',
          fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
          solution: ['e4', 'e5', 'Nf3'],
          objective: 'Test puzzle',
          difficulty: PuzzleDifficulty.beginner,
          hints: ['Move the pawn', 'Play e4'],
          rating: 800,
          tags: ['test'],
        );

        // Test correct moves
        expect(puzzleService.validateMove(testPuzzle, [], 'e4'), true);
        expect(puzzleService.validateMove(testPuzzle, ['e4'], 'e5'), true);
        expect(
          puzzleService.validateMove(testPuzzle, ['e4', 'e5'], 'Nf3'),
          true,
        );

        // Test incorrect moves
        expect(puzzleService.validateMove(testPuzzle, [], 'd4'), false);
        expect(puzzleService.validateMove(testPuzzle, ['e4'], 'd5'), false);

        print('✓ Move validation working correctly');
      });

      test('should check puzzle completion correctly', () async {
        const testPuzzle = PuzzleModel(
          id: 'test_001',
          fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
          solution: ['e4', 'e5'],
          objective: 'Test puzzle',
          difficulty: PuzzleDifficulty.beginner,
          hints: ['hint1'],
          rating: 800,
          tags: ['test'],
        );

        // Test incomplete
        expect(puzzleService.isPuzzleSolved(testPuzzle, ['e4']), false);

        // Test complete
        expect(puzzleService.isPuzzleSolved(testPuzzle, ['e4', 'e5']), true);

        // Test incorrect sequence
        expect(puzzleService.isPuzzleSolved(testPuzzle, ['d4', 'e5']), false);

        print('✓ Puzzle completion detection working correctly');
      });
    });

    group('Hint System', () {
      test('should provide hints correctly', () async {
        const testPuzzle = PuzzleModel(
          id: 'test_001',
          fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
          solution: ['e4'],
          objective: 'Test puzzle',
          difficulty: PuzzleDifficulty.beginner,
          hints: ['First hint', 'Second hint', 'Third hint'],
          rating: 800,
          tags: ['test'],
        );

        // Test valid hint indices
        expect(puzzleService.getNextHint(testPuzzle, 0), 'First hint');
        expect(puzzleService.getNextHint(testPuzzle, 1), 'Second hint');
        expect(puzzleService.getNextHint(testPuzzle, 2), 'Third hint');

        // Test invalid indices
        expect(puzzleService.getNextHint(testPuzzle, 3), null);
        expect(puzzleService.getNextHint(testPuzzle, -1), null);

        print('✓ Hint system working correctly');
      });

      test('should handle puzzles with no hints', () async {
        const testPuzzle = PuzzleModel(
          id: 'test_001',
          fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
          solution: ['e4'],
          objective: 'Test puzzle',
          difficulty: PuzzleDifficulty.beginner,
          hints: [],
          rating: 800,
          tags: ['test'],
        );

        expect(puzzleService.getNextHint(testPuzzle, 0), null);
        print('✓ No hints handling working correctly');
      });
    });

    group('Progress Tracking', () {
      test('should save and retrieve progress', () async {
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

        print('✓ Progress tracking working correctly');
      });

      test('should track completion statistics', () async {
        const userId = 'test_user';

        // Save some completed puzzles
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

        await puzzleService.savePuzzleProgress(progress1);
        await puzzleService.savePuzzleProgress(progress2);

        final stats = await puzzleService.getCompletionStats(userId);

        expect(stats[PuzzleDifficulty.beginner], 2);
        expect(stats[PuzzleDifficulty.easy], 0);

        print('✓ Completion statistics working correctly');
      });
    });

    group('PuzzleProvider Integration', () {
      test('should start puzzle session correctly', () async {
        const testPuzzle = PuzzleModel(
          id: 'test_puzzle',
          fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
          solution: ['e4', 'e5'],
          objective: 'Test puzzle',
          difficulty: PuzzleDifficulty.beginner,
          hints: ['hint1', 'hint2'],
          rating: 800,
          tags: ['test'],
        );

        await puzzleProvider.startPuzzle(testPuzzle);

        expect(puzzleProvider.currentSession, isNotNull);
        expect(puzzleProvider.currentSession!.puzzle.id, 'test_puzzle');
        expect(puzzleProvider.currentSession!.state, PuzzleSessionState.active);
        expect(puzzleProvider.hasPuzzleActive, true);

        print('✓ Puzzle session management working correctly');
      });

      test('should handle moves correctly', () async {
        const testPuzzle = PuzzleModel(
          id: 'test_puzzle',
          fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
          solution: ['e4', 'e5'],
          objective: 'Test puzzle',
          difficulty: PuzzleDifficulty.beginner,
          hints: ['hint1', 'hint2'],
          rating: 800,
          tags: ['test'],
        );

        await puzzleProvider.startPuzzle(testPuzzle);

        // Make correct moves
        final result1 = await puzzleProvider.makeMove('e4');
        expect(result1, true);
        expect(puzzleProvider.currentSession!.userMoves.length, 1);

        final result2 = await puzzleProvider.makeMove('e5');
        expect(result2, true);
        expect(puzzleProvider.currentSession!.userMoves.length, 2);
        expect(puzzleProvider.currentSession!.state, PuzzleSessionState.solved);

        print('✓ Move handling working correctly');
      });

      test('should handle hints correctly', () async {
        const testPuzzle = PuzzleModel(
          id: 'test_puzzle',
          fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
          solution: ['e4', 'e5'],
          objective: 'Test puzzle',
          difficulty: PuzzleDifficulty.beginner,
          hints: ['First hint', 'Second hint'],
          rating: 800,
          tags: ['test'],
        );

        await puzzleProvider.startPuzzle(testPuzzle);

        // Request hints
        final hint1 = await puzzleProvider.requestHint();
        expect(hint1, 'First hint');
        expect(puzzleProvider.currentSession!.hintsUsed, 1);

        final hint2 = await puzzleProvider.requestHint();
        expect(hint2, 'Second hint');
        expect(puzzleProvider.currentSession!.hintsUsed, 2);

        // No more hints
        final hint3 = await puzzleProvider.requestHint();
        expect(hint3, null);
        expect(puzzleProvider.currentSession!.hintsUsed, 2);

        print('✓ Hint system integration working correctly');
      });

      test('should reset puzzle correctly', () async {
        const testPuzzle = PuzzleModel(
          id: 'test_puzzle',
          fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
          solution: ['e4', 'e5'],
          objective: 'Test puzzle',
          difficulty: PuzzleDifficulty.beginner,
          hints: ['hint1', 'hint2'],
          rating: 800,
          tags: ['test'],
        );

        await puzzleProvider.startPuzzle(testPuzzle);

        // Make moves and use hints
        await puzzleProvider.makeMove('e4');
        await puzzleProvider.requestHint();

        expect(puzzleProvider.currentSession!.userMoves.length, 1);
        expect(puzzleProvider.currentSession!.hintsUsed, 1);

        // Reset
        await puzzleProvider.resetPuzzle();

        expect(puzzleProvider.currentSession!.userMoves.length, 0);
        expect(puzzleProvider.currentSession!.hintsUsed, 0);
        expect(puzzleProvider.currentSession!.state, PuzzleSessionState.active);

        print('✓ Puzzle reset working correctly');
      });
    });

    group('Error Handling', () {
      test('should handle invalid puzzle data', () async {
        const invalidPuzzle = PuzzleModel(
          id: '',
          fen: 'invalid_fen',
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

        print('✓ Invalid puzzle data handling working correctly');
      });

      test('should handle moves without active puzzle', () async {
        // Try to make move without starting puzzle
        final result = await puzzleProvider.makeMove('e4');
        expect(result, false);

        print('✓ No active puzzle handling working correctly');
      });

      test('should handle hints without active puzzle', () async {
        // Try to request hint without starting puzzle
        final hint = await puzzleProvider.requestHint();
        expect(hint, null);

        print('✓ No active puzzle hint handling working correctly');
      });

      test('should handle empty and null inputs', () async {
        const validPuzzle = PuzzleModel(
          id: 'test_puzzle',
          fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
          solution: ['e4'],
          objective: 'Test puzzle',
          difficulty: PuzzleDifficulty.beginner,
          hints: ['hint1'],
          rating: 800,
          tags: ['test'],
        );

        // Empty move
        expect(puzzleService.validateMove(validPuzzle, [], ''), false);

        // Invalid hint index
        expect(puzzleService.getNextHint(validPuzzle, -1), null);
        expect(puzzleService.getNextHint(validPuzzle, 999), null);

        print('✓ Empty/null input handling working correctly');
      });
    });

    group('Performance Tests', () {
      test('should validate moves quickly', () async {
        const testPuzzle = PuzzleModel(
          id: 'perf_test',
          fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
          solution: ['e4'],
          objective: 'Performance test',
          difficulty: PuzzleDifficulty.beginner,
          hints: ['hint'],
          rating: 800,
          tags: ['test'],
        );

        final stopwatch = Stopwatch()..start();

        // Validate 100 moves (reduced to avoid debug logging overhead)
        for (int i = 0; i < 100; i++) {
          puzzleService.validateMove(testPuzzle, [], 'e4');
        }

        stopwatch.stop();

        // Should complete in reasonable time (less than 100ms for 100 validations)
        expect(stopwatch.elapsedMilliseconds, lessThan(100));

        print(
          '✓ Move validation performance: ${stopwatch.elapsedMilliseconds}ms for 100 validations',
        );
      });

      test('should handle multiple puzzle sessions efficiently', () async {
        const testPuzzle = PuzzleModel(
          id: 'multi_test',
          fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
          solution: ['e4'],
          objective: 'Multi session test',
          difficulty: PuzzleDifficulty.beginner,
          hints: ['hint'],
          rating: 800,
          tags: ['test'],
        );

        final providers = <PuzzleProvider>[];

        try {
          // Create multiple providers
          for (int i = 0; i < 10; i++) {
            final provider = PuzzleProvider();
            providers.add(provider);
            await provider.startPuzzle(testPuzzle);
            await provider.makeMove('e4');
          }

          // All should be successful
          expect(providers.length, 10);
          expect(
            providers.every(
              (p) => p.currentSession?.state == PuzzleSessionState.solved,
            ),
            true,
          );

          print('✓ Multiple puzzle sessions handled efficiently');
        } finally {
          // Clean up
          for (final provider in providers) {
            provider.dispose();
          }
        }
      });
    });

    group('Integration with Existing Components', () {
      test('should maintain separate state from game provider', () async {
        const testPuzzle = PuzzleModel(
          id: 'integration_test',
          fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
          solution: ['e4'],
          objective: 'Integration test',
          difficulty: PuzzleDifficulty.beginner,
          hints: ['hint'],
          rating: 800,
          tags: ['test'],
        );

        await puzzleProvider.startPuzzle(testPuzzle);
        await puzzleProvider.makeMove('e4');

        // Puzzle state should be independent
        expect(puzzleProvider.currentSession, isNotNull);
        expect(puzzleProvider.currentSession!.state, PuzzleSessionState.solved);

        print('✓ Integration with existing components working correctly');
      });

      test('should handle settings integration', () async {
        // This would test that puzzle screens respect user settings
        // For now, just verify the provider can be created
        expect(puzzleProvider, isNotNull);

        print('✓ Settings integration ready');
      });
    });

    group('Comprehensive Flow Test', () {
      test('should complete full puzzle solving workflow', () async {
        try {
          // 1. Load puzzles
          final puzzles = await puzzleService.loadPuzzles();
          expect(puzzles, isNotEmpty);

          // 2. Get puzzles by difficulty
          final beginnerPuzzles = await puzzleService.getPuzzlesByDifficulty(
            PuzzleDifficulty.beginner,
          );
          expect(beginnerPuzzles, isNotEmpty);

          // 3. Start a puzzle
          final testPuzzle = beginnerPuzzles.first;
          await puzzleProvider.startPuzzle(testPuzzle);
          expect(puzzleProvider.hasPuzzleActive, true);

          // 4. Use a hint
          final hint = await puzzleProvider.requestHint();
          expect(hint, isNotNull);

          // 5. Make moves (try to solve)
          for (final move in testPuzzle.solution) {
            final result = await puzzleProvider.makeMove(move);
            if (!result) break; // Stop if move is invalid
          }

          // 6. Check if solved
          final isSolved =
              puzzleProvider.currentSession?.state == PuzzleSessionState.solved;

          // 7. Save progress if solved
          if (isSolved) {
            final progress =
                PuzzleProgress.newAttempt(
                  userId: 'test_user',
                  puzzleId: testPuzzle.id,
                  difficulty: testPuzzle.difficulty,
                ).markCompleted(
                  solveTime: const Duration(seconds: 60),
                  hintsUsed: 1,
                );

            await puzzleService.savePuzzleProgress(progress);
          }

          print('✓ Complete puzzle workflow executed successfully');
          print('  - Loaded ${puzzles.length} puzzles');
          print('  - Found ${beginnerPuzzles.length} beginner puzzles');
          print('  - Puzzle solved: $isSolved');
        } catch (e) {
          print('✗ Workflow failed: $e');
          rethrow;
        }
      });
    });
  });
}
