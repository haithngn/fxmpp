import 'dart:async';
import 'dart:developer';
import 'package:fxmpp/src/core/iq_type.dart';
import 'package:fxmpp/src/core/message_type.dart';
import 'package:fxmpp/src/core/muc_affiliation.dart';
import 'package:fxmpp/src/core/muc_participant.dart';
import 'package:fxmpp/src/core/muc_role.dart';
import 'package:fxmpp/src/core/muc_room.dart';
import 'package:xml/xml.dart';

/// Manager class for MUC (Multi-User Chat) operations
class MucManager {
  /// Map of joined rooms by JID
  final Map<String, MucRoom> _rooms = {};

  /// Stream controller for room events
  final StreamController<MucRoomEvent> _roomEventController =
      StreamController<MucRoomEvent>.broadcast();

  /// Stream controller for participant events
  final StreamController<MucParticipantEvent> _participantEventController =
      StreamController<MucParticipantEvent>.broadcast();

  /// Stream controller for MUC messages
  final StreamController<MucMessage> _mucMessageController =
      StreamController<MucMessage>.broadcast();

  /// Stream of room events (joined, left, created, etc.)
  Stream<MucRoomEvent> get roomEventStream => _roomEventController.stream;

  /// Stream of participant events (joined, left, role changed, etc.)
  Stream<MucParticipantEvent> get participantEventStream =>
      _participantEventController.stream;

  /// Stream of MUC messages
  Stream<MucMessage> get mucMessageStream => _mucMessageController.stream;

  /// Get all joined rooms
  List<MucRoom> get joinedRooms =>
      _rooms.values.where((room) => room.isJoined).toList();

  /// Get all rooms (joined and not joined)
  List<MucRoom> get allRooms => _rooms.values.toList();

  /// Get a room by JID
  MucRoom? getRoom(String roomJid) => _rooms[roomJid];

  /// Check if user is in a room
  bool isInRoom(String roomJid) => _rooms[roomJid]?.isJoined ?? false;

  /// Create a new MUC room
  ///
  /// [roomJid] - The JID of the room to create (room@server)
  /// [nickname] - The nickname to use in the room
  /// [config] - Optional room configuration
  /// [password] - Optional room password
  XmlDocument createRoom({
    required String roomJid,
    required String nickname,
    required String userJid,
    MucRoomConfig? config,
    String? password,
  }) {
    final builder = XmlBuilder();
    builder.element('presence', attributes: {
      'xmlns': 'jabber:client',
      'from': userJid,
      'to': '$roomJid/$nickname',
    }, nest: () {
      builder.element('x', attributes: {
        'xmlns': 'http://jabber.org/protocol/muc',
      }, nest: () {
        if (password != null && password.isNotEmpty) {
          builder.element('password', nest: password);
        }
      });
    });

    // Add room to local cache
    _rooms[roomJid] = MucRoom(
      jid: roomJid,
      userNickname: nickname,
      config: config ?? const MucRoomConfig(),
    );

    return builder.buildDocument();
  }

  /// Join an existing MUC room
  ///
  /// [roomJid] - The JID of the room to join (room@server)
  /// [nickname] - The nickname to use in the room
  /// [password] - Optional room password
  /// [maxStanzas] - Maximum number of history messages to request
  /// [since] - Request history since this date
  XmlDocument joinRoom({
    required String roomJid,
    required String nickname,
    required String userJid,
    String? password,
    int? maxStanzas,
    DateTime? since,
  }) {
    final builder = XmlBuilder();
    builder.element('presence', attributes: {
      'xmlns': 'jabber:client',
      'from': userJid,
      'to': '$roomJid/$nickname',
    }, nest: () {
      builder.element('x', attributes: {
        'xmlns': 'http://jabber.org/protocol/muc',
      }, nest: () {
        if (password != null && password.isNotEmpty) {
          builder.element('password', nest: password);
        }

        // History management
        if (maxStanzas != null || since != null) {
          builder.element('history', attributes: {
            if (maxStanzas != null) 'maxstanzas': maxStanzas.toString(),
            if (since != null) 'since': since.toUtc().toIso8601String(),
          });
        }
      });
    });

    // Add or update room in local cache
    final existingRoom = _rooms[roomJid];
    _rooms[roomJid] = (existingRoom ?? MucRoom(jid: roomJid)).copyWith(
      userNickname: nickname,
    );

    return builder.buildDocument();
  }

