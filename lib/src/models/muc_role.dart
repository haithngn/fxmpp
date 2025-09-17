/// MUC (Multi-User Chat) role enumeration
/// 
/// Roles define what a participant can do in a room.
/// Roles are temporary and tied to the participant's presence in the room.
enum MucRole {
  /// No role (kicked or banned)
  none('none'),
  
  /// Visitor - can receive messages but cannot send messages to all occupants
  visitor('visitor'),
  
  /// Participant - can send messages to all occupants
  participant('participant'),
  
  /// Moderator - can kick participants, grant/revoke voice, etc.
  moderator('moderator');

  const MucRole(this.value);
  
  /// The string value used in XMPP stanzas
  final String value;

  /// Parse role from string value
  static MucRole fromString(String value) {
    switch (value.toLowerCase()) {
      case 'none':
        return MucRole.none;
      case 'visitor':
        return MucRole.visitor;
      case 'participant':
        return MucRole.participant;
      case 'moderator':
        return MucRole.moderator;
      default:
        return MucRole.none;
    }
  }

  @override
  String toString() => value;
}
