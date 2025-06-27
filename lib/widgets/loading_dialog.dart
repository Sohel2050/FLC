import 'package:flutter/material.dart';
import 'package:flutter_chess_app/widgets/animated_dialog.dart';

class LoadingDialog {
  static bool _isShowing = false;

  /// Shows a loading dialog with a spinner and optional message
  static void show(
    BuildContext context, {
    String message = 'Loading...',
    bool barrierDismissible = false,
    double? maxWidth,
  }) {
    if (_isShowing) return;
    _isShowing = true;

    AnimatedDialog.show(
      context: context,
      maxWidth: maxWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const LinearProgressIndicator(),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
    );
  }

  static void updateMessage(BuildContext context, String message) {
    hide(context);
    show(context, message: message);
  }

  /// Hides the currently showing loading dialog
  static void hide(BuildContext context) {
    if (!_isShowing) return;
    _isShowing = false;
    Navigator.of(context, rootNavigator: true).pop();
  }

  /// Shows a loading dialog that automatically dismisses after specified duration
  static Future<void> showWithTimeout(
    BuildContext context, {
    String message = 'Loading...',
    Duration timeout = const Duration(seconds: 10),
  }) async {
    show(context, message: message);
    await Future.delayed(timeout);
    if (_isShowing && context.mounted) {
      hide(context);
    }
  }
}
