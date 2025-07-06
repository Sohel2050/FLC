import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_chess_app/services/user_service.dart';
import 'package:flutter_chess_app/widgets/animated_dialog.dart';

class LoadingDialog {
  static bool _isShowing = false;
  static StreamSubscription? _onlineCountSubscription;
  static ValueNotifier<String> _messageNotifier = ValueNotifier<String>(
    'Loading...',
  );
  static ValueNotifier<Widget?> _topWidgetNotifier = ValueNotifier<Widget?>(
    null,
  );
  static ValueNotifier<bool> _showOnlineCountNotifier = ValueNotifier<bool>(
    false,
  );
  static ValueNotifier<bool> _showCancelButtonNotifier = ValueNotifier<bool>(
    false,
  );
  static VoidCallback? _onCancel;

  /// Shows a loading dialog with a spinner, optional message, and optional widget
  static void show(
    BuildContext context, {
    String message = 'Loading...',
    bool barrierDismissible = false,
    double? maxWidth,
    Widget? topWidget,
    bool showOnlineCount = false,
    bool showCancelButton = false,
    VoidCallback? onCancel,
  }) {
    if (_isShowing) return;
    _isShowing = true;

    // Initialize notifiers
    _messageNotifier.value = message;
    _topWidgetNotifier.value = topWidget;
    _showOnlineCountNotifier.value = showOnlineCount;
    _showCancelButtonNotifier.value = showCancelButton;
    _onCancel = onCancel;

    AnimatedDialog.show(
      context: context,
      maxWidth: maxWidth,
      barrierDismissible: barrierDismissible,
      child: ValueListenableBuilder<String>(
        valueListenable: _messageNotifier,
        builder: (context, message, child) {
          return ValueListenableBuilder<Widget?>(
            valueListenable: _topWidgetNotifier,
            builder: (context, topWidget, child) {
              return ValueListenableBuilder<bool>(
                valueListenable: _showOnlineCountNotifier,
                builder: (context, showOnlineCount, child) {
                  return ValueListenableBuilder<bool>(
                    valueListenable: _showCancelButtonNotifier,
                    builder: (context, showCancelButton, child) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Show custom widget if provided
                          if (topWidget != null) ...[
                            topWidget,
                            const SizedBox(height: 16),
                          ],
                          // Show online players count if enabled
                          if (showOnlineCount) ...[
                            _OnlinePlayersWidget(),
                            const SizedBox(height: 16),
                          ],
                          // Loading spinner and message
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Text(
                              message,
                              key: ValueKey(message),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          // Cancel button if enabled
                          if (showCancelButton) ...[
                            const SizedBox(height: 20),
                            TextButton(
                              onPressed: () {
                                _onCancel?.call();
                                hide(context);
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                              child: const Text('Cancel'),
                            ),
                          ],
                        ],
                      );
                    },
                  );
                },
              );
            },
          );
        },
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
    bool showCancelButton = false,
    VoidCallback? onCancel,
  }) {
    if (!_isShowing) return;

    // Update the notifiers to smoothly change the content
    _messageNotifier.value = message;
    _topWidgetNotifier.value = topWidget;
    _showOnlineCountNotifier.value = showOnlineCount;
    _showCancelButtonNotifier.value = showCancelButton;
    _onCancel = onCancel;
  }

  /// Hides the currently showing loading dialog
  static void hide(BuildContext context) {
    if (!_isShowing) return;
    _isShowing = false;
    _onlineCountSubscription?.cancel();
    _onlineCountSubscription = null;
    _onCancel = null;
    Navigator.of(context, rootNavigator: true).pop();
  }

  /// Shows a loading dialog that automatically dismisses after specified duration
  static Future<void> showWithTimeout(
    BuildContext context, {
    String message = 'Loading...',
    Duration timeout = const Duration(seconds: 10),
    Widget? topWidget,
    bool showOnlineCount = false,
    bool showCancelButton = false,
    VoidCallback? onCancel,
  }) async {
    show(
      context,
      message: message,
      topWidget: topWidget,
      showOnlineCount: showOnlineCount,
      showCancelButton: showCancelButton,
      onCancel: onCancel,
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
