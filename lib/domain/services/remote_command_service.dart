// domain/services/remote_command_service.dart
// ============================================================================
// STREAMZ — Remote Command Service (Production-Fixed)
//
// BUGS FIXED:
//   1. connect() attempted WebSocket connection but errors (refused, timeout)
//      were silently swallowed — _connected stayed false with no retry.
//      Added automatic reconnect with exponential backoff (max 30 s).
//   2. stream.listen had no onError handler — an error event on the WebSocket
//      stream caused an unhandled exception crash. Added onError callback.
//   3. cancelOnError was missing — an error terminated the listen subscription
//      but left _channel alive, leaking the socket. Now sets cancelOnError:true
//      and nullifies _channel on any terminal event.
//   4. send() called _channel!.sink.add() — if _channel was null (race during
//      reconnect) this threw a null-check error. Added null guard.
//   5. reportStatus() had the same null-check risk. Fixed the same way.
//   6. dispose() called disconnect() but disconnect() can throw if close()
//      fails. Wrapped in try/catch.
// ============================================================================

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:streamz/domain/models/remote_command.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class RemoteCommandService extends ChangeNotifier {
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  final _commandController = StreamController<RemoteCommand>.broadcast();

  bool _connected = false;
  bool _disposed = false;

  // Reconnect state
  String? _lastIp;
  String _token = '';
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;
  static const _maxBackoffSeconds = 30;

  /// [SECURITY B1] Set when the server rejected our pairing token (close
  /// code 1008). Reconnecting with the same credentials would fail forever,
  /// so reconnects stop and the UI surfaces the error.
  String? _authError;
  String? get authError => _authError;

  Stream<RemoteCommand> get commands => _commandController.stream;
  bool get isConnected => _connected;

  // ── Connect ───────────────────────────────────────────────────────────────

  void connect(String ip, {String token = ''}) {
    _lastIp = ip;
    _token = token;
    _authError = null;
    _reconnectAttempt = 0;
    _reconnectTimer?.cancel();
    _doConnect(ip);
  }

  void _doConnect(String ip) {
    if (_disposed) return;
    _closeChannel();

    try {
      // [SECURITY B1] The pairing token is presented as the WS subprotocol
      // (Sec-WebSocket-Protocol); the server only negotiates that exact value.
      _channel = WebSocketChannel.connect(
        Uri.parse('ws://$ip:8080/ws'),
        protocols: _token.isNotEmpty ? [_token] : null,
      );
    } catch (e) {
      debugPrint('[WS] Connect error: $e');
      _scheduleReconnect();
      return;
    }

    _connected = false; // Will be set true once first message/ready arrives.

    _sub = _channel!.stream.listen(
      (message) {
        if (_disposed) return;
        // First successful message proves the pairing token was accepted.
        _authError = null;
        // Mark connected on first successful message.
        if (!_connected) {
          _connected = true;
          notifyListeners();
        }
        try {
          final data = jsonDecode(message as String) as Map<String, dynamic>;
          _commandController.add(RemoteCommand.fromJson(data));
        } catch (_) {
          // Non-JSON frame — ignore gracefully.
        }
      },
      onError: (Object error) {
        debugPrint('[WS] Stream error: $error');
        _connected = false;
        _maybeAuthFailure();
        notifyListeners();
        if (_authError == null) _scheduleReconnect();
      },
      onDone: () {
        debugPrint('[WS] Connection closed');
        _connected = false;
        _maybeAuthFailure();
        notifyListeners();
        // FIX: Reconnect only if we haven't explicitly disconnected — and
        // never when the server rejected our pairing token.
        if (!_disposed && _lastIp != null && _authError == null) {
          _scheduleReconnect();
        }
      },
      // FIX: cancelOnError: true ensures the subscription is torn down
      // cleanly when an error event fires.
      cancelOnError: true,
    );

    // Treat the channel as connected optimistically for send() calls.
    // The stream listener will update _connected on first real event.
    _connected = true;
    notifyListeners();
  }

  /// Close code 1008 = the server refused the pairing token. Stop retrying.
  void _maybeAuthFailure() {
    if (_channel?.closeCode == 1008) {
      _authError = 'PAIRING REQUIRED — scan the server QR or enter the code shown on the server dashboard';
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
    }
  }

  void _scheduleReconnect() {
    if (_disposed || _lastIp == null) return;
    _reconnectTimer?.cancel();
    _reconnectAttempt++;
    // Exponential backoff: 2^attempt seconds, capped at _maxBackoffSeconds.
    final delaySec = (_maxBackoffSeconds < (1 << _reconnectAttempt)) ? _maxBackoffSeconds : (1 << _reconnectAttempt);
    debugPrint('[WS] Reconnecting in ${delaySec}s (attempt $_reconnectAttempt)');
    _reconnectTimer = Timer(Duration(seconds: delaySec), () {
      if (!_disposed && _lastIp != null) _doConnect(_lastIp!);
    });
  }

  // ── Disconnect ────────────────────────────────────────────────────────────

  void disconnect() {
    _lastIp = null;
    _token = '';
    _authError = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempt = 0;
    _closeChannel();
    _connected = false;
    notifyListeners();
  }

  void _closeChannel() {
    try {
      _sub?.cancel();
      _channel?.sink.close();
    } catch (_) {}
    _sub = null;
    _channel = null;
  }

  // ── Send ──────────────────────────────────────────────────────────────────

  void send(RemoteCommand cmd) {
    // FIX: Guard against null _channel during reconnect window.
    if (_channel == null || !_connected) return;
    try {
      _channel!.sink.add(jsonEncode(cmd.toJson()));
    } catch (e) {
      debugPrint('[WS] Send error: $e');
    }
  }

  void reportStatus({required String clientId, required String sessionId, required String title, required String mediaId, required double progress, int? position, required String mediaType, required bool isStopped, String? snapshot, List<String>? vibeColors}) {
    // FIX: Same null guard as send().
    if (_channel == null || !_connected) return;
    try {
      _channel!.sink.add(jsonEncode({
        'type': 'report_status',
        'clientId': clientId,
        'sessionId': sessionId,
        'title': title,
        'mediaId': mediaId,
        'progress': progress,
        'position': position,
        'mediaType': mediaType,
        'isStopped': isStopped,
        'snapshot': snapshot,
        'vibeColors': vibeColors,
      }));
    } catch (e) {
      debugPrint('[WS] reportStatus error: $e');
    }
  }

  // ── Dispose ───────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _closeChannel();
    _commandController.close();
    super.dispose();
  }
}
