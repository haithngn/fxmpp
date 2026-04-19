import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Thin wrapper around the browser WebSocket for XMPP-over-WebSocket (RFC 7395).
///
/// Each WebSocket frame is a complete XML element per the RFC 7395 spec.
class XmppWebSocket {
  web.WebSocket? _socket;
  final StreamController<String> _incomingController =
      StreamController<String>.broadcast();
  final Completer<void> _openCompleter = Completer<void>();

  bool _isClosed = false;

  /// Stream of incoming XML frames from the server.
  Stream<String> get incoming => _incomingController.stream;

  /// Whether the WebSocket is currently open.
  bool get isOpen =>
      _socket != null && _socket!.readyState == web.WebSocket.OPEN;

  /// Connect to the given WebSocket URL with the `xmpp` subprotocol.
  Future<void> connect(String wsUrl) async {
    _isClosed = false;

    _socket = web.WebSocket(wsUrl, 'xmpp'.toJS);

    _socket!.onopen = ((web.Event event) {
      if (!_openCompleter.isCompleted) {
        _openCompleter.complete();
      }
    }).toJS;

    _socket!.onmessage = ((web.MessageEvent event) {
      final data = (event.data as JSString).toDart;
      _incomingController.add(data);
    }).toJS;

    _socket!.onerror = ((web.Event event) {
      if (!_openCompleter.isCompleted) {
        _openCompleter.completeError(
          Exception('WebSocket connection failed'),
        );
      }
      if (!_isClosed) {
        _incomingController.addError(Exception('WebSocket error'));
      }
    }).toJS;

    _socket!.onclose = ((web.CloseEvent event) {
      _isClosed = true;
      if (!_openCompleter.isCompleted) {
        _openCompleter.completeError(
          Exception('WebSocket closed before open: ${event.code} ${event.reason}'),
        );
      }
      _incomingController.close();
    }).toJS;

    return _openCompleter.future;
  }

  /// Send an XML string over the WebSocket.
  void send(String xml) {
    if (!isOpen) {
      throw StateError('WebSocket is not open');
    }
    _socket!.send(xml.toJS);
  }

  /// Close the WebSocket connection.
  void close() {
    _isClosed = true;
    _socket?.close();
  }

  /// Dispose all resources.
  void dispose() {
    close();
    _incomingController.close();
  }
}
