/// MUC (Multi-User Chat) affiliation enumeration
///
/// Affiliations define a user's long-term relationship with a room.
/// Affiliations persist even when the user is not present in the room.
enum MucAffiliation {
  /// No affiliation (default for new users)
  none('none'),

  /// Outcast - banned from the room
  outcast('outcast'),

  /// Member - can enter members-only rooms
  member('member'),

  /// Admin - can ban users, grant/revoke membership, etc.
  admin('admin'),

  /// Owner - can destroy room, make others admins, etc.
  owner('owner');

  const MucAffiliation(this.value);

  /// The string value used in XMPP stanzas
  final String value;

  /// Parse affiliation from string value
  static MucAffiliation fromString(String value) {
    switch (value.toLowerCase()) {
      case 'none':
        return MucAffiliation.none;
      case 'outcast':
        return MucAffiliation.outcast;
      case 'member':
        return MucAffiliation.member;
      case 'admin':
        return MucAffiliation.admin;
      case 'owner':
        return MucAffiliation.owner;
      default:
        return MucAffiliation.none;
    }
  }

  @override
  String toString() => value;
}
