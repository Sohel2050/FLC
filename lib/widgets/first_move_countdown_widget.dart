import 'dart:async';
import 'package:flutter/material.dart';

class FirstMoveCountdownWidget extends StatefulWidget {
  final bool isVisible;
  final VoidCallback? onTimeout;
  final int initialSeconds;

  const FirstMoveCountdownWidget({
    super.key,
    required this.isVisible,
    this.onTimeout,
    this.initialSeconds = 10,
  });

  @override
  State<FirstMoveCountdownWidget> createState() =>
      _FirstMoveCountdownWidgetState();
}

class _FirstMoveCountdownWidgetState extends State<FirstMoveCountdownWidget> {
  Timer? _timer;
  int _remainingSeconds = 10;

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

    if (widget.isVisible && !oldWidget.isVisible) {
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

    return Container(
      margin: const EdgeInsets.all(8.0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer, size: 16, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            'White must move in $_remainingSeconds seconds',
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