  /// Leave a MUC room
  ///
  /// [roomJid] - The JID of the room to leave
  /// [reason] - Optional reason for leaving
  XmlDocument leaveRoom({
    required String roomJid,
    required String userJid,
    String? reason,
  }) {
    final room = _rooms[roomJid];
    if (room == null || !room.isJoined || room.userNickname == null) {
      throw StateError('Not joined to room $roomJid');
    }

    final builder = XmlBuilder();
    builder.element('presence', attributes: {
      'xmlns': 'jabber:client',
      'type': 'unavailable',
      'from': userJid,
      'to': '${room.jid}/${room.userNickname}',
    }, nest: () {
      if (reason != null && reason.isNotEmpty) {
        builder.element('status', nest: reason);
      }
    });

    return builder.buildDocument();
  }

  /// Send a message to a MUC room
  ///
  /// [roomJid] - The JID of the room
  /// [message] - The message content
  /// [subject] - Optional subject change
  /// [thread] - Optional thread ID
  XmlDocument sendRoomMessage({
    required String roomJid,
    required String userJid,
    required String message,
    String? subject,
    String? thread,
  }) {
    final room = _rooms[roomJid];
    if (room == null || !room.isJoined) {
      throw StateError('Not joined to room $roomJid');
    }

    final messageId = _generateId('msg');
    final builder = XmlBuilder();
    builder.element('message', attributes: {
      'xmlns': 'jabber:client',
      'id': messageId,
      'type': MessageType.groupchat.value,
      'from': userJid,
      'to': roomJid,
    }, nest: () {
      if (subject != null && subject.isNotEmpty) {
        builder.element('subject', nest: subject);
      }
      builder.element('body', nest: message);
      if (thread != null && thread.isNotEmpty) {
        builder.element('thread', nest: thread);
      }
    });

    return builder.buildDocument();
  }

  /// Send a private message to a room participant
  ///
  /// [roomJid] - The JID of the room
  /// [nickname] - The nickname of the participant
  /// [message] - The message content
  XmlDocument sendPrivateMessage({
    required String roomJid,
    required String nickname,
    required String userJid,
    required String message,
  }) {
    final room = _rooms[roomJid];
    if (room == null || !room.isJoined) {
      throw StateError('Not joined to room $roomJid');
    }

    final messageId = _generateId('pm');
    final builder = XmlBuilder();
    builder.element('message', attributes: {
      'xmlns': 'jabber:client',
      'id': messageId,
      'type': MessageType.chat.value,
      'from': userJid,
      'to': '$roomJid/$nickname',
    }, nest: () {
      builder.element('body', nest: message);
    });

    return builder.buildDocument();
  }

  /// Change room subject/topic
  ///
  /// [roomJid] - The JID of the room
  /// [subject] - The new subject
  XmlDocument changeRoomSubject({
    required String roomJid,
    required String userJid,
    required String subject,
  }) {
    final room = _rooms[roomJid];
    if (room == null || !room.isJoined) {
      throw StateError('Not joined to room $roomJid');
    }

    final messageId = _generateId('subj');
    final builder = XmlBuilder();
    builder.element('message', attributes: {
      'xmlns': 'jabber:client',
      'id': messageId,
      'type': MessageType.groupchat.value,
      'from': userJid,
      'to': roomJid,
    }, nest: () {
      builder.element('subject', nest: subject);
    });

    return builder.buildDocument();
  }

  /// Kick a participant from the room
  ///
  /// [roomJid] - The JID of the room
  /// [nickname] - The nickname of the participant to kick
  /// [reason] - Optional reason for kicking
  XmlDocument kickParticipant({
    required String roomJid,
    required String nickname,
    required String userJid,
    String? reason,
  }) {
    return _setRole(
      roomJid: roomJid,
      nickname: nickname,
      userJid: userJid,
      role: MucRole.none,
      reason: reason,
    );
  }

  /// Grant voice to a participant (make them participant)
  ///
  /// [roomJid] - The JID of the room
  /// [nickname] - The nickname of the participant
  /// [reason] - Optional reason
  XmlDocument grantVoice({
    required String roomJid,
    required String nickname,
    required String userJid,
    String? reason,
  }) {
    return _setRole(
      roomJid: roomJid,
      nickname: nickname,
      userJid: userJid,
      role: MucRole.participant,
      reason: reason,
    );
  }

