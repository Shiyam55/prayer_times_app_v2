import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  Future<bool> hasInternet() async {
    final results = await _connectivity.checkConnectivity();

    return results.any(
      (result) => result != ConnectivityResult.none,
    );
  }

  Stream<bool> onStatusChange() {
    return _connectivity.onConnectivityChanged.map(
      (results) {
        return results.any(
          (result) => result != ConnectivityResult.none,
        );
      },
    );
  }
}