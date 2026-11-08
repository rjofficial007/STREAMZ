import 'package:flutter_test/flutter_test.dart';
import 'package:streamz/domain/models/client_connection_phase.dart';

void main() {
  test('reports reconnecting while a previously ready socket retries', () {
    expect(
      resolveClientConnectionPhase(
        isConnected: false,
        isLoading: false,
        isDiscovering: true,
        hasConnectedBefore: true,
        socketConnecting: false,
        socketReconnecting: true,
        hasError: true,
        hasAuthenticationError: false,
      ),
      ClientConnectionPhase.reconnecting,
    );
  });

  test('reports degraded when HTTP refresh fails but the socket is ready', () {
    expect(
      resolveClientConnectionPhase(
        isConnected: true,
        isLoading: false,
        isDiscovering: false,
        hasConnectedBefore: true,
        socketConnecting: false,
        socketReconnecting: false,
        hasError: true,
        hasAuthenticationError: false,
      ),
      ClientConnectionPhase.degraded,
    );
  });

  test('authentication failure takes precedence over socket state', () {
    expect(
      resolveClientConnectionPhase(
        isConnected: false,
        isLoading: false,
        isDiscovering: false,
        hasConnectedBefore: false,
        socketConnecting: false,
        socketReconnecting: false,
        hasError: true,
        hasAuthenticationError: true,
      ),
      ClientConnectionPhase.failed,
    );
  });
}
