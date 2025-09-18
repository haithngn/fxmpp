/// Represents the state of an XMPP connection
enum XmppConnectionState {
  /// Connection is disconnected
  disconnected,

  /// Connection is in progress
  connecting,

  /// Connection is established and authenticated
  connected,

  /// Connection is being disconnected
  disconnecting,

  /// Connection failed or encountered an error
  error,

  /// Authentication failed
  authenticationFailed,

  /// Connection was lost unexpectedly
  connectionLost,
}

extension XmppConnectionStateExtension on XmppConnectionState {
  /// Returns true if the connection is in a connected state
  bool get isConnected => this == XmppConnectionState.connected;

  /// Returns true if the connection is in progress
  bool get isConnecting => this == XmppConnectionState.connecting;

  /// Returns true if the connection is disconnected
  bool get isDisconnected => this == XmppConnectionState.disconnected;

  /// Returns true if there's an error state
  bool get hasError =>
      this == XmppConnectionState.error ||
      this == XmppConnectionState.authenticationFailed ||
      this == XmppConnectionState.connectionLost;

  /// Returns a human-readable description of the connection state
  String get description {
    switch (this) {
      case XmppConnectionState.disconnected:
        return 'Disconnected';
      case XmppConnectionState.connecting:
        return 'Connecting...';
      case XmppConnectionState.connected:
        return 'Connected';
      case XmppConnectionState.disconnecting:
        return 'Disconnecting...';
      case XmppConnectionState.error:
        return 'Connection Error';
      case XmppConnectionState.authenticationFailed:
        return 'Authentication Failed';
      case XmppConnectionState.connectionLost:
        return 'Connection Lost';
    }
  }
}
