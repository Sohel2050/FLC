import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chess_app/services/puzzle_service.dart';
import 'package:flutter_chess_app/models/puzzle_model.dart';

void main() {
  group('PuzzleService Integration Tests', () {
    late PuzzleService puzzleService;

    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    setUp(() {
      puzzleService = PuzzleService();
    });

    test('should load actual puzzles from assets', () async {
      try {
        final puzzles = await puzzleService.loadPuzzles();

        expect(puzzles.isNotEmpty, true);
        print('Loaded ${puzzles.length} puzzles from assets');

        // Test that we have puzzles for each difficulty
        final difficulties = PuzzleDifficulty.values;
        for (final difficulty in difficulties) {
          final puzzlesForDifficulty = puzzles
              .where((p) => p.difficulty == difficulty)
              .toList();
          expect(
            puzzlesForDifficulty.isNotEmpty,
            true,
            reason:
                'No puzzles found for difficulty: ${difficulty.displayName}',
          );
          print(
            '${difficulty.displayName}: ${puzzlesForDifficulty.length} puzzles',
          );
        }

        // Test first puzzle structure
        final firstPuzzle = puzzles.first;
        expect(firstPuzzle.id.isNotEmpty, true);
        expect(firstPuzzle.fen.isNotEmpty, true);
        expect(firstPuzzle.solution.isNotEmpty, true);
        expect(firstPuzzle.objective.isNotEmpty, true);
        expect(firstPuzzle.hints.isNotEmpty, true);
        expect(firstPuzzle.tags.isNotEmpty, true);
        expect(firstPuzzle.rating > 0, true);

        print('First puzzle: ${firstPuzzle.id} - ${firstPuzzle.objective}');
      } catch (e) {
        fail('Failed to load puzzles from assets: $e');
      }
    });

    test('should get puzzles by difficulty', () async {
      try {
        final beginnerPuzzles = await puzzleService.getPuzzlesByDifficulty(
          PuzzleDifficulty.beginner,
        );
        expect(beginnerPuzzles.isNotEmpty, true);

        // Verify all returned puzzles are beginner difficulty
        for (final puzzle in beginnerPuzzles) {
          expect(puzzle.difficulty, PuzzleDifficulty.beginner);
        }

        print('Found ${beginnerPuzzles.length} beginner puzzles');
      } catch (e) {
        fail('Failed to get puzzles by difficulty: $e');
      }
    });

    test('should get puzzle counts by difficulty', () async {
      try {
        final counts = await puzzleService.getPuzzleCountsByDifficulty();

        expect(counts.isNotEmpty, true);

        int totalPuzzles = 0;
        for (final difficulty in PuzzleDifficulty.values) {
          final count = counts[difficulty] ?? 0;
          expect(count >= 0, true);
          totalPuzzles += count;
          print('${difficulty.displayName}: $count puzzles');
        }

        expect(totalPuzzles > 0, true);
        print('Total puzzles: $totalPuzzles');
      } catch (e) {
        fail('Failed to get puzzle counts: $e');
      }
    });
  });
}
