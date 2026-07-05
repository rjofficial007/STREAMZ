import 'package:flutter/material.dart';

/// Lightweight broadcast bus so the root WidgetsBindingObserver can
/// forward AppLifecycleState to the ServerViewModel singleton without
/// requiring a BuildContext or widget tree traversal.
///
/// Also implements [ChangeNotifier] so UI components can watch it if needed.
class AppLifecycleBroadcaster extends ChangeNotifier {
  AppLifecycleState _state = AppLifecycleState.resumed;
  AppLifecycleState get state => _state;

  final List<void Function(AppLifecycleState)> _manualListeners = [];

  void addManualListener(void Function(AppLifecycleState) cb) => _manualListeners.add(cb);

  void removeManualListener(void Function(AppLifecycleState) cb) => _manualListeners.remove(cb);

  void notify(AppLifecycleState state) {
    _state = state;
    
    // Notify manual listeners (used by ServerViewModel)
    for (final cb in List.of(_manualListeners)) {
      cb(state);
    }
    
    // Notify Flutter listeners (if any)
    notifyListeners();
  }
}
