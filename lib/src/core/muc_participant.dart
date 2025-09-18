import 'muc_role.dart';
import 'muc_affiliation.dart';

/// Represents a participant in a MUC room
class MucParticipant {
  /// The participant's nickname in the room
  final String nickname;

  /// The participant's real JID (if known and allowed to be seen)
  final String? realJid;

  /// The participant's full JID in the room (room@server/nickname)
  final String roomJid;

  /// The participant's current role in the room
  final MucRole role;

  /// The participant's affiliation with the room
  final MucAffiliation affiliation;

  /// The participant's status message
  final String? status;

  /// The participant's show status (away, dnd, etc.)
  final String? show;

  /// Whether the participant is currently online
  final bool isOnline;

  /// When the participant joined the room
  final DateTime? joinedAt;

  const MucParticipant({
    required this.nickname,
    this.realJid,
    required this.roomJid,
    required this.role,
    required this.affiliation,
    this.status,
    this.show,
    this.isOnline = true,
    this.joinedAt,
  });

  /// Create a copy of this participant with updated values
  MucParticipant copyWith({
    String? nickname,
    String? realJid,
    String? roomJid,
    MucRole? role,
    MucAffiliation? affiliation,
    String? status,
    String? show,
    bool? isOnline,
    DateTime? joinedAt,
  }) {
    return MucParticipant(
      nickname: nickname ?? this.nickname,
      realJid: realJid ?? this.realJid,
      roomJid: roomJid ?? this.roomJid,
      role: role ?? this.role,
      affiliation: affiliation ?? this.affiliation,
      status: status ?? this.status,
      show: show ?? this.show,
      isOnline: isOnline ?? this.isOnline,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }

  /// Convert to map for serialization
  Map<String, dynamic> toMap() {
    return {
      'nickname': nickname,
      'realJid': realJid,
      'roomJid': roomJid,
      'role': role.value,
      'affiliation': affiliation.value,
      'status': status,
      'show': show,
      'isOnline': isOnline,
      'joinedAt': joinedAt?.millisecondsSinceEpoch,
    };
  }

  /// Create from map
  factory MucParticipant.fromMap(Map<String, dynamic> map) {
    return MucParticipant(
      nickname: map['nickname'] as String,
      realJid: map['realJid'] as String?,
      roomJid: map['roomJid'] as String,
      role: MucRole.fromString(map['role'] as String),
      affiliation: MucAffiliation.fromString(map['affiliation'] as String),
      status: map['status'] as String?,
      show: map['show'] as String?,
      isOnline: map['isOnline'] as bool? ?? true,
      joinedAt: map['joinedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['joinedAt'] as int)
          : null,
    );
  }

  @override
  String toString() {
    return 'MucParticipant(nickname: $nickname, role: $role, affiliation: $affiliation, isOnline: $isOnline)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MucParticipant &&
        other.nickname == nickname &&
        other.roomJid == roomJid;
  }

  @override
  int get hashCode => nickname.hashCode ^ roomJid.hashCode;
}
