import 'dart:async';
import 'package:flutter/material.dart';
import 'package:squares/squares.dart';

class FirstMoveCountdownWidget extends StatefulWidget {
  final bool isVisible;
  final VoidCallback? onTimeout;
  final int initialSeconds;
  final int playerToMove;

  const FirstMoveCountdownWidget({
    super.key,
    required this.isVisible,
    this.onTimeout,
    this.initialSeconds = 30,
    required this.playerToMove,
  });

  @override
  State<FirstMoveCountdownWidget> createState() =>
      _FirstMoveCountdownWidgetState();
}

class _FirstMoveCountdownWidgetState extends State<FirstMoveCountdownWidget> {
  Timer? _timer;
  int _remainingSeconds = 30;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.initialSeconds;
    if (widget.isVisible) {
      _startCountdown();
    }
  }

  @override
  void didUpdateWidget(FirstMoveCountdownWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Reset countdown if player changes or visibility changes
    if (widget.isVisible &&
        (!oldWidget.isVisible ||
            widget.playerToMove != oldWidget.playerToMove)) {
      _remainingSeconds = widget.initialSeconds;
      _startCountdown();
    } else if (!widget.isVisible && oldWidget.isVisible) {
      _stopCountdown();
    }
  }

  void _startCountdown() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _remainingSeconds--;
        });

        if (_remainingSeconds <= 0) {
          _stopCountdown();
          widget.onTimeout?.call();
        }
      }
    });
  }

  void _stopCountdown() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _stopCountdown();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible || _remainingSeconds <= 0) {
      return const SizedBox.shrink();
    }

    final playerName = widget.playerToMove == Squares.white ? 'White' : 'Black';
    final color =
        widget.playerToMove == Squares.white ? Colors.orange : Colors.red;

    // Debug: Widget is showing countdown for the current player

    return Container(
      margin: const EdgeInsets.all(8.0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer, size: 16, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            '$playerName must move in $_remainingSeconds seconds',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
