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
                    capturedPieces.map((piece) {
                      String displayPiece =
                          isWhite ? piece.toUpperCase() : piece.toLowerCase();
                      return Container(
                        width: 24,
                        height: 24,
                        margin: const EdgeInsets.only(right: 2),
                        child: pieceSet.piece(context, displayPiece),
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
