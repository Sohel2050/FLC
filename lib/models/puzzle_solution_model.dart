import 'package:json_annotation/json_annotation.dart';

part 'puzzle_solution_model.g.dart';

/// Model representing an engine-calculated puzzle solution stored in Firestore
@JsonSerializable()
class PuzzleSolution {
  /// Unique identifier for the puzzle (matches puzzle ID)
  final String puzzleId;

  /// Engine-calculated best move sequence
  final List<String> engineMoves;

  /// FEN position where the puzzle starts
  final String startingFen;

  /// Engine evaluation at the starting position
  final double? evaluation;

  /// Engine depth used for calculation
  final int calculationDepth;

  /// Timestamp when the solution was calculated
  final DateTime calculatedAt;

  /// Engine that calculated this solution (e.g., "Stockfish 16")
  final String engine;

  /// Whether this solution has been verified by the engine
  final bool verified;

  /// Number of moves in the engine solution
  final int moveCount;

  const PuzzleSolution({
    required this.puzzleId,
    required this.engineMoves,
    required this.startingFen,
    this.evaluation,
    required this.calculationDepth,
    required this.calculatedAt,
    required this.engine,
    this.verified = false,
    required this.moveCount,
  });

  /// Create PuzzleSolution from JSON
  factory PuzzleSolution.fromJson(Map<String, dynamic> json) =>
      _$PuzzleSolutionFromJson(json);

  /// Convert PuzzleSolution to JSON
  Map<String, dynamic> toJson() => _$PuzzleSolutionToJson(this);

  /// Create a copy of this solution with updated fields
  PuzzleSolution copyWith({
    String? puzzleId,
    List<String>? engineMoves,
    String? startingFen,
    double? evaluation,
    int? calculationDepth,
    DateTime? calculatedAt,
    String? engine,
    bool? verified,
    int? moveCount,
  }) {
    return PuzzleSolution(
      puzzleId: puzzleId ?? this.puzzleId,
      engineMoves: engineMoves ?? this.engineMoves,
      startingFen: startingFen ?? this.startingFen,
      evaluation: evaluation ?? this.evaluation,
      calculationDepth: calculationDepth ?? this.calculationDepth,
      calculatedAt: calculatedAt ?? this.calculatedAt,
      engine: engine ?? this.engine,
      verified: verified ?? this.verified,
      moveCount: moveCount ?? this.moveCount,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PuzzleSolution && other.puzzleId == puzzleId;
  }

  @override
  int get hashCode => puzzleId.hashCode;

  @override
  String toString() {
    return 'PuzzleSolution(puzzleId: $puzzleId, moveCount: $moveCount, engine: $engine)';
  }
}
