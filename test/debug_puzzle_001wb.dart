import 'package:bishop/bishop.dart' as bishop;

void main() {
  // FEN from puzzle 001wb
  final fen = 'r3k2r/pb1p1ppp/1b4q1/1Q2P3/8/2NP1Pn1/PP4PP/R1B2R1K w kq - 1 17';

  print('Testing FEN: $fen');

  try {
    final game = bishop.Game(variant: bishop.Variant.standard(), fen: fen);

    print('Game created successfully');
    print('Turn: ${game.state.turn}'); // 0 = white, 1 = black
    print('Move number: ${game.state.moveNumber}');

    // Try to make the first move from solution: h1g3
    final moveString = 'h1g3';
    print('Attempting to make move: $moveString');

    // First let's see what moves are available
    final moves = game.moves();
    print('Available moves (${moves.length}):');
    for (var move in moves) {
      print('  ${move.algebraic()} (${move.from} -> ${move.to})');
    }

    final success = game.makeMoveString(moveString);
    print('Move success: $success');

    if (success) {
      print('Move made successfully!');
      print('New FEN: ${game.fen}');
      print('New turn: ${game.state.turn}');
    } else {
      print('Move failed!');
      print(
        'This suggests there might be an issue with the move notation or the game state.',
      );
    }
  } catch (e) {
    print('Error creating game: $e');
  }
}
