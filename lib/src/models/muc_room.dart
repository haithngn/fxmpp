import 'muc_participant.dart';
import 'muc_role.dart';
import 'muc_affiliation.dart';

/// Represents a MUC (Multi-User Chat) room
class MucRoom {
  /// The room's JID (room@server)
  final String jid;
  
  /// The room's human-readable name
  final String? name;
  
  /// The room's description
  final String? description;
  
  /// The room's subject/topic
  final String? subject;
  
  /// The user's nickname in this room
  final String? userNickname;
  
  /// The user's role in this room
  final MucRole? userRole;
  
  /// The user's affiliation with this room
  final MucAffiliation? userAffiliation;
  
  /// Whether the user has joined this room
  final bool isJoined;
  
  /// List of participants currently in the room
  final List<MucParticipant> participants;
  
  /// Room configuration options
  final MucRoomConfig config;
  
  /// When the user joined this room
  final DateTime? joinedAt;
  
  /// The maximum number of occupants allowed
  final int? maxOccupants;
  
  /// Number of current occupants
  final int occupantCount;

  const MucRoom({
    required this.jid,
    this.name,
    this.description,
    this.subject,
    this.userNickname,
    this.userRole,
    this.userAffiliation,
    this.isJoined = false,
    this.participants = const [],
    this.config = const MucRoomConfig(),
    this.joinedAt,
    this.maxOccupants,
    this.occupantCount = 0,
  });

  /// Create a copy of this room with updated values
  MucRoom copyWith({
    String? jid,
    String? name,
    String? description,
    String? subject,
    String? userNickname,
    MucRole? userRole,
    MucAffiliation? userAffiliation,
    bool? isJoined,
    List<MucParticipant>? participants,
    MucRoomConfig? config,
    DateTime? joinedAt,
    int? maxOccupants,
    int? occupantCount,
  }) {
    return MucRoom(
      jid: jid ?? this.jid,
      name: name ?? this.name,
      description: description ?? this.description,
      subject: subject ?? this.subject,
      userNickname: userNickname ?? this.userNickname,
      userRole: userRole ?? this.userRole,
      userAffiliation: userAffiliation ?? this.userAffiliation,
      isJoined: isJoined ?? this.isJoined,
      participants: participants ?? this.participants,
      config: config ?? this.config,
      joinedAt: joinedAt ?? this.joinedAt,
      maxOccupants: maxOccupants ?? this.maxOccupants,
      occupantCount: occupantCount ?? this.occupantCount,
    );
  }

  /// Get a participant by nickname
  MucParticipant? getParticipant(String nickname) {
    try {
      return participants.firstWhere((p) => p.nickname == nickname);
    } catch (e) {
      return null;
    }
  }

  /// Check if a participant is in the room
  bool hasParticipant(String nickname) {
    return participants.any((p) => p.nickname == nickname);
  }

  /// Get the room's server component
  String get server {
    final parts = jid.split('@');
    return parts.length > 1 ? parts[1] : jid;
  }

  /// Get the room's local name
  String get localName {
    final parts = jid.split('@');
    return parts.isNotEmpty ? parts[0] : jid;
  }

  /// Convert to map for serialization
  Map<String, dynamic> toMap() {
    return {
      'jid': jid,
      'name': name,
      'description': description,
      'subject': subject,
      'userNickname': userNickname,
      'userRole': userRole?.value,
      'userAffiliation': userAffiliation?.value,
      'isJoined': isJoined,
      'participants': participants.map((p) => p.toMap()).toList(),
      'config': config.toMap(),
      'joinedAt': joinedAt?.millisecondsSinceEpoch,
      'maxOccupants': maxOccupants,
      'occupantCount': occupantCount,
    };
  }

