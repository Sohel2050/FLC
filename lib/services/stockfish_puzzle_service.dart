import 'dart:async';
import 'package:logger/logger.dart';
import 'package:stockfish/stockfish.dart';
import '../models/puzzle_model.dart';
import '../models/puzzle_solution_model.dart';
import '../stockfish/uci_commands.dart';

/// Service for calculating puzzle solutions using Stockfish engine
class StockfishPuzzleService {
  final Logger _logger = Logger();
  Stockfish? _stockfish;
  bool _initialized = false;
  bool _calculating = false;

  static const int _calculationDepth = 20; // Deep analysis for puzzles
  static const int _calculationTimeMs = 5000; // 5 seconds max calculation time
  static const String _engineName = 'Stockfish 16';

  /// Initialize the Stockfish engine for puzzle calculation
  Future<void> initialize() async {
    if (_initialized || _calculating) {
      return;
    }

    try {
      _logger.i('Initializing Stockfish for puzzle calculation');
      _stockfish = Stockfish();

      // Wait for engine to be ready
      await _waitForEngineReady();

      _initialized = true;
      _logger.i('Stockfish puzzle service initialized successfully');
    } catch (e) {
      _logger.e('Failed to initialize Stockfish puzzle service: $e');
      _stockfish?.dispose();
      _stockfish = null;
      _initialized = false;
      rethrow;
    }
  }

  /// Calculate the best solution for a puzzle using the engine
  Future<PuzzleSolution> calculatePuzzleSolution(PuzzleModel puzzle) async {
    if (!_initialized || _stockfish == null) {
      throw StateError('Stockfish puzzle service not initialized');
    }

    if (_calculating) {
      throw StateError('Another calculation is already in progress');
    }

    _calculating = true;

    try {
      _logger.i('Calculating solution for puzzle: ${puzzle.id}');

      // Set up the position
      await _setPosition(puzzle.fen);

      // Calculate best moves with deep analysis
      final engineMoves = await _calculateBestMoves(puzzle.fen);

      // Get position evaluation
      final evaluation = await _getPositionEvaluation(puzzle.fen);

      final solution = PuzzleSolution(
        puzzleId: puzzle.id,
        engineMoves: engineMoves,
        startingFen: puzzle.fen,
        evaluation: evaluation,
        calculationDepth: _calculationDepth,
        calculatedAt: DateTime.now(),
        engine: _engineName,
        verified: true,
        moveCount: engineMoves.length,
      );

      _logger.i(
        'Successfully calculated solution for puzzle ${puzzle.id}: ${engineMoves.join(', ')}',
      );
      return solution;
    } catch (e) {
      _logger.e('Error calculating puzzle solution for ${puzzle.id}: $e');
      rethrow;
    } finally {
      _calculating = false;
    }
  }

  /// Set the chess position in the engine
  Future<void> _setPosition(String fen) async {
    if (_stockfish == null) return;

    final completer = Completer<void>();
    late StreamSubscription subscription;

    // Send position command
    _stockfish!.stdin = '${UCICommands.position} $fen';
    _stockfish!.stdin = UCICommands.isReady;

    subscription = _stockfish!.stdout.listen((line) {
      if (line.contains('readyok')) {
        subscription.cancel();
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
    });

    // Timeout after 5 seconds
    Timer(const Duration(seconds: 5), () {
      subscription.cancel();
      if (!completer.isCompleted) {
        completer.completeError('Timeout setting position');
      }
    });

    return completer.future;
  }

  /// Calculate the best moves for the current position
  Future<List<String>> _calculateBestMoves(String fen) async {
    if (_stockfish == null) return [];

    final moves = <String>[];
    final completer = Completer<List<String>>();
    late StreamSubscription subscription;

    // Start calculation with specific depth and time
    _stockfish!.stdin = '${UCICommands.goMoveTime} $_calculationTimeMs';

    subscription = _stockfish!.stdout.listen((line) {
      if (line.contains(UCICommands.bestMove)) {
        subscription.cancel();

        // Extract the best move
        final parts = line.split(' ');
        if (parts.length > 1 && parts[1].isNotEmpty) {
          final bestMove = parts[1];
          if (bestMove != '(none)') {
            moves.add(bestMove);

            // For puzzles, we typically want the first critical move
            // You can extend this to calculate multiple moves if needed
            _logger.i('Engine found best move: $bestMove');
          }
        }

        if (!completer.isCompleted) {
          completer.complete(moves);
        }
      }
    });

    // Timeout after calculation time + buffer
    Timer(Duration(milliseconds: _calculationTimeMs + 2000), () {
      subscription.cancel();
      if (!completer.isCompleted) {
        completer.completeError('Timeout calculating moves');
      }
    });

    return completer.future;
  }

  /// Get position evaluation from the engine
  Future<double?> _getPositionEvaluation(String fen) async {
    if (_stockfish == null) return null;

    try {
      final completer = Completer<double?>();
      late StreamSubscription subscription;

      // Request evaluation
      _stockfish!.stdin = 'eval';

      subscription = _stockfish!.stdout.listen((line) {
        if (line.contains('Final evaluation')) {
          subscription.cancel();

          // Try to extract numerical evaluation
          final match = RegExp(r'[-+]?\d*\.?\d+').firstMatch(line);
          if (match != null) {
            final evalStr = match.group(0);
            if (evalStr != null) {
              final evaluation = double.tryParse(evalStr);
              if (!completer.isCompleted) {
                completer.complete(evaluation);
              }
              return;
            }
          }

          if (!completer.isCompleted) {
            completer.complete(null);
          }
        }
      });

      // Timeout after 3 seconds
      Timer(const Duration(seconds: 3), () {
        subscription.cancel();
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      });

      return await completer.future;
    } catch (e) {
      _logger.w('Could not get position evaluation: $e');
      return null;
    }
  }

  /// Wait for the engine to be ready
  Future<void> _waitForEngineReady() async {
    if (_stockfish == null) return;

    int attempts = 0;
    const maxAttempts = 60; // 30 seconds max

    while (_stockfish!.state.value != StockfishState.ready &&
        attempts < maxAttempts) {
      await Future.delayed(const Duration(milliseconds: 500));
      attempts++;
    }

    if (attempts >= maxAttempts) {
      throw Exception('Stockfish initialization timeout');
    }
  }

  /// Check if the service is currently calculating a solution
  bool get isCalculating => _calculating;

  /// Check if the service is initialized
  bool get isInitialized => _initialized;

  /// Dispose of the engine and cleanup resources
  void dispose() {
    _logger.i('Disposing Stockfish puzzle service');
    _stockfish?.dispose();
    _stockfish = null;
    _initialized = false;
    _calculating = false;
  }
}
