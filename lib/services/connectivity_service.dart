import 'package:connectivity_plus/connectivity_plus.dart';

/// Thin wrapper over connectivity_plus exposing a simple online/offline signal.
/// Note: this reflects whether a network interface exists, not guaranteed
/// internet reachability — good enough to gate the flight lookup.
class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final _connectivity = Connectivity();

  bool _isOnline(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  Future<bool> isOnline() async => _isOnline(await _connectivity.checkConnectivity());

  Stream<bool> get onlineStream => _connectivity.onConnectivityChanged.map(_isOnline);
}
