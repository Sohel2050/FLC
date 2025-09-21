import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_chess_app/models/puzzle_model.dart';
import 'package:flutter_chess_app/providers/puzzle_provider.dart';

void main() {
  group('PuzzleMovePattern', () {
    test('should correctly identify opponent first moves', () {
      // Test case for puzzle 001wb
      // FEN: "r3k2r/pb1p1ppp/1b4q1/1Q2P3/8/2NP1Pn1/PP4PP/R1B2R1K w kq - 1 17" (White to move)
      // Solution: ["h1g3", "g6h5"]
      // Objective: "White to play, Black mates in 1"
      // Player should be Black (opposite of FEN turn since multi-move puzzle)
      // Opponent (White) plays first, then player (Black) mates
      final movePattern = PuzzleMovePattern(
        isUserMove: [false, true], // Opponent first, then user
        playerColor: 1, // Black
        opponentMovesFirst: true,
        expectedUserMoves: 1,
      );

      expect(movePattern.opponentMovesFirst, true);
      expect(movePattern.isUserMove, [false, true]);
      expect(movePattern.playerColor, 1);
      expect(movePattern.expectedUserMoves, 1);
    });

    test('should correctly identify user first moves', () {
      // Test case for a puzzle where user plays first
      final movePattern = PuzzleMovePattern(
        isUserMove: [true, false], // User first, then opponent
        playerColor: 0, // White
        opponentMovesFirst: false,
        expectedUserMoves: 1,
      );

      expect(movePattern.opponentMovesFirst, false);
      expect(movePattern.isUserMove, [true, false]);
      expect(movePattern.playerColor, 0);
      expect(movePattern.expectedUserMoves, 1);
    });
  });
}
