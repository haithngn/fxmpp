import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:fxmpp/src/core/xmpp_connection_config.dart';
import 'package:fxmpp/src/core/xmpp_connection_state.dart';
import 'package:xml/xml.dart';

import 'fxmpp_platform_interface.dart';
import 'web/xmpp_stream_handler.dart';
import 'web/xmpp_websocket.dart';

/// Web implementation of [FxmppPlatform] using XMPP-over-WebSocket (RFC 7395).
class FxmppWeb extends FxmppPlatform {
  XmppWebSocket? _webSocket;
  StreamSubscription<String>? _incomingSubscription;
  XmppConnectionState _connectionState = XmppConnectionState.disconnected;
  String? _fullJid;

  Function(XmppConnectionState)? _connectionStateCallback;
  Function(XmlDocument)? _messageCallback;
  Function(XmlDocument)? _presenceCallback;
  Function(XmlDocument)? _iqCallback;
  // MUC events arrive as regular presence/message stanzas on web.
  // ignore: unused_field
  Function(Map<String, dynamic>)? _mucEventCallback;

  /// Registers this class as the default instance of [FxmppPlatform].
  static void registerWith(Registrar registrar) {
    FxmppPlatform.instance = FxmppWeb();
  }

  void _updateState(XmppConnectionState state) {
    _connectionState = state;
    _connectionStateCallback?.call(state);
  }

  @override
  Future<void> initialize() async {
    // No-op on web — event routing is set up in connect().
  }

  @override
  Future<bool> connect(XmppConnectionConfig config) async {
    final wsUrl = config.wsUrl;
    if (wsUrl == null || wsUrl.isEmpty) {
      throw ArgumentError(
        'wsUrl is required for web platform. '
        'Provide it in XmppConnectionConfig (e.g. wss://example.com:5443/ws).',
      );
    }

    try {
      _updateState(XmppConnectionState.connecting);

      // Open WebSocket
      _webSocket = XmppWebSocket();
      await _webSocket!.connect(wsUrl);

      // Run XMPP stream negotiation (SASL auth + resource bind)
      final handler = XmppStreamHandler(_webSocket!, config, _updateState);
      _fullJid = await handler.negotiate();

      // Negotiation succeeded — set up stanza routing
      _setupStanzaRouting();
      _updateState(XmppConnectionState.connected);

      // Send initial presence so the server knows we're online.
      // Native libraries (Smack, XMPPFramework) do this automatically;
      // on web we must do it explicitly or the server won't route
      // incoming stanzas to this resource.
      _webSocket!.send('<presence xmlns="jabber:client"/>');

      return true;
    } on XmppStreamException catch (e) {
      _updateState(e.state);
      _webSocket?.dispose();
      _webSocket = null;
      return false;
    } catch (e) {
      _updateState(XmppConnectionState.error);
      _webSocket?.dispose();
      _webSocket = null;
      return false;
    }
  }

  void _setupStanzaRouting() {
    _incomingSubscription = _webSocket!.incoming.listen(
      (frame) {
        try {
          final doc = XmlDocument.parse(frame);
          final root = doc.rootElement;
          final name = root.name.local;

          switch (name) {
            case 'message':
              _messageCallback?.call(doc);
              break;
            case 'presence':
              _presenceCallback?.call(doc);
              break;
            case 'iq':
              _iqCallback?.call(doc);
              break;
            case 'close':
              _handleServerClose();
              break;
          }
        } catch (e) {
          debugPrint('Error parsing incoming XMPP frame: $e');
        }
      },
      onError: (error) {
        debugPrint('WebSocket stream error: $error');
        _updateState(XmppConnectionState.connectionLost);
      },
      onDone: () {
        if (_connectionState == XmppConnectionState.connected) {
          _updateState(XmppConnectionState.connectionLost);
        }
      },
    );
  }

  void _handleServerClose() {
    _updateState(XmppConnectionState.disconnected);
    _cleanup();
  }

  @override
  Future<void> disconnect() async {
    if (_webSocket != null && _webSocket!.isOpen) {
      _updateState(XmppConnectionState.disconnecting);
      try {
        _webSocket!.send(
          '<close xmlns="urn:ietf:params:xml:ns:xmpp-framing"/>',
        );
      } catch (_) {
        // Socket may already be closing
      }
    }
    _updateState(XmppConnectionState.disconnected);
    _cleanup();
  }