  /// Revoke voice from a participant (make them visitor)
  ///
  /// [roomJid] - The JID of the room
  /// [nickname] - The nickname of the participant
  /// [reason] - Optional reason
  XmlDocument revokeVoice({
    required String roomJid,
    required String nickname,
    required String userJid,
    String? reason,
  }) {
    return _setRole(
      roomJid: roomJid,
      nickname: nickname,
      userJid: userJid,
      role: MucRole.visitor,
      reason: reason,
    );
  }

  /// Grant moderator privileges to a participant
  ///
  /// [roomJid] - The JID of the room
  /// [nickname] - The nickname of the participant
  /// [reason] - Optional reason
  XmlDocument grantModerator({
    required String roomJid,
    required String nickname,
    required String userJid,
    String? reason,
  }) {
    return _setRole(
      roomJid: roomJid,
      nickname: nickname,
      userJid: userJid,
      role: MucRole.moderator,
      reason: reason,
    );
  }

  /// Ban a user from the room (set affiliation to outcast)
  ///
  /// [roomJid] - The JID of the room
  /// [userJidToBan] - The real JID of the user to ban
  /// [reason] - Optional reason for banning
  XmlDocument banUser({
    required String roomJid,
    required String userJidToBan,
    required String userJid,
    String? reason,
  }) {
    return _setAffiliation(
      roomJid: roomJid,
      targetJid: userJidToBan,
      userJid: userJid,
      affiliation: MucAffiliation.outcast,
      reason: reason,
    );
  }

  /// Grant membership to a user
  ///
  /// [roomJid] - The JID of the room
  /// [memberJid] - The JID of the user to make member
  /// [reason] - Optional reason
  XmlDocument grantMembership({
    required String roomJid,
    required String memberJid,
    required String userJid,
    String? reason,
  }) {
    return _setAffiliation(
      roomJid: roomJid,
      targetJid: memberJid,
      userJid: userJid,
      affiliation: MucAffiliation.member,
      reason: reason,
    );
  }

  /// Grant admin privileges to a user
  ///
  /// [roomJid] - The JID of the room
  /// [adminJid] - The JID of the user to make admin
  /// [reason] - Optional reason
  XmlDocument grantAdmin({
    required String roomJid,
    required String adminJid,
    required String userJid,
    String? reason,
  }) {
    return _setAffiliation(
      roomJid: roomJid,
      targetJid: adminJid,
      userJid: userJid,
      affiliation: MucAffiliation.admin,
      reason: reason,
    );
  }

  /// Invite a user to the room
  ///
  /// [roomJid] - The JID of the room
  /// [inviteeJid] - The JID of the user to invite
  /// [reason] - Optional invitation message
  XmlDocument inviteUser({
    required String roomJid,
    required String inviteeJid,
    required String userJid,
    String? reason,
  }) {
    final messageId = _generateId('invite');
    final builder = XmlBuilder();
    builder.element('message', attributes: {
      'xmlns': 'jabber:client',
      'id': messageId,
      'from': userJid,
      'to': roomJid,
    }, nest: () {
      builder.element('x', attributes: {
        'xmlns': 'http://jabber.org/protocol/muc#user',
      }, nest: () {
        builder.element('invite', attributes: {
          'to': inviteeJid,
        }, nest: () {
          if (reason != null && reason.isNotEmpty) {
            builder.element('reason', nest: reason);
          }
        });
      });
    });

    return builder.buildDocument();
  }

  /// Destroy a room (owner only)
  ///
  /// [roomJid] - The JID of the room to destroy
  /// [reason] - Optional reason for destruction
  /// [alternativeRoom] - Optional alternative room JID
  XmlDocument destroyRoom({
    required String roomJid,
    required String userJid,
    String? reason,
    String? alternativeRoom,
  }) {
    final iqId = _generateId('destroy');
    final builder = XmlBuilder();
    builder.element('iq', attributes: {
      'xmlns': 'jabber:client',
      'id': iqId,
      'type': IqType.set.value,
      'from': userJid,
      'to': roomJid,
    }, nest: () {
      builder.element('query', attributes: {
        'xmlns': 'http://jabber.org/protocol/muc#owner',
      }, nest: () {
        builder.element('destroy', attributes: {
          if (alternativeRoom != null) 'jid': alternativeRoom,
        }, nest: () {
          if (reason != null && reason.isNotEmpty) {
            builder.element('reason', nest: reason);
          }
        });
      });
    });

    return builder.buildDocument();
  }

