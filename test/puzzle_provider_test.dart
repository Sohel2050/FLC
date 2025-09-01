import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_chess_app/providers/puzzle_provider.dart';
import 'package:flutter_chess_app/models/puzzle_model.dart';

void main() {
  group('PuzzleProvider Tests', () {
    late PuzzleProvider puzzleProvider;

    setUp(() {
      puzzleProvider = PuzzleProvider();
    });

    tearDown(() {
      puzzleProvider.dispose();
    });

    test('should initialize without errors', () async {
      expect(puzzleProvider.currentSession, isNull);
      expect(puzzleProvider.isLoading, isFalse);
      expect(puzzleProvider.hasPuzzleActive, isFalse);
    });

    test('should start a puzzle session', () async {
      // Create a test puzzle
      const testPuzzle = PuzzleModel(
        id: 'test_puzzle',
        fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        solution: ['e4', 'e5'],
        objective: 'Test puzzle',
        difficulty: PuzzleDifficulty.beginner,
        hints: ['Move the pawn', 'Play e4'],
        rating: 800,
        tags: ['test'],
      );

      await puzzleProvider.startPuzzle(testPuzzle);

      expect(puzzleProvider.currentSession, isNotNull);
      expect(puzzleProvider.currentSession!.puzzle.id, equals('test_puzzle'));
      expect(
        puzzleProvider.currentSession!.state,
        equals(PuzzleSessionState.active),
      );
      expect(puzzleProvider.hasPuzzleActive, isTrue);
    });

    test('should make moves and validate them', () async {
      // Create a test puzzle
      const testPuzzle = PuzzleModel(
        id: 'test_puzzle',
        fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        solution: ['e4', 'e5'],
        objective: 'Test puzzle',
        difficulty: PuzzleDifficulty.beginner,
        hints: ['Move the pawn', 'Play e4'],
        rating: 800,
        tags: ['test'],
      );

      await puzzleProvider.startPuzzle(testPuzzle);

      // Make correct first move
      final result1 = await puzzleProvider.makeMove('e4');
      expect(result1, isTrue);
      expect(puzzleProvider.currentSession!.userMoves.length, equals(1));
      expect(puzzleProvider.currentSession!.userMoves.first, equals('e4'));

      // Make correct second move
      final result2 = await puzzleProvider.makeMove('e5');
      expect(result2, isTrue);
      expect(puzzleProvider.currentSession!.userMoves.length, equals(2));
      expect(
        puzzleProvider.currentSession!.state,
        equals(PuzzleSessionState.solved),
      );
    });

    test('should handle incorrect moves', () async {
      // Create a test puzzle
      const testPuzzle = PuzzleModel(
        id: 'test_puzzle',
        fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        solution: ['e4', 'e5'],
        objective: 'Test puzzle',
        difficulty: PuzzleDifficulty.beginner,
        hints: ['Move the pawn', 'Play e4'],
        rating: 800,
        tags: ['test'],
      );

      await puzzleProvider.startPuzzle(testPuzzle);

      // Make incorrect move
      final result = await puzzleProvider.makeMove('d4');
      expect(result, isFalse);
      expect(puzzleProvider.currentSession!.userMoves.length, equals(0));
      expect(
        puzzleProvider.currentSession!.state,
        equals(PuzzleSessionState.active),
      );
    });

    test('should provide hints', () async {
      // Create a test puzzle
      const testPuzzle = PuzzleModel(
        id: 'test_puzzle',
        fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        solution: ['e4', 'e5'],
        objective: 'Test puzzle',
        difficulty: PuzzleDifficulty.beginner,
        hints: ['Move the pawn', 'Play e4'],
        rating: 800,
        tags: ['test'],
      );

      await puzzleProvider.startPuzzle(testPuzzle);

      // Request first hint
      final hint1 = await puzzleProvider.requestHint();
      expect(hint1, equals('Move the pawn'));
      expect(puzzleProvider.currentSession!.hintsUsed, equals(1));

      // Request second hint
      final hint2 = await puzzleProvider.requestHint();
      expect(hint2, equals('Play e4'));
      expect(puzzleProvider.currentSession!.hintsUsed, equals(2));

      // Request third hint (should return null)
      final hint3 = await puzzleProvider.requestHint();
      expect(hint3, isNull);
      expect(puzzleProvider.currentSession!.hintsUsed, equals(2));
    });

    test('should reset puzzle', () async {
      // Create a test puzzle
      const testPuzzle = PuzzleModel(
        id: 'test_puzzle',
        fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        solution: ['e4', 'e5'],
        objective: 'Test puzzle',
        difficulty: PuzzleDifficulty.beginner,
        hints: ['Move the pawn', 'Play e4'],
        rating: 800,
        tags: ['test'],
      );

      await puzzleProvider.startPuzzle(testPuzzle);

      // Make a move and use a hint
      await puzzleProvider.makeMove('e4');
      await puzzleProvider.requestHint();

      expect(puzzleProvider.currentSession!.userMoves.length, equals(1));
      expect(puzzleProvider.currentSession!.hintsUsed, equals(1));

      // Reset puzzle
      await puzzleProvider.resetPuzzle();

      expect(puzzleProvider.currentSession!.userMoves.length, equals(0));
      expect(puzzleProvider.currentSession!.hintsUsed, equals(0));
      expect(
        puzzleProvider.currentSession!.state,
        equals(PuzzleSessionState.active),
      );
    });

    test('should handle completion percentage calculation', () {
      // Test with empty data
      final percentage = puzzleProvider.getCompletionPercentage(
        PuzzleDifficulty.beginner,
      );
      expect(percentage, equals(0));
    });
  });
}