  void _cleanup() {
    _incomingSubscription?.cancel();
    _incomingSubscription = null;
    _webSocket?.dispose();
    _webSocket = null;
    _fullJid = null;
  }

  @override
  Future<bool> sendMessage(XmlDocument message) async {
    return _sendStanza(message);
  }

  @override
  Future<bool> sendPresence(XmlDocument presence) async {
    return _sendStanza(presence);
  }

  @override
  Future<bool> sendIq(XmlDocument iq) async {
    return _sendStanza(iq);
  }

  bool _sendStanza(XmlDocument stanza) {
    if (_webSocket == null || !_webSocket!.isOpen) return false;
    try {
      _webSocket!.send(stanza.toXmlString());
      return true;
    } catch (e) {
      debugPrint('Error sending stanza: $e');
      return false;
    }
  }

  @override
  Future<XmppConnectionState> getConnectionState() async {
    return _connectionState;
  }

  @override
  void setConnectionStateCallback(Function(XmppConnectionState) callback) {
    _connectionStateCallback = callback;
  }

  @override
  void setMessageCallback(Function(XmlDocument) callback) {
    _messageCallback = callback;
  }

  @override
  void setPresenceCallback(Function(XmlDocument) callback) {
    _presenceCallback = callback;
  }

  @override
  void setIqCallback(Function(XmlDocument) callback) {
    _iqCallback = callback;
  }

  @override
  void setMucEventCallback(Function(Map<String, dynamic>) callback) {
    _mucEventCallback = callback;
  }

  // ============================================================================
  // MUC (Multi-User Chat) METHODS
  //
  // On web, MUC operations are sent as raw XMPP stanzas over the WebSocket.
  // The server handles them identically to stanzas from any XMPP client.
  // ============================================================================

  @override
  Future<bool> joinMucRoom({
    required String roomJid,
    required String nickname,
    String? password,
    int? maxStanzas,
    DateTime? since,
  }) async {
    final historyAttrs = <String, String>{};
    if (maxStanzas != null) historyAttrs['maxstanzas'] = '$maxStanzas';
    if (since != null) historyAttrs['since'] = since.toUtc().toIso8601String();

    final historyElement = historyAttrs.isEmpty
        ? ''
        : '<history${historyAttrs.entries.map((e) => ' ${e.key}="${e.value}"').join()}/>';

    final passwordElement =
        password != null ? '<password>$password</password>' : '';

    final xml =
        '<presence to="$roomJid/$nickname" xmlns="jabber:client"'
        '${_fullJid != null ? ' from="$_fullJid"' : ''}>'
        '<x xmlns="http://jabber.org/protocol/muc">'
        '$passwordElement$historyElement'
        '</x></presence>';

    return _sendRawXml(xml);
  }

  @override
  Future<bool> leaveMucRoom({
    required String roomJid,
    String? reason,
  }) async {
    // To leave, we need the nickname we used. Extract from presence tracking
    // or use a generic unavailable presence to the room.
    final statusElement =
        reason != null ? '<status>$reason</status>' : '';

    final xml =
        '<presence to="$roomJid" type="unavailable" xmlns="jabber:client"'
        '${_fullJid != null ? ' from="$_fullJid"' : ''}>'
        '$statusElement</presence>';

    return _sendRawXml(xml);
  }

  @override
  Future<bool> sendMucMessage(XmlDocument message) async {
    return _sendStanza(message);
  }

  @override
  Future<bool> sendMucPrivateMessage(XmlDocument message) async {
    return _sendStanza(message);
  }

  @override
  Future<bool> changeMucSubject({
    required String roomJid,
    required String subject,
  }) async {
    final xml =
        '<message to="$roomJid" type="groupchat" xmlns="jabber:client"'
        '${_fullJid != null ? ' from="$_fullJid"' : ''}>'
        '<subject>$subject</subject></message>';

    return _sendRawXml(xml);
  }

  @override
  Future<bool> kickMucParticipant({
    required String roomJid,
    required String nickname,
    String? reason,
  }) async {
    return _sendMucAdminIq(
      roomJid: roomJid,
      itemAttributes: {'nick': nickname, 'role': 'none'},
      reason: reason,
    );
  }

  @override
  Future<bool> banMucUser({
    required String roomJid,
    required String userJid,
    String? reason,
  }) async {
    return _sendMucAdminIq(
      roomJid: roomJid,
      itemAttributes: {'jid': userJid, 'affiliation': 'outcast'},
      reason: reason,
    );
  }

