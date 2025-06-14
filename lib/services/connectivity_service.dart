import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final _connectivity = Connectivity();
  final _controller = StreamController<bool>.broadcast();
  bool _isConnected = true;

  Stream<bool> get connectionStream => _controller.stream;
  bool get isConnected => _isConnected;

  Future<void> initialize() async {
    // Check initial connection
    final result = await _connectivity.checkConnectivity();
    _isConnected = result != ConnectivityResult.none;
    _controller.add(_isConnected);

    // Listen for connection changes
    _connectivity.onConnectivityChanged.listen((ConnectivityResult result) {
      _isConnected = result != ConnectivityResult.none;
      _controller.add(_isConnected);
    });
  }

  void dispose() {
    _controller.close();
  }
}
