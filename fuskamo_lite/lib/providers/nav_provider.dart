import 'package:flutter/foundation.dart';

class NavProvider extends ChangeNotifier {
  int _index = 0;
  int get index => _index;

  void setIndex(int i) {
    _index = i;
    notifyListeners();
  }
}
