enum ClientConnectionPhase {
  idle,
  discovering,
  connecting,
  connected,
  degraded,
  reconnecting,
  failed,
}

ClientConnectionPhase resolveClientConnectionPhase({
  required bool isConnected,
  required bool isLoading,
  required bool isDiscovering,
  required bool hasConnectedBefore,
  required bool socketConnecting,
  required bool socketReconnecting,
  required bool hasError,
  required bool hasAuthenticationError,
}) {
  if (hasAuthenticationError) return ClientConnectionPhase.failed;
  if (isLoading) return ClientConnectionPhase.connecting;
  if (isConnected) {
    return hasError
        ? ClientConnectionPhase.degraded
        : ClientConnectionPhase.connected;
  }
  if (hasConnectedBefore || socketReconnecting) {
    return ClientConnectionPhase.reconnecting;
  }
  if (socketConnecting) return ClientConnectionPhase.connecting;
  if (isDiscovering) return ClientConnectionPhase.discovering;
  if (hasError) return ClientConnectionPhase.failed;
  return ClientConnectionPhase.idle;
}
