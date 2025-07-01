import 'package:flutter/material.dart';
import 'package:flutter_chess_app/models/user_model.dart';

class UserProvider with ChangeNotifier {
  ChessUser? _user;

  ChessUser? get user => _user;

  void setUser(ChessUser? newUser) {
    _user = newUser;
    notifyListeners();
  }
}
