import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:xml/xml.dart';

import 'fxmpp_method_channel.dart';
import 'models/xmpp_connection_config.dart';
import 'models/xmpp_connection_state.dart';

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
    throw UnimplementedError('setConnectionStateCallback() has not been implemented.');
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
}
