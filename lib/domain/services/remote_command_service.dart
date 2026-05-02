// domain/services/remote_command_service.dart

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../domain/models/remote_command.dart';

class RemoteCommandService extends ChangeNotifier {
  WebSocketChannel? _channel;
  final _commandController = StreamController<RemoteCommand>.broadcast();
  bool _connected = false;

  Stream<RemoteCommand> get commands => _commandController.stream;
  bool get isConnected => _connected;

  void connect(String ip) {
    disconnect();
    try {
      _channel = WebSocketChannel.connect(Uri.parse('ws://$ip:8080/ws'));
      _connected = true;
      notifyListeners();

      _channel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message as String) as Map<String, dynamic>;
            _commandController.add(RemoteCommand.fromJson(data));
          } catch (_) {}
        },
        onDone: () {
          _connected = false;
          notifyListeners();
        },
        onError: (_) {
          _connected = false;
          notifyListeners();
        },
      );
    } catch (e) {
      _connected = false;
      debugPrint('WebSocket connect error: $e');
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
    _connected = false;
    notifyListeners();
  }

  void send(RemoteCommand cmd) {
    if (_channel == null) return;
    try {
      _channel!.sink.add(jsonEncode(cmd.toJson()));
    } catch (e) {
      debugPrint('WS send error: $e');
    }
  }

  void reportStatus({required String clientId, required String sessionId, required String title, required double progress, required String mediaType, required bool isStopped}) {
    if (_channel == null) return;
    try {
      _channel!.sink.add(jsonEncode({'type': 'report_status', 'clientId': clientId, 'sessionId': sessionId, 'title': title, 'progress': progress, 'mediaType': mediaType, 'isStopped': isStopped}));
    } catch (_) {}
  }

  @override
  void dispose() {
    disconnect();
    _commandController.close();
    super.dispose();
  }
}
