import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Real connectivity monitoring, backed by connectivity_plus. Exposes a
/// singleton so any widget can check the current state synchronously
/// (`isOnline`) or listen for changes (`onStatusChange`) without each
/// screen wiring its own platform channel listener.
///
/// This complements, not replaces, the try/catch in PlayerProvider /
/// ScoutProvider — those still handle failed calls. This service exists so
/// the app can proactively show an offline banner instead of only reacting
/// after a request already failed.
class ConnectivityService {
  ConnectivityService._internal();
  static final ConnectivityService instance = ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _statusController = StreamController<bool>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  /// Emits true/false whenever connectivity changes. Call [init] once at
  /// app startup (see main.dart) before relying on this stream.
  Stream<bool> get onStatusChange => _statusController.stream;

  Future<void> init() async {
    final initial = await _connectivity.checkConnectivity();
    _updateStatus(initial);

    _subscription = _connectivity.onConnectivityChanged.listen(_updateStatus);
  }

  void _updateStatus(List<ConnectivityResult> results) {
    final online = results.any((r) => r != ConnectivityResult.none);
    if (online != _isOnline) {
      _isOnline = online;
      _statusController.add(online);
    }
  }

  void dispose() {
    _subscription?.cancel();
    _statusController.close();
  }
}
