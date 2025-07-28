import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_chess_app/models/user_model.dart';

class UserProvider with ChangeNotifier {
  ChessUser? _user;

  ChessUser? get user => _user;

  void setUser(ChessUser? newUser) {
    log('User provider setUser called with photoUrl: ${newUser?.photoUrl}');
    _user = newUser;
    notifyListeners();
  }

  void updateUserPhoto(String? photoUrl) {
    if (_user != null) {
      _user = _user!.copyWith(photoUrl: photoUrl);
      notifyListeners();
    }
  }

  void updateUserRating(String ratingTypeField, int newRating) {
    if (_user != null) {
      _user = _user!.copyWith(
        classicalRating:
            ratingTypeField == 'classicalRating'
                ? newRating
                : _user!.classicalRating,
        blitzRating:
            ratingTypeField == 'blitzRating' ? newRating : _user!.blitzRating,
        tempoRating:
            ratingTypeField == 'tempoRating' ? newRating : _user!.tempoRating,
      );
      notifyListeners();
    }
  }
}
