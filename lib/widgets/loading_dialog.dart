import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_chess_app/services/user_service.dart';
import 'package:flutter_chess_app/widgets/animated_dialog.dart';

class LoadingDialog {
  static bool _isShowing = false;
  static Function()? onCancel;
  static StreamSubscription? _onlineCountSubscription;

  /// Shows a loading dialog with a spinner, optional message, and optional widget
  static void show(
    BuildContext context, {
    String message = 'Loading...',
    bool barrierDismissible = false,
    double? maxWidth,
    Widget? topWidget,
    bool showOnlineCount = false,
  }) {
    if (_isShowing) return;
    _isShowing = true;

    AnimatedDialog.show(
      context: context,
      maxWidth: maxWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Show custom widget if provided
          if (topWidget != null) ...[topWidget, const SizedBox(height: 16)],
          // Show online players count if enabled
          if (showOnlineCount) ...[
            _OnlinePlayersWidget(),
            const SizedBox(height: 16),
          ],
          // Loading spinner and message
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),

          // Cancel button
          if (barrierDismissible)
            TextButton(
              onPressed: () {
                hide(context);
                onCancel?.call();
              },
              child: const Text('Cancel'),
            ),
        ],
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
    );
  }

  /// Updates the message of the currently showing dialog
  static void updateMessage(
    BuildContext context,
    String message, {
    Widget? topWidget,
    bool showOnlineCount = false,
  }) {
    if (!_isShowing) return;
    hide(context);
    show(
      context,
      message: message,
      topWidget: topWidget,
      showOnlineCount: showOnlineCount,
    );
  }

  /// Hides the currently showing loading dialog
  static void hide(BuildContext context) {
    if (!_isShowing) return;
    _isShowing = false;
    _onlineCountSubscription?.cancel();
    _onlineCountSubscription = null;
    Navigator.of(context, rootNavigator: true).pop();
  }

  /// Shows a loading dialog that automatically dismisses after specified duration
  static Future<void> showWithTimeout(
    BuildContext context, {
    String message = 'Loading...',
    Duration timeout = const Duration(seconds: 10),
    Widget? topWidget,
    bool showOnlineCount = false,
  }) async {
    show(
      context,
      message: message,
      topWidget: topWidget,
      showOnlineCount: showOnlineCount,
    );
    await Future.delayed(timeout);
    if (_isShowing && context.mounted) {
      hide(context);
    }
  }
}

class _OnlinePlayersWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final userService = UserService();

    return StreamBuilder<int>(
      stream: userService.getOnlinePlayersCountStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('Error loading online count');
        }

        final count = snapshot.data ?? 0;
        return Column(
          children: [
            Icon(
              Icons.people,
              size: 32,
              color: count > 0 ? Colors.green : Colors.grey,
            ),
            const SizedBox(height: 8),
            Text(
              '$count players online',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        );
      },
    );
  }
}
