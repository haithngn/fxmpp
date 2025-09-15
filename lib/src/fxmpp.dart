import 'dart:async';
import 'dart:developer';
import 'package:xml/xml.dart';

import 'fxmpp_platform_interface.dart';
import 'models/xmpp_connection_config.dart';
import 'models/xmpp_connection_state.dart';
import 'models/message_type.dart';
import 'models/presence_type.dart';
import 'models/iq_type.dart';

/// Main FXMPP class for XMPP operations
class Fxmpp {
  static final Fxmpp _instance = Fxmpp._internal();
  factory Fxmpp() => _instance;
  Fxmpp._internal();

  /// Stream controller for connection state changes
  final StreamController<XmppConnectionState> _connectionStateController =
      StreamController<XmppConnectionState>.broadcast();

  /// Stream controller for incoming messages
  final StreamController<XmlDocument> _messageController =
      StreamController<XmlDocument>.broadcast();

  /// Stream controller for presence updates
  final StreamController<XmlDocument> _presenceController =
      StreamController<XmlDocument>.broadcast();

  /// Stream controller for IQ stanzas
  final StreamController<XmlDocument> _iqController =
      StreamController<XmlDocument>.broadcast();

  /// Stream of connection state changes
  Stream<XmppConnectionState> get connectionStateStream =>
      _connectionStateController.stream;

  /// Stream of incoming messages
  Stream<XmlDocument> get messageStream => _messageController.stream;

  /// Stream of presence updates
  Stream<XmlDocument> get presenceStream => _presenceController.stream;

  /// Stream of IQ stanzas
  Stream<XmlDocument> get iqStream => _iqController.stream;

  /// Connect to XMPP server
  Future<bool> connect(XmppConnectionConfig config) async {
    log("[XMPP-Connection] connect ${config.toString()}");
    try {
      final result = await FxmppPlatform.instance.connect(config);
      return result;
    } catch (e) {
      _connectionStateController.add(XmppConnectionState.error);
      rethrow;
    }
  }

  /// Disconnect from XMPP server
  Future<void> disconnect() async {
    await FxmppPlatform.instance.disconnect();
    log("[XMPP-Connection] << disconnect");
    _connectionStateController.add(XmppConnectionState.disconnected);
  }

  /// Send a message
  Future<bool> sendMessage(XmlDocument message) async {
    log("[XMPP-Message] >>> ${message.toXmlString()}");
    return await FxmppPlatform.instance.sendMessage(message);
  }

  /// Send presence
  Future<bool> sendPresence(XmlDocument presence) async {
    log("[XMPP-Presence] >>> ${presence.toXmlString()}");
    return await FxmppPlatform.instance.sendPresence(presence);
  }

  /// Send IQ stanza
  Future<bool> sendIq(XmlDocument iq) async {
    log("[XMPP-IQ] >>> ${iq.toXmlString()}");
    return await FxmppPlatform.instance.sendIq(iq);
  }

  /// Get current connection state
  Future<XmppConnectionState> getConnectionState() async {
    return await FxmppPlatform.instance.getConnectionState();
  }

  /// Initialize the plugin and set up listeners
  Future<void> initialize() async {
    await FxmppPlatform.instance.initialize();

    // Set up platform callbacks
    FxmppPlatform.instance.setConnectionStateCallback((state) {
      log("[XMPP-Connection] didChangeConnectionState $state");
      _connectionStateController.add(state);
    });

    FxmppPlatform.instance.setMessageCallback((message) {
      log("[XMPP-Message] <<< ${message.toXmlString()}");
      _messageController.add(message);
    });

    FxmppPlatform.instance.setPresenceCallback((presence) {
      log("[XMPP-Presence] <<< ${presence.toXmlString()}");
      _presenceController.add(presence);
    });

    FxmppPlatform.instance.setIqCallback((iq) {
      log("[XMPP-IQ] <<< ${iq.toXmlString()}");
      _iqController.add(iq);
    });
  }

  /// Dispose resources
  void dispose() {
    _connectionStateController.close();
    _messageController.close();
    _presenceController.close();
    _iqController.close();
  }

  // ============================================================================
  // UTILITY METHODS FOR CREATING BASIC STANZAS
  // ============================================================================

  /// Create a basic message stanza
  /// 
  /// [messageId] - Unique identifier for the message
  /// [type] - Type of message (chat, groupchat, normal, etc.)
  /// [fromJid] - Sender's JID
  /// [toJid] - Recipient's JID
  /// [content] - Message content/body
  /// [subject] - Optional message subject
  /// [thread] - Optional thread identifier for conversation tracking
  static XmlDocument createMessage({
    required String messageId,
    required MessageType type,
    required String fromJid,
    required String toJid,
    required String content,
    String? subject,
    String? thread,
  }) {
    final builder = XmlBuilder();
    builder.element('message', attributes: {
      'xmlns': 'jabber:client',
      'id': messageId,
      'type': type.value,
      'from': fromJid,
      'to': toJid,
    }, nest: () {
      if (subject != null && subject.isNotEmpty) {
        builder.element('subject', nest: subject);
      }
      builder.element('body', nest: content);
      if (thread != null && thread.isNotEmpty) {
        builder.element('thread', nest: thread);
      }
    });
    return builder.buildDocument();
  }

