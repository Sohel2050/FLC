import 'package:flutter/material.dart';
import 'package:flutter_chess_app/services/user_service.dart';

class OnlinePlayersCountWidget extends StatefulWidget {
  const OnlinePlayersCountWidget({super.key});

  @override
  State<OnlinePlayersCountWidget> createState() =>
      _OnlinePlayersCountWidgetState();
}

class _OnlinePlayersCountWidgetState extends State<OnlinePlayersCountWidget> {
  final UserService _userService = UserService();
  Stream<int>? _onlineCountStream;

  @override
  void initState() {
    super.initState();
    // Initialize stream immediately
    _onlineCountStream = _userService.getOnlinePlayersCountStream();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(10.0),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.people,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              size: 20,
            ),
            const SizedBox(width: 8.0),
            StreamBuilder<int>(
              stream: _onlineCountStream,
              builder: (context, snapshot) {
                // Show loading indicator while waiting for data
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  );
                }

                // Handle errors by showing 0 but log the error
                if (snapshot.hasError) {
                  debugPrint(
                    'Error in online players count stream: ${snapshot.error}',
                  );
                  return Text(
                    '0',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontSize: 16.0,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                }

                // Display the actual count
                final onlineCount = snapshot.data ?? 0;
                return Text(
                  '$onlineCount',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontSize: 16.0,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