  /// Process incoming presence stanza for MUC
  void handlePresence(XmlDocument presenceDoc) {
    try {
      final presence = presenceDoc.rootElement;
      final from = presence.getAttribute('from');
      final type = presence.getAttribute('type');

      if (from == null) return;

      final parts = from.split('/');
      if (parts.length != 2) return;

      final roomJid = parts[0];
      final nickname = parts[1];

      // Check if this is a MUC presence
      final mucUser = presence
          .findElements('x')
          .where((x) =>
              x.getAttribute('xmlns') == 'http://jabber.org/protocol/muc#user')
          .firstOrNull;

      if (mucUser == null) return;

      final room = _rooms[roomJid];
      if (room == null) return;

      if (type == 'unavailable') {
        _handleParticipantLeft(room, nickname, mucUser);
      } else {
        _handleParticipantJoined(room, nickname, presence, mucUser);
      }
    } catch (e) {
      log('Error handling MUC presence: $e');
    }
  }

  /// Process incoming message stanza for MUC
  void handleMessage(XmlDocument messageDoc) {
    try {
      final message = messageDoc.rootElement;
      final from = message.getAttribute('from');
      final type = message.getAttribute('type');
      final id = message.getAttribute('id');

      if (from == null || type != MessageType.groupchat.value) return;

      final parts = from.split('/');
      final roomJid = parts[0];
      final nickname = parts.length > 1 ? parts[1] : null;

      final room = _rooms[roomJid];
      if (room == null || !room.isJoined) return;

      final body = message.findElements('body').firstOrNull?.value;
      final subject = message.findElements('subject').firstOrNull?.value;
      final thread = message.findElements('thread').firstOrNull?.value;

      final mucMessage = MucMessage(
        id: id ?? _generateId('msg'),
        roomJid: roomJid,
        senderNickname: nickname,
        body: body,
        subject: subject,
        thread: thread,
        timestamp: DateTime.now(),
        isPrivate: false,
      );

      _mucMessageController.add(mucMessage);

      // Handle subject change
      if (subject != null) {
        final updatedRoom = room.copyWith(subject: subject);
        _rooms[roomJid] = updatedRoom;
        _roomEventController.add(MucRoomEvent(
          type: MucRoomEventType.subjectChanged,
          room: updatedRoom,
          data: {'subject': subject, 'changedBy': nickname},
        ));
      }
    } catch (e) {
      log('Error handling MUC message: $e');
    }
  }

  /// Internal method to set participant role
  XmlDocument _setRole({
    required String roomJid,
    required String nickname,
    required String userJid,
    required MucRole role,
    String? reason,
  }) {
    final iqId = _generateId('role');
    final builder = XmlBuilder();
    builder.element('iq', attributes: {
      'xmlns': 'jabber:client',
      'id': iqId,
      'type': IqType.set.value,
      'from': userJid,
      'to': roomJid,
    }, nest: () {
      builder.element('query', attributes: {
        'xmlns': 'http://jabber.org/protocol/muc#admin',
      }, nest: () {
        builder.element('item', attributes: {
          'nick': nickname,
          'role': role.value,
        }, nest: () {
          if (reason != null && reason.isNotEmpty) {
            builder.element('reason', nest: reason);
          }
        });
      });
    });

    return builder.buildDocument();
  }

  /// Internal method to set user affiliation
  XmlDocument _setAffiliation({
    required String roomJid,
    required String targetJid,
    required String userJid,
    required MucAffiliation affiliation,
    String? reason,
  }) {
    final iqId = _generateId('affiliation');
    final builder = XmlBuilder();
    builder.element('iq', attributes: {
      'xmlns': 'jabber:client',
      'id': iqId,
      'type': IqType.set.value,
      'from': userJid,
      'to': roomJid,
    }, nest: () {
      builder.element('query', attributes: {
        'xmlns': 'http://jabber.org/protocol/muc#admin',
      }, nest: () {
        builder.element('item', attributes: {
          'jid': targetJid,
          'affiliation': affiliation.value,
        }, nest: () {
          if (reason != null && reason.isNotEmpty) {
            builder.element('reason', nest: reason);
          }
        });
      });
    });

    return builder.buildDocument();
  }

