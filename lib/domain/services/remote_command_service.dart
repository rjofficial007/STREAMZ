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
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:streamz/domain/models/remote_command.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class RemoteCommandService extends ChangeNotifier {
  RemoteCommandService({String? clientId}) : _clientId = clientId;

  final String? _clientId;
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  final _commandController = StreamController<RemoteCommand>.broadcast();

  bool _connected = false;
  bool _disposed = false;

  // Reconnect state
  String? _lastIp;
  String _token = '';
  Timer? _reconnectTimer;
  Timer? _readyTimer;
  Timer? _heartbeatTimer;
  int _reconnectAttempt = 0;
  static const _maxBackoffSeconds = 30;
  static const _heartbeatInterval = Duration(seconds: 15);
  static const _heartbeatTimeout = Duration(seconds: 45);
  final Random _random = Random();
  DateTime? _lastHeartbeatResponse;
  int _heartbeatSequence = 0;
  bool _rediscoveryRequested = false;
  Stopwatch? _attemptStopwatch;
  Stopwatch? _reconnectStopwatch;

  void Function()? onRediscoveryRequested;

  /// [SECURITY B1] Set when the server rejected our pairing token (close
  /// code 1008). Reconnecting with the same credentials would fail forever,
  /// so reconnects stop and the UI surfaces the error.
  String? _authError;
  String? get authError => _authError;

  Stream<RemoteCommand> get commands => _commandController.stream;
  bool get isConnected => _connected;
  bool get isConnecting =>
      !_connected &&
      _reconnectAttempt == 0 &&
      _channel != null &&
      _readyTimer?.isActive == true;
  bool get isReconnecting =>
      !_connected &&
      _lastIp != null &&
      _reconnectAttempt > 0 &&
      _authError == null;

  // ── Connect ───────────────────────────────────────────────────────────────

  void connect(String ip, {String token = ''}) {
    _lastIp = ip;
    _token = token;
    _authError = null;
    _reconnectAttempt = 0;
    _rediscoveryRequested = false;
    _reconnectStopwatch?.stop();
    _reconnectStopwatch = null;
    _reconnectTimer?.cancel();
    _doConnect(ip);
  }

  void reconnectAfterNetworkChange() {
    final ip = _lastIp;
    if (_disposed || ip == null || _authError != null) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectStopwatch ??= Stopwatch()..start();
    _doConnect(ip);
  }

  void _doConnect(String ip) {
    if (_disposed) return;
    _attemptStopwatch?.stop();
    _attemptStopwatch = Stopwatch()..start();
    final wasConnected = _connected;
    _connected = false;
    if (wasConnected) notifyListeners();
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
      _reconnectStopwatch ??= Stopwatch()..start();
      _scheduleReconnect();
      return;
    }

    _connected = false; // Will be set true once first message/ready arrives.
    final connectingChannel = _channel!;
    _readyTimer = Timer(const Duration(seconds: 10), () {
      if (!_connected && identical(_channel, connectingChannel)) {
        _reconnectStopwatch ??= Stopwatch()..start();
        _closeChannel();
        _scheduleReconnect();
      }
    });

    _sub = connectingChannel.stream.listen(
      (message) {
        if (_disposed || !identical(_channel, connectingChannel)) return;
        try {
          final data = jsonDecode(message as String) as Map<String, dynamic>;
          final command = RemoteCommand.fromJson(data);
          if (command.type == 'system' && command.action == 'heartbeat_ack') {
            _lastHeartbeatResponse = DateTime.now();
            return;
          }
          if (command.type == 'system' && command.action == 'ready') {
            final wasConnected = _connected;
            final handshakeMs = _attemptStopwatch?.elapsedMilliseconds ?? 0;
            final reconnectMs = _reconnectStopwatch?.elapsedMilliseconds;
            _authError = null;
            _readyTimer?.cancel();
            _readyTimer = null;
            _lastHeartbeatResponse = DateTime.now();
            _reconnectAttempt = 0;
            _rediscoveryRequested = false;
            _connected = true;
            debugPrint(
              '[WS] Ready handshake_ms=$handshakeMs'
              '${reconnectMs == null ? '' : ' reconnect_ms=$reconnectMs'}',
            );
            _attemptStopwatch?.stop();
            _attemptStopwatch = null;
            _reconnectStopwatch?.stop();
            _reconnectStopwatch = null;
            if (!wasConnected) notifyListeners();
            _startHeartbeat();
          }
          _commandController.add(command);
        } catch (_) {
          // Ignore malformed frames without treating them as a ready handshake.
        }
      },
      onError: (Object error) {
        if (!identical(_channel, connectingChannel)) return;
        debugPrint('[WS] Stream error: $error');
        _reconnectStopwatch ??= Stopwatch()..start();
        _connected = false;
        _stopConnectionTimers();
        _maybeAuthFailure();
        notifyListeners();
        if (_authError == null) _scheduleReconnect();
      },
      onDone: () {
        if (!identical(_channel, connectingChannel)) return;
        debugPrint('[WS] Connection closed');
        _reconnectStopwatch ??= Stopwatch()..start();
        _connected = false;
        _stopConnectionTimers();
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
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _sendHeartbeat();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      final channel = _channel;
      if (!_connected || channel == null) return;
      final lastResponse = _lastHeartbeatResponse;
      if (lastResponse != null &&
          DateTime.now().difference(lastResponse) > _heartbeatTimeout) {
        _reconnectStopwatch ??= Stopwatch()..start();
        _connected = false;
        notifyListeners();
        _closeChannel();
        _scheduleReconnect();
        return;
      }

      _sendHeartbeat(channel);
    });
  }

  void _sendHeartbeat([WebSocketChannel? channel]) {
    final activeChannel = channel ?? _channel;
    if (!_connected || activeChannel == null) return;
    try {
      activeChannel.sink.add(
        jsonEncode(
          RemoteCommand('system', 'heartbeat', {
            'sequence': ++_heartbeatSequence,
            if (_clientId != null) 'clientId': _clientId,
          }).toJson(),
        ),
      );
    } catch (error) {
      debugPrint('[WS] Heartbeat send error: $error');
    }
  }

  void _stopConnectionTimers() {
    _readyTimer?.cancel();
    _readyTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _lastHeartbeatResponse = null;
  }

  /// Close code 1008 = the server refused the pairing token. Stop retrying.
  void _maybeAuthFailure() {
    if (_channel?.closeCode == 1008) {
      _authError =
          'PAIRING REQUIRED — scan the server QR or enter the code shown on the server dashboard';
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
    }
  }

  void _scheduleReconnect() {
    if (_disposed || _lastIp == null) return;
    if (_reconnectTimer?.isActive == true) return;
    _reconnectTimer?.cancel();
    _reconnectAttempt++;
    final exponent = min(_reconnectAttempt, 5);
    final baseMillis = min(_maxBackoffSeconds * 1000, 1000 * (1 << exponent));
    final minimumMillis = baseMillis ~/ 2;
    final delayMillis =
        minimumMillis + _random.nextInt(baseMillis - minimumMillis + 1);
    debugPrint(
      '[WS] Reconnecting in ${delayMillis}ms (attempt $_reconnectAttempt)',
    );
    if (_reconnectAttempt >= 3 && !_rediscoveryRequested) {
      _rediscoveryRequested = true;
      onRediscoveryRequested?.call();
    }
    _reconnectTimer = Timer(Duration(milliseconds: delayMillis), () {
      if (!_disposed && _lastIp != null) _doConnect(_lastIp!);
    });
  }

  // ── Disconnect ────────────────────────────────────────────────────────────

  void disconnect() {
    _lastIp = null;
    _token = '';
    _authError = null;
    _attemptStopwatch?.stop();
    _attemptStopwatch = null;
    _reconnectStopwatch?.stop();
    _reconnectStopwatch = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _stopConnectionTimers();
    _reconnectAttempt = 0;
    _closeChannel();
    _connected = false;
    notifyListeners();
  }

  void _closeChannel() {
    _stopConnectionTimers();
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

  void reportStatus({
    required String clientId,
    required String sessionId,
    required String title,
    required String mediaId,
    required double progress,
    int? position,
    required String mediaType,
    required bool isStopped,
    String? snapshot,
    List<String>? vibeColors,
  }) {
    // FIX: Same null guard as send().
    if (_channel == null || !_connected) return;
    try {
      _channel!.sink.add(
        jsonEncode({
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
        }),
      );
    } catch (e) {
      debugPrint('[WS] reportStatus error: $e');
    }
  }

  // ── Dispose ───────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _stopConnectionTimers();
    _closeChannel();
    _commandController.close();
    super.dispose();
  }
}
