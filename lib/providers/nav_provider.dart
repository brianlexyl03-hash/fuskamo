import 'package:flutter/foundation.dart';

class NavProvider extends ChangeNotifier {
  static const int tabCount = 5;
  int _index = 0;
  int get index => _index;

  void setIndex(int index) {
    if (index < 0 || index >= tabCount || index == _index) return;
    _index = index;
    notifyListeners();
  }
}
