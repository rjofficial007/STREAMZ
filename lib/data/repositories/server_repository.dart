// data/repositories/server_repository.dart

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/connection_record.dart';

class ServerRepository {
  static const _logsKey = 'access_logs';

  final SharedPreferences _prefs;
  final List<ConnectionRecord> _history = [];

  ServerRepository(this._prefs) {
    _loadHistory();
  }

  List<ConnectionRecord> get connectionHistory => List.unmodifiable(_history);

  // ── Load / Save ──────────────────────────────────────────────────────────

  void _loadHistory() {
    final logs = _prefs.getStringList(_logsKey) ?? [];
    for (final log in logs) {
      try {
        _history.add(ConnectionRecord.fromJson(jsonDecode(log) as Map<String, dynamic>));
      } catch (_) {}
    }
  }

  Future<void> _save() async {
    final logs = _history.map((c) => jsonEncode(c.toJson())).toList();
    await _prefs.setStringList(_logsKey, logs);
  }

  // ── Access Logging ────────────────────────────────────────────────────────

  Future<bool> logAccess(String ip) async {
    // Skip localhost
    if (ip == '127.0.0.1' || ip == '::1') return false;

    final now = DateTime.now();
    final idx = _history.indexWhere((c) => c.ip == ip);

    if (idx >= 0) {
      final old = _history[idx];
      // Debounce: skip if connected within last 60 seconds and still online
      if (now.difference(old.time).inSeconds < 60 && old.isOnline) {
        return false;
      }
      _history
        ..removeAt(idx)
        ..insert(0, old.copyWith(time: now, isOnline: true));
    } else {
      _history.insert(0, ConnectionRecord(ip: ip, network: 'WLAN NODE', time: now, transferGB: 0.0, isOnline: true));
    }

    await _save();
    return true;
  }

  Future<void> forgetConnection(String ip) async {
    _history.removeWhere((c) => c.ip == ip);
    await _save();
  }

  /// Call when server stops — marks all records as offline
  Future<void> markAllOffline() async {
    for (int i = 0; i < _history.length; i++) {
      _history[i] = _history[i].copyWith(isOnline: false);
    }
    await _save();
  }

  Future<void> updateTransferGB(String ip, double addGB) async {
    final idx = _history.indexWhere((c) => c.ip == ip);
    if (idx < 0) return;
    final old = _history[idx];
    _history[idx] = old.copyWith(transferGB: old.transferGB + addGB);
    await _save();
  }
}