  /// Handle participant joining
  void _handleParticipantJoined(
      MucRoom room, String nickname, XmlElement presence, XmlElement mucUser) {
    final item = mucUser.findElements('item').firstOrNull;
    if (item == null) return;

    final role = MucRole.fromString(item.getAttribute('role') ?? 'none');
    final affiliation =
        MucAffiliation.fromString(item.getAttribute('affiliation') ?? 'none');
    final realJid = item.getAttribute('jid');

    final show = presence.findElements('show').firstOrNull?.value;
    final status = presence.findElements('status').firstOrNull?.value;

    final participant = MucParticipant(
      nickname: nickname,
      realJid: realJid,
      roomJid: '${room.jid}/$nickname',
      role: role,
      affiliation: affiliation,
      show: show,
      status: status,
      isOnline: true,
      joinedAt: DateTime.now(),
    );

    // Update room with new participant
    final participants = List<MucParticipant>.from(room.participants);
    final existingIndex =
        participants.indexWhere((p) => p.nickname == nickname);

    if (existingIndex >= 0) {
      participants[existingIndex] = participant;
    } else {
      participants.add(participant);
    }

    final updatedRoom = room.copyWith(
      participants: participants,
      occupantCount: participants.length,
      isJoined: nickname == room.userNickname ? true : room.isJoined,
      userRole: nickname == room.userNickname ? role : room.userRole,
      userAffiliation:
          nickname == room.userNickname ? affiliation : room.userAffiliation,
      joinedAt: nickname == room.userNickname && !room.isJoined
          ? DateTime.now()
          : room.joinedAt,
    );

    _rooms[room.jid] = updatedRoom;

    // Emit events
    if (nickname == room.userNickname) {
      _roomEventController.add(MucRoomEvent(
        type: MucRoomEventType.joined,
        room: updatedRoom,
      ));
    }

    _participantEventController.add(MucParticipantEvent(
      type: MucParticipantEventType.joined,
      room: updatedRoom,
      participant: participant,
    ));
  }

  /// Handle participant leaving
  void _handleParticipantLeft(
      MucRoom room, String nickname, XmlElement mucUser) {
    final participants = List<MucParticipant>.from(room.participants);
    final participantIndex =
        participants.indexWhere((p) => p.nickname == nickname);

    if (participantIndex >= 0) {
      final participant = participants.removeAt(participantIndex);

      final updatedRoom = room.copyWith(
        participants: participants,
        occupantCount: participants.length,
        isJoined: nickname == room.userNickname ? false : room.isJoined,
      );

      _rooms[room.jid] = updatedRoom;

      // Emit events
      if (nickname == room.userNickname) {
        _roomEventController.add(MucRoomEvent(
          type: MucRoomEventType.left,
          room: updatedRoom,
        ));
      }

      _participantEventController.add(MucParticipantEvent(
        type: MucParticipantEventType.left,
        room: updatedRoom,
        participant: participant,
      ));
    }
  }

  /// Generate a unique ID
  String _generateId([String prefix = 'muc']) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 10000).toString().padLeft(4, '0');
    return '${prefix}_${timestamp}_$random';
  }

  /// Dispose resources
  void dispose() {
    _roomEventController.close();
    _participantEventController.close();
    _mucMessageController.close();
    _rooms.clear();
  }
}

/// MUC room event types
enum MucRoomEventType {
  joined,
  left,
  created,
  destroyed,
  subjectChanged,
  configurationChanged,
}

/// MUC room event
class MucRoomEvent {
  final MucRoomEventType type;
  final MucRoom room;
  final Map<String, dynamic>? data;

  const MucRoomEvent({
    required this.type,
    required this.room,
    this.data,
  });

  @override
  String toString() => 'MucRoomEvent(type: $type, room: ${room.jid})';
}

/// MUC participant event types
enum MucParticipantEventType {
  joined,
  left,
  roleChanged,
  affiliationChanged,
  statusChanged,
  kicked,
  banned,
}

/// MUC participant event
class MucParticipantEvent {
  final MucParticipantEventType type;
  final MucRoom room;
  final MucParticipant participant;
  final Map<String, dynamic>? data;

  const MucParticipantEvent({
    required this.type,
    required this.room,
    required this.participant,
    this.data,
  });

  @override
  String toString() =>
      'MucParticipantEvent(type: $type, participant: ${participant.nickname})';
}

/// MUC message
class MucMessage {
  final String id;
  final String roomJid;
  final String? senderNickname;
  final String? body;
  final String? subject;
  final String? thread;
  final DateTime timestamp;
  final bool isPrivate;

  const MucMessage({
    required this.id,
    required this.roomJid,
    this.senderNickname,
    this.body,
    this.subject,
    this.thread,
    required this.timestamp,
    this.isPrivate = false,
  });

  @override
  String toString() =>
      'MucMessage(id: $id, room: $roomJid, sender: $senderNickname, body: $body)';
}
