import 'package:fxmpp/src/core/xmpp_connection_config.dart';
import 'package:fxmpp/src/core/xmpp_connection_state.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:xml/xml.dart';

import 'fxmpp_method_channel.dart';

abstract class FxmppPlatform extends PlatformInterface {
  /// Constructs a FxmppPlatform.
  FxmppPlatform() : super(token: _token);

  static final Object _token = Object();

  static FxmppPlatform _instance = MethodChannelFxmpp();

  /// The default instance of [FxmppPlatform] to use.
  ///
  /// Defaults to [MethodChannelFxmpp].
  static FxmppPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FxmppPlatform] when
  /// they register themselves.
  static set instance(FxmppPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Initialize the plugin
  Future<void> initialize() {
    throw UnimplementedError('initialize() has not been implemented.');
  }

  /// Connect to XMPP server
  Future<bool> connect(XmppConnectionConfig config) {
    throw UnimplementedError('connect() has not been implemented.');
  }

  /// Disconnect from XMPP server
  Future<void> disconnect() {
    throw UnimplementedError('disconnect() has not been implemented.');
  }

  /// Send a message as XML
  Future<bool> sendMessage(XmlDocument message) {
    throw UnimplementedError('sendMessage() has not been implemented.');
  }

  /// Send presence as XML
  Future<bool> sendPresence(XmlDocument presence) {
    throw UnimplementedError('sendPresence() has not been implemented.');
  }

  /// Send IQ stanza as XML
  Future<bool> sendIq(XmlDocument iq) {
    throw UnimplementedError('sendIq() has not been implemented.');
  }

  /// Get current connection state
  Future<XmppConnectionState> getConnectionState() {
    throw UnimplementedError('getConnectionState() has not been implemented.');
  }

  /// Set connection state callback
  void setConnectionStateCallback(Function(XmppConnectionState) callback) {
    throw UnimplementedError(
        'setConnectionStateCallback() has not been implemented.');
  }

  /// Set message callback
  void setMessageCallback(Function(XmlDocument) callback) {
    throw UnimplementedError('setMessageCallback() has not been implemented.');
  }

  /// Set presence callback
  void setPresenceCallback(Function(XmlDocument) callback) {
    throw UnimplementedError('setPresenceCallback() has not been implemented.');
  }

  /// Set IQ callback
  void setIqCallback(Function(XmlDocument) callback) {
    throw UnimplementedError('setIqCallback() has not been implemented.');
  }

  // ============================================================================
  // MUC (Multi-User Chat) METHODS
  // ============================================================================

  /// Join a MUC room
  Future<bool> joinMucRoom({
    required String roomJid,
    required String nickname,
    String? password,
    int? maxStanzas,
    DateTime? since,
  }) {
    throw UnimplementedError('joinMucRoom() has not been implemented.');
  }

  /// Leave a MUC room
  Future<bool> leaveMucRoom({
    required String roomJid,
    String? reason,
  }) {
    throw UnimplementedError('leaveMucRoom() has not been implemented.');
  }

  /// Send a message to a MUC room
  Future<bool> sendMucMessage(XmlDocument message) {
    throw UnimplementedError('sendMucMessage() has not been implemented.');
  }

  /// Send a private message to a room participant
  Future<bool> sendMucPrivateMessage(XmlDocument message) {
    throw UnimplementedError(
        'sendMucPrivateMessage() has not been implemented.');
  }

  /// Change room subject/topic
  Future<bool> changeMucSubject({
    required String roomJid,
    required String subject,
  }) {
    throw UnimplementedError('changeMucSubject() has not been implemented.');
  }

  /// Kick a participant from the room
  Future<bool> kickMucParticipant({
    required String roomJid,
    required String nickname,
    String? reason,
  }) {
    throw UnimplementedError('kickMucParticipant() has not been implemented.');
  }

  /// Ban a user from the room
  Future<bool> banMucUser({
    required String roomJid,
    required String userJid,
    String? reason,
  }) {
    throw UnimplementedError('banMucUser() has not been implemented.');
  }

  /// Grant voice to a participant
  Future<bool> grantMucVoice({
    required String roomJid,
    required String nickname,
    String? reason,
  }) {
    throw UnimplementedError('grantMucVoice() has not been implemented.');
  }

  /// Revoke voice from a participant
  Future<bool> revokeMucVoice({
    required String roomJid,
    required String nickname,
    String? reason,
  }) {
    throw UnimplementedError('revokeMucVoice() has not been implemented.');
  }

  /// Grant moderator privileges to a participant
  Future<bool> grantMucModerator({
    required String roomJid,
    required String nickname,
    String? reason,
  }) {
    throw UnimplementedError('grantMucModerator() has not been implemented.');
  }

  /// Grant membership to a user
  Future<bool> grantMucMembership({
    required String roomJid,
    required String userJid,
    String? reason,
  }) {
    throw UnimplementedError('grantMucMembership() has not been implemented.');
  }

  /// Grant admin privileges to a user
  Future<bool> grantMucAdmin({
    required String roomJid,
    required String userJid,
    String? reason,
  }) {
    throw UnimplementedError('grantMucAdmin() has not been implemented.');
  }

  /// Invite a user to the room
  Future<bool> inviteMucUser({
    required String roomJid,
    required String userJid,
    String? reason,
  }) {
    throw UnimplementedError('inviteMucUser() has not been implemented.');
  }

  /// Destroy a room (owner only)
  Future<bool> destroyMucRoom({
    required String roomJid,
    String? reason,
    String? alternativeRoom,
  }) {
    throw UnimplementedError('destroyMucRoom() has not been implemented.');
  }

  /// Create a new MUC room
  Future<bool> createMucRoom({
    required String roomJid,
    required String nickname,
    String? password,
  }) {
    throw UnimplementedError('createMucRoom() has not been implemented.');
  }

  /// Set MUC event callback
  void setMucEventCallback(Function(Map<String, dynamic>) callback) {
    throw UnimplementedError('setMucEventCallback() has not been implemented.');
  }
}