  /// Create from map
  factory MucRoom.fromMap(Map<String, dynamic> map) {
    return MucRoom(
      jid: map['jid'] as String,
      name: map['name'] as String?,
      description: map['description'] as String?,
      subject: map['subject'] as String?,
      userNickname: map['userNickname'] as String?,
      userRole: map['userRole'] != null 
          ? MucRole.fromString(map['userRole'] as String)
          : null,
      userAffiliation: map['userAffiliation'] != null 
          ? MucAffiliation.fromString(map['userAffiliation'] as String)
          : null,
      isJoined: map['isJoined'] as bool? ?? false,
      participants: (map['participants'] as List<dynamic>?)
          ?.map((p) => MucParticipant.fromMap(p as Map<String, dynamic>))
          .toList() ?? [],
      config: map['config'] != null 
          ? MucRoomConfig.fromMap(map['config'] as Map<String, dynamic>)
          : const MucRoomConfig(),
      joinedAt: map['joinedAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['joinedAt'] as int)
          : null,
      maxOccupants: map['maxOccupants'] as int?,
      occupantCount: map['occupantCount'] as int? ?? 0,
    );
  }

  @override
  String toString() {
    return 'MucRoom(jid: $jid, name: $name, isJoined: $isJoined, participants: ${participants.length})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MucRoom && other.jid == jid;
  }

  @override
  int get hashCode => jid.hashCode;
}

/// Configuration options for a MUC room
class MucRoomConfig {
  /// Whether the room is password protected
  final bool isPasswordProtected;
  
  /// Whether the room is members-only
  final bool isMembersOnly;
  
  /// Whether the room is moderated
  final bool isModerated;
  
  /// Whether the room is persistent
  final bool isPersistent;
  
  /// Whether the room is public (discoverable)
  final bool isPublic;
  
  /// Whether participants can invite others
  final bool allowInvites;
  
  /// Whether participants can change the subject
  final bool allowSubjectChange;
  
  /// Whether real JIDs are visible to participants
  final bool showRealJids;
  
  /// Whether the room logs conversations
  final bool isLogged;

  const MucRoomConfig({
    this.isPasswordProtected = false,
    this.isMembersOnly = false,
    this.isModerated = false,
    this.isPersistent = false,
    this.isPublic = true,
    this.allowInvites = true,
    this.allowSubjectChange = true,
    this.showRealJids = false,
    this.isLogged = false,
  });

  /// Create a copy with updated values
  MucRoomConfig copyWith({
    bool? isPasswordProtected,
    bool? isMembersOnly,
    bool? isModerated,
    bool? isPersistent,
    bool? isPublic,
    bool? allowInvites,
    bool? allowSubjectChange,
    bool? showRealJids,
    bool? isLogged,
  }) {
    return MucRoomConfig(
      isPasswordProtected: isPasswordProtected ?? this.isPasswordProtected,
      isMembersOnly: isMembersOnly ?? this.isMembersOnly,
      isModerated: isModerated ?? this.isModerated,
      isPersistent: isPersistent ?? this.isPersistent,
      isPublic: isPublic ?? this.isPublic,
      allowInvites: allowInvites ?? this.allowInvites,
      allowSubjectChange: allowSubjectChange ?? this.allowSubjectChange,
      showRealJids: showRealJids ?? this.showRealJids,
      isLogged: isLogged ?? this.isLogged,
    );
  }

  /// Convert to map for serialization
  Map<String, dynamic> toMap() {
    return {
      'isPasswordProtected': isPasswordProtected,
      'isMembersOnly': isMembersOnly,
      'isModerated': isModerated,
      'isPersistent': isPersistent,
      'isPublic': isPublic,
      'allowInvites': allowInvites,
      'allowSubjectChange': allowSubjectChange,
      'showRealJids': showRealJids,
      'isLogged': isLogged,
    };
  }

  /// Create from map
  factory MucRoomConfig.fromMap(Map<String, dynamic> map) {
    return MucRoomConfig(
      isPasswordProtected: map['isPasswordProtected'] as bool? ?? false,
      isMembersOnly: map['isMembersOnly'] as bool? ?? false,
      isModerated: map['isModerated'] as bool? ?? false,
      isPersistent: map['isPersistent'] as bool? ?? false,
      isPublic: map['isPublic'] as bool? ?? true,
      allowInvites: map['allowInvites'] as bool? ?? true,
      allowSubjectChange: map['allowSubjectChange'] as bool? ?? true,
      showRealJids: map['showRealJids'] as bool? ?? false,
      isLogged: map['isLogged'] as bool? ?? false,
    );
  }

  @override
  String toString() {
    return 'MucRoomConfig(isPasswordProtected: $isPasswordProtected, isMembersOnly: $isMembersOnly, isModerated: $isModerated)';
  }
}
