import 'dart:math';
import '../models/user_model.dart';

class UserService {
  ChessUser createGuestUser() {
    final random = Random();
    final guestId = random.nextInt(100000); // Generate a random 5-digit number
    final displayName = 'Guest$guestId';
    return ChessUser(displayName: displayName, isGuest: true);
  }
}
