import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_chess_app/models/puzzle_models.dart';

void main() {
  group('Puzzle Models Tests', () {
    test('PuzzleModel can be created and serialized', () {
      final puzzle = PuzzleModel(
        id: 'test_puzzle_1',
        fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        solution: ['e4', 'e5', 'Nf3'],
        objective: 'White to play and develop pieces',
        difficulty: PuzzleDifficulty.beginner,
        hints: ['Develop your pieces', 'Control the center'],
        rating: 900,
        tags: ['opening', 'development'],
      );

      expect(puzzle.id, 'test_puzzle_1');
      expect(puzzle.difficulty, PuzzleDifficulty.beginner);
      expect(puzzle.solution.length, 3);

      // Test JSON serialization
      final json = puzzle.toJson();
      expect(json['id'], 'test_puzzle_1');
      expect(json['difficulty'], 'beginner');

      // Test JSON deserialization
      final puzzleFromJson = PuzzleModel.fromJson(json);
      expect(puzzleFromJson.id, puzzle.id);
      expect(puzzleFromJson.difficulty, puzzle.difficulty);
    });

    test('PuzzleProgress can be created and managed', () {
      final progress = PuzzleProgress.newAttempt(
        userId: 'user123',
        puzzleId: 'puzzle123',
        difficulty: PuzzleDifficulty.easy,
      );

      expect(progress.userId, 'user123');
      expect(progress.puzzleId, 'puzzle123');
      expect(progress.completed, false);
      expect(progress.attempts, 1);
      expect(progress.hintsUsed, 0);

      // Test completion
      final completedProgress = progress.markCompleted(
        solveTime: const Duration(seconds: 30),
        hintsUsed: 1,
      );

      expect(completedProgress.completed, true);
      expect(completedProgress.solveTime, const Duration(seconds: 30));
      expect(completedProgress.hintsUsed, 1);
      expect(completedProgress.solvedWithoutHints, false);
    });

    test('PuzzleSession can be managed', () {
      final puzzle = PuzzleModel(
        id: 'test_puzzle_1',
        fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        solution: ['e4', 'e5'],
        objective: 'Test puzzle',
        difficulty: PuzzleDifficulty.beginner,
        hints: ['Hint 1', 'Hint 2'],
        rating: 900,
        tags: ['test'],
      );

      final session = PuzzleSession.start(puzzle: puzzle);

      expect(session.puzzle.id, 'test_puzzle_1');
      expect(session.state, PuzzleSessionState.active);
      expect(session.userMoves.isEmpty, true);
      expect(session.currentMoveIndex, 0);
      expect(session.nextExpectedMove, 'e4');

      // Test adding correct move
      final sessionWithMove = session.addCorrectMove('e4');
      expect(sessionWithMove.userMoves.length, 1);
      expect(sessionWithMove.currentMoveIndex, 1);
      expect(sessionWithMove.nextExpectedMove, 'e5');

      // Test using hint
      final sessionWithHint = session.useHint();
      expect(sessionWithHint.hintsUsed, 1);
      expect(sessionWithHint.hasMoreHints, true);
    });

    test('PuzzleDifficulty extension methods work', () {
      expect(PuzzleDifficulty.beginner.displayName, 'Beginner');
      expect(PuzzleDifficulty.expert.displayName, 'Expert');
      expect(PuzzleDifficulty.beginner.ratingRange, '800-1000');
      expect(PuzzleDifficulty.expert.ratingRange, '1600+');
    });

    test('PuzzleStatistics can be created and managed', () {
      final stats = PuzzleStatistics.initial(userId: 'user123');

      expect(stats.userId, 'user123');
      expect(stats.totalPuzzlesSolved, 0);
      expect(stats.perfectSolutions, 0);
      expect(stats.overallCompletionPercentage, 0.0);

      // Test difficulty stats
      final beginnerStats =
          stats.puzzlesByDifficulty[PuzzleDifficulty.beginner];
      expect(beginnerStats?.completed, 0);
      expect(beginnerStats?.total, 0);
    });
  });
}
