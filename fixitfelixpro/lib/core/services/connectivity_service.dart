import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Service for monitoring network connectivity
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  final _connectivityController = StreamController<bool>.broadcast();

  bool _isConnected = true;
  bool _isInitialized = false;

  /// Stream of connectivity status changes
  Stream<bool> get connectivityStream => _connectivityController.stream;

  /// Current connectivity status
  bool get isConnected => _isConnected;

  /// Initialize the connectivity service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Check initial connectivity
      final results = await _connectivity.checkConnectivity();
      _isConnected = _hasConnection(results);

      // Listen for changes
      _connectivity.onConnectivityChanged.listen((results) {
        final wasConnected = _isConnected;
        _isConnected = _hasConnection(results);

        if (wasConnected != _isConnected) {
          _connectivityController.add(_isConnected);
          debugPrint(
            'Connectivity changed: ${_isConnected ? "Online" : "Offline"}',
          );
        }
      });

      _isInitialized = true;
      debugPrint(
        'ConnectivityService initialized: ${_isConnected ? "Online" : "Offline"}',
      );
    } catch (e) {
      debugPrint('ConnectivityService initialization error: $e');
      _isConnected = true; // Assume connected if check fails
    }
  }

  /// Check if any connection type is available
  bool _hasConnection(List<ConnectivityResult> results) {
    return results.any(
      (result) =>
          result == ConnectivityResult.wifi ||
          result == ConnectivityResult.mobile ||
          result == ConnectivityResult.ethernet,
    );
  }

  /// Check connectivity once
  Future<bool> checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _isConnected = _hasConnection(results);
      return _isConnected;
    } catch (e) {
      debugPrint('Error checking connectivity: $e');
      return true;
    }
  }

  /// Dispose the service
  void dispose() {
    _connectivityController.close();
  }
}
