import 'package:flutter/foundation.dart';
import '../models/scout_model.dart';
import '../repositories/scout_repository.dart';
import 'player_provider.dart'; // for LoadState

class ScoutProvider extends ChangeNotifier {
  final ScoutRepository _repo = ScoutRepository();

  List<Scout> _scouts = [];
  LoadState _state = LoadState.idle;

  List<Scout> get scouts => _scouts;
  LoadState get state => _state;

  Future<void> loadScouts() async {
    _state = LoadState.loading;
    notifyListeners();
    try {
      _scouts = await _repo.getVerifiedScouts();
      _state = LoadState.loaded;
    } catch (e) {
      _state = LoadState.error;
    }
    notifyListeners();
  }
}
