/// XMPP message types
enum MessageType {
  /// Normal message (default)
  normal,

  /// Chat message (one-to-one conversation)
  chat,

  /// Group chat message
  groupchat,

  /// Headline message (news, alerts)
  headline,

  /// Error message
  error;

  /// Convert enum to string value for XML
  String get value {
    switch (this) {
      case MessageType.normal:
        return 'normal';
      case MessageType.chat:
        return 'chat';
      case MessageType.groupchat:
        return 'groupchat';
      case MessageType.headline:
        return 'headline';
      case MessageType.error:
        return 'error';
    }
  }
}
