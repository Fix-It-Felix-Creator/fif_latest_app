// Global utilities and custom exceptions for FixItFelix app

import 'package:flutter/cupertino.dart';

final GlobalKey<NavigatorState> globalNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'Global',
);
final GlobalKey<NavigatorState> homeNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'Home',
);
final GlobalKey<NavigatorState> settingsNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'Settings');

/// Custom exception class for handling app-specific errors
class CustomException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  CustomException({required this.message, this.code, this.originalError});

  @override
  String toString() {
    if (code != null) {
      return 'CustomException [$code]: $message';
    }
    return 'CustomException: $message';
  }
}
