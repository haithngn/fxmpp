/// XMPP presence types
enum PresenceType {
  /// Available presence (default, no type attribute)
  available,
  
  /// Unavailable presence
  unavailable,
  
  /// Subscribe to someone's presence
  subscribe,
  
  /// Unsubscribe from someone's presence
  unsubscribe,
  
  /// Subscribed confirmation
  subscribed,
  
  /// Unsubscribed confirmation
  unsubscribed,
  
  /// Probe for presence
  probe,
  
  /// Error presence
  error;
  
  /// Convert enum to string value for XML (null for available)
  String? get value {
    switch (this) {
      case PresenceType.available:
        return null; // No type attribute for available
      case PresenceType.unavailable:
        return 'unavailable';
      case PresenceType.subscribe:
        return 'subscribe';
      case PresenceType.unsubscribe:
        return 'unsubscribe';
      case PresenceType.subscribed:
        return 'subscribed';
      case PresenceType.unsubscribed:
        return 'unsubscribed';
      case PresenceType.probe:
        return 'probe';
      case PresenceType.error:
        return 'error';
    }
  }
}

/// XMPP presence show values
enum PresenceShow {
  /// Available (default, no show element)
  available,
  
  /// Away
  away,
  
  /// Extended away
  xa,
  
  /// Do not disturb
  dnd,
  
  /// Free for chat
  chat;
  
  /// Convert enum to string value for XML (null for available)
  String? get value {
    switch (this) {
      case PresenceShow.available:
        return null; // No show element for available
      case PresenceShow.away:
        return 'away';
      case PresenceShow.xa:
        return 'xa';
      case PresenceShow.dnd:
        return 'dnd';
      case PresenceShow.chat:
        return 'chat';
    }
  }
}
