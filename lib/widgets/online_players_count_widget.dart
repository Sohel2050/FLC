import 'package:flutter/material.dart';
import 'package:flutter_chess_app/services/user_service.dart';

class OnlinePlayersCountWidget extends StatelessWidget {
  const OnlinePlayersCountWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final userService = UserService();
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
            const Icon(Icons.people, color: Colors.white),
            const SizedBox(width: 8.0),
            StreamBuilder<int>(
              stream: userService.getOnlinePlayersCountStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox();
                }
                final onlineCount = snapshot.data ?? 0;
                return Text(
                  '$onlineCount',
                  style: const TextStyle(
                    color: Colors.white,
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
