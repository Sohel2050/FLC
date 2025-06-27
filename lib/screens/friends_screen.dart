import 'package:flutter/material.dart';
import 'package:flutter_chess_app/screens/sign_up_screen.dart';
import 'package:flutter_chess_app/widgets/play_mode_button.dart';
import '../models/user_model.dart';

class FriendsScreen extends StatelessWidget {
  final ChessUser user;

  const FriendsScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Account required',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'To play with friends, please create an account.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),

            MainAppButton(
              text: 'Create Account',
              onPressed: () {
                // Navigate to sign-up screen
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const SignUpScreen()),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
