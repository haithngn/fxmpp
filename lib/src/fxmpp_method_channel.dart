import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:xml/xml.dart';

import 'fxmpp_platform_interface.dart';
import 'models/xmpp_connection_config.dart';
import 'models/xmpp_connection_state.dart';

/// An implementation of [FxmppPlatform] that uses method channels.
class MethodChannelFxmpp extends FxmppPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('fxmpp');

  /// The event channel for receiving connection state updates
  @visibleForTesting
  final connectionStateEventChannel =
      const EventChannel('fxmpp/connection_state');

  /// The event channel for receiving messages
  @visibleForTesting
  final messageEventChannel = const EventChannel('fxmpp/messages');

  /// The event channel for receiving presence updates
  @visibleForTesting
  final presenceEventChannel = const EventChannel('fxmpp/presence');

  /// The event channel for receiving IQ stanzas
  @visibleForTesting
  final iqEventChannel = const EventChannel('fxmpp/iq');

  /// The event channel for receiving MUC events
  @visibleForTesting
  final mucEventChannel = const EventChannel('fxmpp/muc_events');

  Function(XmppConnectionState)? _connectionStateCallback;
  Function(XmlDocument)? _messageCallback;
  Function(XmlDocument)? _presenceCallback;
  Function(XmlDocument)? _iqCallback;
  Function(Map<String, dynamic>)? _mucEventCallback;

  @override
  Future<void> initialize() async {
    // Set up event channel listeners
    connectionStateEventChannel.receiveBroadcastStream().listen((event) {
      if (_connectionStateCallback != null) {
        final state = XmppConnectionState.values[event as int];
        _connectionStateCallback!(state);
      }
    });

    messageEventChannel.receiveBroadcastStream().listen((event) {
      if (_messageCallback != null) {
        String xmlString;
        if (event is Map) {
          xmlString = event['xml'] as String;
        } else {
          xmlString = event as String;
        }
        try {
          final xmlDocument = XmlDocument.parse(xmlString);
          _messageCallback!(xmlDocument);
        } catch (e) {
          debugPrint('Error parsing message XML: $e');
        }
      }
    });

    presenceEventChannel.receiveBroadcastStream().listen((event) {
      if (_presenceCallback != null) {
        String xmlString;
        if (event is Map) {
          xmlString = event['xml'] as String;
        } else {
          xmlString = event as String;
        }
        try {
          final xmlDocument = XmlDocument.parse(xmlString);
          _presenceCallback!(xmlDocument);
        } catch (e) {
          debugPrint('Error parsing presence XML: $e');
        }
      }
    });

    iqEventChannel.receiveBroadcastStream().listen((event) {
      if (_iqCallback != null) {
        String xmlString;
        if (event is Map) {
          xmlString = event['xml'] as String;
        } else {
          xmlString = event as String;
        }
        try {
          final xmlDocument = XmlDocument.parse(xmlString);
          _iqCallback!(xmlDocument);
        } catch (e) {
          debugPrint('Error parsing IQ XML: $e');
        }
      }
    });

    mucEventChannel.receiveBroadcastStream().listen((event) {
      if (_mucEventCallback != null && event is Map<String, dynamic>) {
        _mucEventCallback!(event);
      }
    });
  }

  @override
  Future<bool> connect(XmppConnectionConfig config) async {
    final result =
        await methodChannel.invokeMethod<bool>('connect', config.toMap());
    return result ?? false;
  }

  @override
  Future<void> disconnect() async {
    await methodChannel.invokeMethod<void>('disconnect');
  }

  @override
  Future<bool> sendMessage(XmlDocument message) async {
    final result = await methodChannel
        .invokeMethod<bool>('sendMessage', {'xml': message.toXmlString()});
    return result ?? false;
  }

  @override
  Future<bool> sendPresence(XmlDocument presence) async {
    final result = await methodChannel
        .invokeMethod<bool>('sendPresence', {'xml': presence.toXmlString()});
    return result ?? false;
  }

  @override
  Future<bool> sendIq(XmlDocument iq) async {
    final result = await methodChannel
        .invokeMethod<bool>('sendIq', {'xml': iq.toXmlString()});
    return result ?? false;
  }

  @override
  Future<XmppConnectionState> getConnectionState() async {
    final result = await methodChannel.invokeMethod<int>('getConnectionState');
    return XmppConnectionState.values[result ?? 0];
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

  // ============================================================================
  // MUC (Multi-User Chat) METHODS
  // ============================================================================

  @override
  Future<bool> joinMucRoom({
    required String roomJid,
    required String nickname,
    String? password,
    int? maxStanzas,
    DateTime? since,
  }) async {
    final params = <String, dynamic>{
      'roomJid': roomJid,
      'nickname': nickname,
    };
    if (password != null) params['password'] = password;
    if (maxStanzas != null) params['maxStanzas'] = maxStanzas;
    if (since != null) params['since'] = since.millisecondsSinceEpoch;

    final result = await methodChannel.invokeMethod<bool>('joinMucRoom', params);
    return result ?? false;
  }

  @override
  Future<bool> leaveMucRoom({
    required String roomJid,
    String? reason,
  }) async {
    final params = <String, dynamic>{
      'roomJid': roomJid,
    };
    if (reason != null) params['reason'] = reason;

    final result = await methodChannel.invokeMethod<bool>('leaveMucRoom', params);
    return result ?? false;
  }

  @override
  Future<bool> sendMucMessage(XmlDocument message) async {
    final result = await methodChannel
        .invokeMethod<bool>('sendMucMessage', {'xml': message.toXmlString()});
    return result ?? false;
  }

  @override
  Future<bool> sendMucPrivateMessage(XmlDocument message) async {
    final result = await methodChannel
        .invokeMethod<bool>('sendMucPrivateMessage', {'xml': message.toXmlString()});
    return result ?? false;
  }

  @override
  Future<bool> changeMucSubject({
    required String roomJid,
    required String subject,
  }) async {
    final params = <String, dynamic>{
      'roomJid': roomJid,
      'subject': subject,
    };

    final result = await methodChannel.invokeMethod<bool>('changeMucSubject', params);
    return result ?? false;
  }

  @override
  Future<bool> kickMucParticipant({
    required String roomJid,
    required String nickname,
    String? reason,
  }) async {
    final params = <String, dynamic>{
      'roomJid': roomJid,
      'nickname': nickname,
    };
    if (reason != null) params['reason'] = reason;

    final result = await methodChannel.invokeMethod<bool>('kickMucParticipant', params);
    return result ?? false;
  }

  @override
  Future<bool> banMucUser({
    required String roomJid,
    required String userJid,
    String? reason,
  }) async {
    final params = <String, dynamic>{
      'roomJid': roomJid,
      'userJid': userJid,
    };
    if (reason != null) params['reason'] = reason;

    final result = await methodChannel.invokeMethod<bool>('banMucUser', params);
    return result ?? false;
  }

  @override
  Future<bool> grantMucVoice({
    required String roomJid,
    required String nickname,
    String? reason,
  }) async {
    final params = <String, dynamic>{
      'roomJid': roomJid,
      'nickname': nickname,
    };
    if (reason != null) params['reason'] = reason;

    final result = await methodChannel.invokeMethod<bool>('grantMucVoice', params);
    return result ?? false;
  }

  @override
  Future<bool> revokeMucVoice({
    required String roomJid,
    required String nickname,
    String? reason,
  }) async {
    final params = <String, dynamic>{
      'roomJid': roomJid,
      'nickname': nickname,
    };
    if (reason != null) params['reason'] = reason;

    final result = await methodChannel.invokeMethod<bool>('revokeMucVoice', params);
    return result ?? false;
  }

  @override
  Future<bool> grantMucModerator({
    required String roomJid,
    required String nickname,
    String? reason,
  }) async {
    final params = <String, dynamic>{
      'roomJid': roomJid,
      'nickname': nickname,
    };
    if (reason != null) params['reason'] = reason;

    final result = await methodChannel.invokeMethod<bool>('grantMucModerator', params);
    return result ?? false;
  }

  @override
  Future<bool> grantMucMembership({
    required String roomJid,
    required String userJid,
    String? reason,
  }) async {
    final params = <String, dynamic>{
      'roomJid': roomJid,
      'userJid': userJid,
    };
    if (reason != null) params['reason'] = reason;

    final result = await methodChannel.invokeMethod<bool>('grantMucMembership', params);
    return result ?? false;
  }

  @override
  Future<bool> grantMucAdmin({
    required String roomJid,
    required String userJid,
    String? reason,
  }) async {
    final params = <String, dynamic>{
      'roomJid': roomJid,
      'userJid': userJid,
    };
    if (reason != null) params['reason'] = reason;

    final result = await methodChannel.invokeMethod<bool>('grantMucAdmin', params);
    return result ?? false;
  }

  @override
  Future<bool> inviteMucUser({
    required String roomJid,
    required String userJid,
    String? reason,
  }) async {
    final params = <String, dynamic>{
      'roomJid': roomJid,
      'userJid': userJid,
    };
    if (reason != null) params['reason'] = reason;

    final result = await methodChannel.invokeMethod<bool>('inviteMucUser', params);
    return result ?? false;
  }

  @override
  Future<bool> destroyMucRoom({
    required String roomJid,
    String? reason,
    String? alternativeRoom,
  }) async {
    final params = <String, dynamic>{
      'roomJid': roomJid,
    };
    if (reason != null) params['reason'] = reason;
    if (alternativeRoom != null) params['alternativeRoom'] = alternativeRoom;

    final result = await methodChannel.invokeMethod<bool>('destroyMucRoom', params);
    return result ?? false;
  }

  @override
  Future<bool> createMucRoom({
    required String roomJid,
    required String nickname,
    String? password,
  }) async {
    final params = <String, dynamic>{
      'roomJid': roomJid,
      'nickname': nickname,
    };
    if (password != null) params['password'] = password;

    final result = await methodChannel.invokeMethod<bool>('createMucRoom', params);
    return result ?? false;
  }

  @override
  void setMucEventCallback(Function(Map<String, dynamic>) callback) {
    _mucEventCallback = callback;
  }
}
