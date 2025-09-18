import 'package:xml/xml.dart';

// ============================================================================
// XEP-0012: LAST ACTIVITY UTILITY METHODS
// ============================================================================
class XEP_0012 {
  /// Create a last activity query IQ (XEP-0012)
  ///
  /// [iqId] - Unique identifier for the IQ stanza
  /// [toJid] - Target JID to query (can be bare JID, full JID, or server JID)
  /// [fromJid] - Sender's JID
  static XmlDocument createLastActivityQuery({
    required String iqId,
    required String toJid,
    required String fromJid,
  }) {
    final builder = XmlBuilder();
    builder.element('iq', attributes: {
      'xmlns': 'jabber:client',
      'id': iqId,
      'type': 'get',
      'from': fromJid,
      'to': toJid,
    }, nest: () {
      builder.element('query', attributes: {
        'xmlns': 'jabber:iq:last',
      });
    });
    return builder.buildDocument();
  }

  /// Create a last activity response IQ (XEP-0012)
  ///
  /// [iqId] - IQ identifier (should match the query ID)
  /// [toJid] - Recipient's JID (original requester)
  /// [fromJid] - Sender's JID (original target)
  /// [seconds] - Number of seconds since last activity/logout/startup
  /// [statusMessage] - Optional status message (for offline user queries)
  static XmlDocument createLastActivityResponse({
    required String iqId,
    required String toJid,
    required String fromJid,
    required int seconds,
    String? statusMessage,
  }) {
    final builder = XmlBuilder();
    builder.element('iq', attributes: {
      'xmlns': 'jabber:client',
      'id': iqId,
      'type': 'result',
      'from': fromJid,
      'to': toJid,
    }, nest: () {
      builder.element('query', attributes: {
        'xmlns': 'jabber:iq:last',
        'seconds': seconds.toString(),
      }, nest: () {
        if (statusMessage != null && statusMessage.isNotEmpty) {
          builder.text(statusMessage);
        }
      });
    });
    return builder.buildDocument();
  }

  /// Create a forbidden error response for last activity query (XEP-0012)
  /// Used when the requesting entity is not authorized to view presence information
  ///
  /// [iqId] - IQ identifier (should match the query ID)
  /// [toJid] - Recipient's JID (original requester)
  /// [fromJid] - Sender's JID (original target)
  static XmlDocument createLastActivityForbiddenError({
    required String iqId,
    required String toJid,
    required String fromJid,
  }) {
    final builder = XmlBuilder();
    builder.element('iq', attributes: {
      'xmlns': 'jabber:client',
      'id': iqId,
      'type': 'error',
      'from': fromJid,
      'to': toJid,
    }, nest: () {
      builder.element('error', attributes: {
        'type': 'auth',
      }, nest: () {
        builder.element('forbidden', attributes: {
          'xmlns': 'urn:ietf:params:xml:ns:xmpp-stanzas',
        });
      });
    });
    return builder.buildDocument();
  }

  /// Create a service unavailable error response for last activity query (XEP-0012)
  /// Used when the client doesn't support the protocol or doesn't wish to divulge information
  ///
  /// [iqId] - IQ identifier (should match the query ID)
  /// [toJid] - Recipient's JID (original requester)
  /// [fromJid] - Sender's JID (original target)
  static XmlDocument createLastActivityServiceUnavailableError({
    required String iqId,
    required String toJid,
    required String fromJid,
  }) {
    final builder = XmlBuilder();
    builder.element('iq', attributes: {
      'xmlns': 'jabber:client',
      'id': iqId,
      'type': 'error',
      'from': fromJid,
      'to': toJid,
    }, nest: () {
      builder.element('error', attributes: {
        'type': 'cancel',
      }, nest: () {
        builder.element('service-unavailable', attributes: {
          'xmlns': 'urn:ietf:params:xml:ns:xmpp-stanzas',
        });
      });
    });
    return builder.buildDocument();
  }

  /// Create a last activity response for offline user query
  /// Convenience method for querying when a user was last online
  ///
  /// [iqId] - IQ identifier (should match the query ID)
  /// [toJid] - Recipient's JID (original requester)
  /// [fromJid] - Sender's JID (user's bare JID)
  /// [secondsSinceLogout] - Number of seconds since the user logged out
  /// [lastStatusMessage] - Optional status message from the last unavailable presence
  static XmlDocument createOfflineUserResponse({
    required String iqId,
    required String toJid,
    required String fromJid,
    required int secondsSinceLogout,
    String? lastStatusMessage,
  }) {
    return createLastActivityResponse(
      iqId: iqId,
      toJid: toJid,
      fromJid: fromJid,
      seconds: secondsSinceLogout,
      statusMessage: lastStatusMessage,
    );
  }

  /// Create a last activity response for online user query (idle time)
  /// Convenience method for responding with user's idle time
  ///
  /// [iqId] - IQ identifier (should match the query ID)
  /// [toJid] - Recipient's JID (original requester)
  /// [fromJid] - Sender's JID (user's full JID with resource)
  /// [idleSeconds] - Number of seconds the user has been idle
  static XmlDocument createOnlineUserResponse({
    required String iqId,
    required String toJid,
    required String fromJid,
    required int idleSeconds,
  }) {
    return createLastActivityResponse(
      iqId: iqId,
      toJid: toJid,
      fromJid: fromJid,
      seconds: idleSeconds,
      // No status message for online user queries
    );
  }

  /// Create a last activity response for server/component uptime query
  /// Convenience method for responding with server uptime
  ///
  /// [iqId] - IQ identifier (should match the query ID)
  /// [toJid] - Recipient's JID (original requester)
  /// [fromJid] - Sender's JID (server/component domain)
  /// [uptimeSeconds] - Number of seconds the server has been running
  static XmlDocument createServerUptimeResponse({
    required String iqId,
    required String toJid,
    required String fromJid,
    required int uptimeSeconds,
  }) {
    return createLastActivityResponse(
      iqId: iqId,
      toJid: toJid,
      fromJid: fromJid,
      seconds: uptimeSeconds,
      // No status message for server uptime queries
    );
  }

  /// Create a last activity response indicating user is currently online
  /// Used when the user has at least one connected resource (seconds = 0)
  ///
  /// [iqId] - IQ identifier (should match the query ID)
  /// [toJid] - Recipient's JID (original requester)
  /// [fromJid] - Sender's JID (user's bare JID)
  static XmlDocument createCurrentlyOnlineResponse({
    required String iqId,
    required String toJid,
    required String fromJid,
  }) {
    return createLastActivityResponse(
      iqId: iqId,
      toJid: toJid,
      fromJid: fromJid,
      seconds: 0, // 0 indicates currently online
    );
  }
}
