import 'dart:async';

import 'package:fxmpp/src/core/xmpp_connection_config.dart';
import 'package:fxmpp/src/core/xmpp_connection_state.dart';
import 'package:xml/xml.dart';

import 'sasl_plain.dart';
import 'xmpp_websocket.dart';

/// Exception thrown when XMPP stream negotiation fails.
class XmppStreamException implements Exception {
  final String message;
  final XmppConnectionState state;
  XmppStreamException(this.message, this.state);
  @override
  String toString() => 'XmppStreamException: $message';
}

/// Handles XMPP-over-WebSocket stream negotiation per RFC 7395.
///
/// Manages the sequence: open -> SASL auth -> re-open -> resource bind.
class XmppStreamHandler {
  final XmppWebSocket _webSocket;
  final XmppConnectionConfig _config;
  final void Function(XmppConnectionState) _onStateChange;

  XmppStreamHandler(this._webSocket, this._config, this._onStateChange);

  /// Run the full XMPP stream negotiation.
  ///
  /// Returns the full bound JID on success.
  /// Throws [XmppStreamException] on failure.
  Future<String> negotiate() async {
    _onStateChange(XmppConnectionState.connecting);

    // Step 1: Send opening frame
    _sendOpen();

    // Step 2: Wait for server <open> and <stream:features> with SASL mechanisms
    await _waitForSaslFeatures();

    // Step 3: Authenticate with SASL PLAIN
    await _authenticate();

    // Step 4: Re-open stream after SASL success
    _sendOpen();

    // Step 5: Wait for new <stream:features> with bind
    await _waitForBindFeatures();

    // Step 6: Bind resource
    final fullJid = await _bindResource();

    return fullJid;
  }

  void _sendOpen() {
    _webSocket.send(
      '<open xmlns="urn:ietf:params:xml:ns:xmpp-framing"'
      ' to="${_config.domain}"'
      ' version="1.0"/>',
    );
  }

  Future<void> _waitForSaslFeatures() async {
    var receivedOpen = false;
    var receivedFeatures = false;

    await for (final frame in _webSocket.incoming) {
      final element = _parseFrame(frame);
      if (element == null) continue;

      if (element.name.local == 'open') {
        receivedOpen = true;
        continue;
      }

      if (element.name.local == 'features') {
        receivedFeatures = true;
        // Verify PLAIN mechanism is available
        final mechanisms = element.findAllElements('mechanism');
        final hasPlain = mechanisms.any((m) => m.innerText == 'PLAIN');
        if (!hasPlain) {
          throw XmppStreamException(
            'Server does not support SASL PLAIN mechanism',
            XmppConnectionState.error,
          );
        }
        break;
      }

      if (element.name.local == 'error' || element.name.local == 'close') {
        throw XmppStreamException(
          'Server returned error during stream open: $frame',
          XmppConnectionState.error,
        );
      }

      // Accept features after open
      if (receivedOpen && !receivedFeatures) continue;
    }

    if (!receivedOpen || !receivedFeatures) {
      throw XmppStreamException(
        'Stream ended before receiving features',
        XmppConnectionState.error,
      );
    }
  }

  Future<void> _authenticate() async {
    final credentials = SaslPlain.encode(_config.username, _config.password);
    _webSocket.send(
      '<auth xmlns="urn:ietf:params:xml:ns:xmpp-sasl"'
      ' mechanism="PLAIN">$credentials</auth>',
    );

    await for (final frame in _webSocket.incoming) {
      final element = _parseFrame(frame);
      if (element == null) continue;

      if (element.name.local == 'success') {
        return;
      }

      if (element.name.local == 'failure') {
        throw XmppStreamException(
          'SASL authentication failed: $frame',
          XmppConnectionState.authenticationFailed,
        );
      }
    }

    throw XmppStreamException(
      'Stream ended during SASL authentication',
      XmppConnectionState.error,
    );
  }

  Future<void> _waitForBindFeatures() async {
    await for (final frame in _webSocket.incoming) {
      final element = _parseFrame(frame);
      if (element == null) continue;

      // Skip the new <open> from server
      if (element.name.local == 'open') continue;

      if (element.name.local == 'features') {
        return;
      }

      if (element.name.local == 'error' || element.name.local == 'close') {
        throw XmppStreamException(
          'Server returned error after SASL: $frame',
          XmppConnectionState.error,
        );
      }
    }

    throw XmppStreamException(
      'Stream ended before receiving bind features',
      XmppConnectionState.error,
    );
  }

  Future<String> _bindResource() async {
    final resource = _config.resource ?? 'fxmpp';
    _webSocket.send(
      '<iq type="set" id="bind_1" xmlns="jabber:client">'
      '<bind xmlns="urn:ietf:params:xml:ns:xmpp-bind">'
      '<resource>$resource</resource>'
      '</bind></iq>',
    );

    await for (final frame in _webSocket.incoming) {
      final element = _parseFrame(frame);
      if (element == null) continue;

      if (element.name.local == 'iq') {
        final type = element.getAttribute('type');
        if (type == 'result') {
          final jidElement = element.findAllElements('jid').firstOrNull;
          if (jidElement != null) {
            return jidElement.innerText;
          }
          throw XmppStreamException(
            'Bind result missing JID element',
            XmppConnectionState.error,
          );
        }
        if (type == 'error') {
          throw XmppStreamException(
            'Resource binding failed: $frame',
            XmppConnectionState.error,
          );
        }
      }
    }

    throw XmppStreamException(
      'Stream ended during resource binding',
      XmppConnectionState.error,
    );
  }

  /// Parse a WebSocket frame as an XML element.
  /// Returns the root element, or null if parsing fails.
  XmlElement? _parseFrame(String frame) {
    try {
      final doc = XmlDocument.parse(frame);
      return doc.rootElement;
    } catch (_) {
      // Some servers may send incomplete or prefixed XML; skip gracefully
      return null;
    }
  }
}
