import 'package:xml/xml.dart';

// ============================================================================
// XEP-0085: CHAT STATE NOTIFICATIONS UTILITY METHODS
// ============================================================================
class XEP_0085 {
  /// Create a chat state notification message (XEP-0085)
  ///
  /// [messageId] - Unique identifier for the message
  /// [toJid] - Recipient's JID
  /// [fromJid] - Sender's JID
  /// [chatState] - The chat state (active, inactive, gone, composing, paused)
  /// [thread] - Optional thread identifier
  /// [type] - Message type (defaults to 'chat', can be 'groupchat' for MUC)
  static XmlDocument createChatStateNotification({
    required String messageId,
    required String toJid,
    required String fromJid,
    required String chatState,
    String? thread,
    String type = 'chat',
  }) {
    final builder = XmlBuilder();
    builder.element('message', attributes: {
      'xmlns': 'jabber:client',
      'id': messageId,
      'type': type,
      'from': fromJid,
      'to': toJid,
    }, nest: () {
      if (thread != null && thread.isNotEmpty) {
        builder.element('thread', nest: thread);
      }
      builder.element(chatState, attributes: {
        'xmlns': 'http://jabber.org/protocol/chatstates',
      });
    });
    return builder.buildDocument();
  }

  /// Create an 'active' chat state notification
  /// Indicates that the user is actively participating in the chat session
  static XmlDocument createActiveChatState({
    required String messageId,
    required String toJid,
    required String fromJid,
    String? thread,
    String type = 'chat',
  }) {
    return createChatStateNotification(
      messageId: messageId,
      toJid: toJid,
      fromJid: fromJid,
      chatState: 'active',
      thread: thread,
      type: type,
    );
  }

  /// Create an 'inactive' chat state notification
  /// Indicates that the user has not been actively participating in the chat session
  static XmlDocument createInactiveChatState({
    required String messageId,
    required String toJid,
    required String fromJid,
    String? thread,
    String type = 'chat',
  }) {
    return createChatStateNotification(
      messageId: messageId,
      toJid: toJid,
      fromJid: fromJid,
      chatState: 'inactive',
      thread: thread,
      type: type,
    );
  }

  /// Create a 'gone' chat state notification
  /// Indicates that the user has effectively ended their participation in the chat session
  static XmlDocument createGoneChatState({
    required String messageId,
    required String toJid,
    required String fromJid,
    String? thread,
    String type = 'chat',
  }) {
    return createChatStateNotification(
      messageId: messageId,
      toJid: toJid,
      fromJid: fromJid,
      chatState: 'gone',
      thread: thread,
      type: type,
    );
  }

  /// Create a 'composing' chat state notification
  /// Indicates that the user is composing a message
  static XmlDocument createComposingChatState({
    required String messageId,
    required String toJid,
    required String fromJid,
    String? thread,
    String type = 'chat',
  }) {
    return createChatStateNotification(
      messageId: messageId,
      toJid: toJid,
      fromJid: fromJid,
      chatState: 'composing',
      thread: thread,
      type: type,
    );
  }

  /// Create a 'paused' chat state notification
  /// Indicates that the user was composing but has paused
  static XmlDocument createPausedChatState({
    required String messageId,
    required String toJid,
    required String fromJid,
    String? thread,
    String type = 'chat',
  }) {
    return createChatStateNotification(
      messageId: messageId,
      toJid: toJid,
      fromJid: fromJid,
      chatState: 'paused',
      thread: thread,
      type: type,
    );
  }
}
