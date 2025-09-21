import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_chess_app/models/puzzle_model.dart';

void main() {
  group('PuzzleModel', () {
    test('should create puzzle model with opponentPlaysFirst field', () {
      final puzzle = PuzzleModel(
        id: 'test1',
        fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        solution: ['e2e4', 'e7e5'],
        objective: 'Test puzzle',
        difficulty: PuzzleDifficulty.beginner,
        hints: ['First move', 'Second move'],
        rating: 1000,
        tags: ['test', 'beginner'],
        opponentPlaysFirst: true,
      );

      expect(puzzle.id, 'test1');
      expect(puzzle.opponentPlaysFirst, true);
    });

    test('should default opponentPlaysFirst to false', () {
      final puzzle = PuzzleModel(
        id: 'test2',
        fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        solution: ['e2e4', 'e7e5'],
        objective: 'Test puzzle',
        difficulty: PuzzleDifficulty.beginner,
        hints: ['First move', 'Second move'],
        rating: 1000,
        tags: ['test', 'beginner'],
      );

      expect(puzzle.opponentPlaysFirst, false);
    });

    test('should copy with opponentPlaysFirst field', () {
      final puzzle = PuzzleModel(
        id: 'test3',
        fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        solution: ['e2e4', 'e7e5'],
        objective: 'Test puzzle',
        difficulty: PuzzleDifficulty.beginner,
        hints: ['First move', 'Second move'],
        rating: 1000,
        tags: ['test', 'beginner'],
        opponentPlaysFirst: false,
      );

      final copiedPuzzle = puzzle.copyWith(opponentPlaysFirst: true);

      expect(copiedPuzzle.opponentPlaysFirst, true);
      expect(puzzle.opponentPlaysFirst, false); // Original unchanged
    });
  });
}
