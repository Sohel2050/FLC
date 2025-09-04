// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'puzzle_solution_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PuzzleSolution _$PuzzleSolutionFromJson(Map<String, dynamic> json) =>
    PuzzleSolution(
      puzzleId: json['puzzleId'] as String,
      engineMoves: (json['engineMoves'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      startingFen: json['startingFen'] as String,
      evaluation: (json['evaluation'] as num?)?.toDouble(),
      calculationDepth: (json['calculationDepth'] as num).toInt(),
      calculatedAt: DateTime.parse(json['calculatedAt'] as String),
      engine: json['engine'] as String,
      verified: json['verified'] as bool? ?? false,
      moveCount: (json['moveCount'] as num).toInt(),
    );

Map<String, dynamic> _$PuzzleSolutionToJson(PuzzleSolution instance) =>
    <String, dynamic>{
      'puzzleId': instance.puzzleId,
      'engineMoves': instance.engineMoves,
      'startingFen': instance.startingFen,
      'evaluation': instance.evaluation,
      'calculationDepth': instance.calculationDepth,
      'calculatedAt': instance.calculatedAt.toIso8601String(),
      'engine': instance.engine,
      'verified': instance.verified,
      'moveCount': instance.moveCount,
    };
