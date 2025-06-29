import 'package:flutter/material.dart';
import 'package:squares/squares.dart';

class CapturedPiecesWidget extends StatelessWidget {
  final List<String> capturedPieces;
  final int materialAdvantage;
  final bool isWhite;
  final PieceSet pieceSet;

  const CapturedPiecesWidget({
    super.key,
    required this.capturedPieces,
    required this.materialAdvantage,
    required this.isWhite,
    required this.pieceSet,
  });

  @override
  Widget build(BuildContext context) {
    if (capturedPieces.isEmpty && materialAdvantage == 0) {
      return const SizedBox.shrink();
    }

    // Group pieces by type and count them
    Map<String, int> pieceCount = {};
    for (String piece in capturedPieces) {
      pieceCount[piece] = (pieceCount[piece] ?? 0) + 1;
    }

    return SizedBox(
      height: 32,
      child: Row(
        children: [
          // Captured pieces
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children:
                    pieceCount.entries.map((entry) {
                      final pieceName = entry.key;
                      final count = entry.value;

                      return Container(
                        margin: const EdgeInsets.only(right: 4),
                        child: Stack(
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: pieceSet.piece(context, pieceName),
                            ),
                            if (count > 1)
                              Positioned(
                                right: -2,
                                top: -2,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  child: Text(
                                    count.toString(),
                                    style: TextStyle(
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onPrimary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
              ),
            ),
          ),
          // Material advantage
          if (materialAdvantage > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '+$materialAdvantage',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