  @override
  Future<bool> grantMucVoice({
    required String roomJid,
    required String nickname,
    String? reason,
  }) async {
    return _sendMucAdminIq(
      roomJid: roomJid,
      itemAttributes: {'nick': nickname, 'role': 'participant'},
      reason: reason,
    );
  }

  @override
  Future<bool> revokeMucVoice({
    required String roomJid,
    required String nickname,
    String? reason,
  }) async {
    return _sendMucAdminIq(
      roomJid: roomJid,
      itemAttributes: {'nick': nickname, 'role': 'visitor'},
      reason: reason,
    );
  }

  @override
  Future<bool> grantMucModerator({
    required String roomJid,
    required String nickname,
    String? reason,
  }) async {
    return _sendMucAdminIq(
      roomJid: roomJid,
      itemAttributes: {'nick': nickname, 'role': 'moderator'},
      reason: reason,
    );
  }

  @override
  Future<bool> grantMucMembership({
    required String roomJid,
    required String userJid,
    String? reason,
  }) async {
    return _sendMucAdminIq(
      roomJid: roomJid,
      itemAttributes: {'jid': userJid, 'affiliation': 'member'},
      reason: reason,
    );
  }

  @override
  Future<bool> grantMucAdmin({
    required String roomJid,
    required String userJid,
    String? reason,
  }) async {
    return _sendMucAdminIq(
      roomJid: roomJid,
      itemAttributes: {'jid': userJid, 'affiliation': 'admin'},
      reason: reason,
    );
  }

  @override
  Future<bool> inviteMucUser({
    required String roomJid,
    required String userJid,
    String? reason,
  }) async {
    final reasonElement =
        reason != null ? '<reason>$reason</reason>' : '';

    final xml =
        '<message to="$roomJid" xmlns="jabber:client"'
        '${_fullJid != null ? ' from="$_fullJid"' : ''}>'
        '<x xmlns="http://jabber.org/protocol/muc#user">'
        '<invite to="$userJid">$reasonElement</invite>'
        '</x></message>';

    return _sendRawXml(xml);
  }

  @override
  Future<bool> destroyMucRoom({
    required String roomJid,
    String? reason,
    String? alternativeRoom,
  }) async {
    final reasonElement =
        reason != null ? '<reason>$reason</reason>' : '';
    final altRoomAttr =
        alternativeRoom != null ? ' jid="$alternativeRoom"' : '';

    final xml =
        '<iq to="$roomJid" type="set" id="destroy_1" xmlns="jabber:client"'
        '${_fullJid != null ? ' from="$_fullJid"' : ''}>'
        '<query xmlns="http://jabber.org/protocol/muc#owner">'
        '<destroy$altRoomAttr>$reasonElement</destroy>'
        '</query></iq>';

    return _sendRawXml(xml);
  }

  @override
  Future<bool> createMucRoom({
    required String roomJid,
    required String nickname,
    String? password,
  }) async {
    // Creating a room in XMPP is the same as joining a non-existent room.
    return joinMucRoom(
      roomJid: roomJid,
      nickname: nickname,
      password: password,
    );
  }

  // ============================================================================
  // Private helpers
  // ============================================================================

  bool _sendRawXml(String xml) {
    if (_webSocket == null || !_webSocket!.isOpen) return false;
    try {
      _webSocket!.send(xml);
      return true;
    } catch (e) {
      debugPrint('Error sending raw XML: $e');
      return false;
    }
  }

  /// Send a MUC admin IQ stanza for role/affiliation changes.
  Future<bool> _sendMucAdminIq({
    required String roomJid,
    required Map<String, String> itemAttributes,
    String? reason,
  }) async {
    final attrs =
        itemAttributes.entries.map((e) => '${e.key}="${e.value}"').join(' ');

    final String itemElement;
    if (reason != null) {
      itemElement = '<item $attrs><reason>$reason</reason></item>';
    } else {
      itemElement = '<item $attrs/>';
    }

    final xml =
        '<iq to="$roomJid" type="set" id="muc_admin_1" xmlns="jabber:client"'
        '${_fullJid != null ? ' from="$_fullJid"' : ''}>'
        '<query xmlns="http://jabber.org/protocol/muc#admin">'
        '$itemElement'
        '</query></iq>';

    return _sendRawXml(xml);
  }
}
