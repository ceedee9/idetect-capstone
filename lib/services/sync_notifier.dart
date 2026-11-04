import 'package:flutter/material.dart';

/// Shows sync alerts on any screen. The key is attached to the root
/// MaterialApp, and both sync queues use it.
class SyncNotifier {
  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static void show(String message) {
    messengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 6)),
    );
  }
}