  /// Create a basic presence stanza
  /// 
  /// [presenceId] - Optional unique identifier for the presence
  /// [type] - Type of presence (available, unavailable, subscribe, etc.)
  /// [fromJid] - Sender's JID
  /// [toJid] - Optional recipient's JID (for directed presence)
  /// [show] - Availability status (away, dnd, chat, etc.)
  /// [status] - Human-readable status message
  /// [priority] - Presence priority (-128 to 127)
  static XmlDocument createPresence({
    String? presenceId,
    PresenceType type = PresenceType.available,
    required String fromJid,
    String? toJid,
    PresenceShow show = PresenceShow.available,
    String? status,
    int? priority,
  }) {
    final builder = XmlBuilder();
    final attributes = <String, String>{
      'xmlns': 'jabber:client',
      'from': fromJid,
    };
    
    if (presenceId != null) {
      attributes['id'] = presenceId;
    }
    
    if (type.value != null) {
      attributes['type'] = type.value!;
    }
    
    if (toJid != null) {
      attributes['to'] = toJid;
    }
    
    builder.element('presence', attributes: attributes, nest: () {
      if (show.value != null) {
        builder.element('show', nest: show.value!);
      }
      if (status != null && status.isNotEmpty) {
        builder.element('status', nest: status);
      }
      if (priority != null) {
        builder.element('priority', nest: priority.toString());
      }
    });
    return builder.buildDocument();
  }

  /// Create a basic IQ stanza
  /// 
  /// [iqId] - Unique identifier for the IQ
  /// [type] - Type of IQ (get, set, result, error)
  /// [fromJid] - Sender's JID
  /// [toJid] - Recipient's JID
  /// [queryElement] - Optional query element for the IQ payload
  static XmlDocument createIq({
    required String iqId,
    required IqType type,
    required String fromJid,
    required String toJid,
    XmlElement? queryElement,
  }) {
    final builder = XmlBuilder();
    builder.element('iq', attributes: {
      'xmlns': 'jabber:client',
      'id': iqId,
      'type': type.value,
      'from': fromJid,
      'to': toJid,
    }, nest: () {
      if (queryElement != null) {
        builder.element(queryElement.name.local, 
          attributes: Map.fromEntries(queryElement.attributes.map((attr) => 
            MapEntry(attr.name.local, attr.value))),
          nest: () {
            for (final child in queryElement.children) {
              if (child is XmlElement) {
                _addElementRecursively(builder, child);
              } else if (child is XmlText) {
                builder.text(child.text);
              }
            }
          });
      }
    });
    return builder.buildDocument();
  }

  /// Helper method to recursively add XML elements
  static void _addElementRecursively(XmlBuilder builder, XmlElement element) {
    builder.element(element.name.local,
      attributes: Map.fromEntries(element.attributes.map((attr) => 
        MapEntry(attr.name.local, attr.value))),
      nest: () {
        for (final child in element.children) {
          if (child is XmlElement) {
            _addElementRecursively(builder, child);
          } else if (child is XmlText) {
            builder.text(child.text);
          }
        }
      });
  }

  /// Create a disco#info IQ query
  /// 
  /// [iqId] - Unique identifier for the IQ
  /// [fromJid] - Sender's JID
  /// [toJid] - Target JID to query
  /// [node] - Optional node to query
  static XmlDocument createDiscoInfoQuery({
    required String iqId,
    required String fromJid,
    required String toJid,
    String? node,
  }) {
    final builder = XmlBuilder();
    builder.element('iq', attributes: {
      'xmlns': 'jabber:client',
      'id': iqId,
      'type': 'get',
      'from': fromJid,
      'to': toJid,
    }, nest: () {
      final queryAttrs = <String, String>{
        'xmlns': 'http://jabber.org/protocol/disco#info',
      };
      if (node != null) {
        queryAttrs['node'] = node;
      }
      builder.element('query', attributes: queryAttrs);
    });
    return builder.buildDocument();
  }

  /// Create a version IQ query
  /// 
  /// [iqId] - Unique identifier for the IQ
  /// [fromJid] - Sender's JID
  /// [toJid] - Target JID to query
  static XmlDocument createVersionQuery({
    required String iqId,
    required String fromJid,
    required String toJid,
  }) {
    final builder = XmlBuilder();
    builder.element('iq', attributes: {
      'xmlns': 'jabber:client',
      'id': iqId,
      'type': 'get',
      'from': fromJid,
      'to': toJid,
    }, nest: () {
      builder.element('query', attributes: {
        'xmlns': 'jabber:iq:version',
      });
    });
    return builder.buildDocument();
  }

  /// Create a time IQ query
  /// 
  /// [iqId] - Unique identifier for the IQ
  /// [fromJid] - Sender's JID
  /// [toJid] - Target JID to query
  static XmlDocument createTimeQuery({
    required String iqId,
    required String fromJid,
    required String toJid,
  }) {
    final builder = XmlBuilder();
    builder.element('iq', attributes: {
      'xmlns': 'jabber:client',
      'id': iqId,
      'type': 'get',
      'from': fromJid,
      'to': toJid,
    }, nest: () {
      builder.element('time', attributes: {
        'xmlns': 'urn:xmpp:time',
      });
    });
    return builder.buildDocument();
  }

  /// Generate a unique ID for stanzas
  /// 
  /// [prefix] - Optional prefix for the ID
  static String generateId([String prefix = 'fxmpp']) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 10000).toString().padLeft(4, '0');
    return '${prefix}_${timestamp}_$random';
  }
}
