import 'package:xml/xml.dart';

// ============================================================================
// XEP-0424: MESSAGE RETRACTION UTILITY METHODS
// ============================================================================
class XEP_0424 {
  /// Create a message retraction request (XEP-0424)
  ///
  /// [messageId] - Unique identifier for this retraction message
  /// [toJid] - Recipient's JID (same as original message)
  /// [fromJid] - Sender's JID (same as original message)
  /// [originalMessageId] - The ID of the original message to retract
  /// [type] - Message type (should match original message type)
  /// [fallbackText] - Optional fallback text for non-supporting clients
  /// [includeStoreHint] - Whether to include store hint for archiving
  static XmlDocument createMessageRetraction({
    required String messageId,
    required String toJid,
    required String fromJid,
    required String originalMessageId,
    String type = 'chat',
    String? fallbackText,
    bool includeStoreHint = true,
  }) {
    final builder = XmlBuilder();
    builder.element('message', attributes: {
      'xmlns': 'jabber:client',
      'id': messageId,
      'type': type,
      'from': fromJid,
      'to': toJid,
    }, nest: () {
      // Add retraction element
      builder.element('retract', attributes: {
        'id': originalMessageId,
        'xmlns': 'urn:xmpp:message-retract:1',
      });

      // Add fallback indication and body
      builder.element('fallback', attributes: {
        'xmlns': 'urn:xmpp:fallback:0',
        'for': 'urn:xmpp:message-retract:1',
      });

      final bodyText = fallbackText ??
          '/me retracted a previous message, but it\'s unsupported by your client.';
      builder.element('body', nest: bodyText);

      // Add store hint if requested
      if (includeStoreHint) {
        builder.element('store', attributes: {
          'xmlns': 'urn:xmpp:hints',
        });
      }
    });
    return builder.buildDocument();
  }

  /// Create a tombstone message for archived retracted message (XEP-0424)
  /// Used by archiving services to replace retracted message content
  ///
  /// [messageId] - Original message ID
  /// [toJid] - Recipient's JID
  /// [fromJid] - Sender's JID
  /// [retractionMessageId] - ID of the retraction message
  /// [retractionTimestamp] - When the retraction occurred
  /// [type] - Message type (should match original message type)
  static XmlDocument createTombstoneMessage({
    required String messageId,
    required String toJid,
    required String fromJid,
    required String retractionMessageId,
    required DateTime retractionTimestamp,
    String type = 'chat',
  }) {
    final builder = XmlBuilder();
    builder.element('message', attributes: {
      'xmlns': 'jabber:client',
      'id': messageId,
      'type': type,
      'from': fromJid,
      'to': toJid,
    }, nest: () {
      // Add retracted tombstone element
      builder.element('retracted', attributes: {
        'xmlns': 'urn:xmpp:message-retract:1',
        'id': retractionMessageId,
        'stamp': retractionTimestamp.toUtc().toIso8601String(),
      });
    });
    return builder.buildDocument();
  }

  /// Create a message retraction for individual chat
  /// Convenience method for 1-on-1 chat message retraction
  ///
  /// [messageId] - Unique identifier for this retraction message
  /// [toJid] - Recipient's JID
  /// [fromJid] - Sender's JID
  /// [originalMessageId] - The ID of the original message to retract
  /// [fallbackText] - Optional custom fallback text
  static XmlDocument createChatMessageRetraction({
    required String messageId,
    required String toJid,
    required String fromJid,
    required String originalMessageId,
    String? fallbackText,
  }) {
    return createMessageRetraction(
      messageId: messageId,
      toJid: toJid,
      fromJid: fromJid,
      originalMessageId: originalMessageId,
      type: 'chat',
      fallbackText: fallbackText,
    );
  }

  /// Create a message retraction for MUC groupchat
  /// Convenience method for MUC message retraction
  ///
  /// [messageId] - Unique identifier for this retraction message
  /// [roomJid] - Room JID
  /// [fromJid] - Sender's full JID (with resource)
  /// [originalMessageId] - The stanza ID assigned by the MUC service (XEP-0359)
  /// [fallbackText] - Optional custom fallback text
  static XmlDocument createGroupchatMessageRetraction({
    required String messageId,
    required String roomJid,
    required String fromJid,
    required String originalMessageId,
    String? fallbackText,
  }) {
    return createMessageRetraction(
      messageId: messageId,
      toJid: roomJid,
      fromJid: fromJid,
      originalMessageId: originalMessageId,
      type: 'groupchat',
      fallbackText: fallbackText,
    );
  }

  /// Create a tombstone for MAM (Message Archive Management) result
  /// Used in MAM query results to show retracted messages
  ///
  /// [messageId] - Original message ID
  /// [toJid] - Recipient's JID
  /// [fromJid] - Sender's JID
  /// [retractionMessageId] - ID of the retraction message
  /// [retractionTimestamp] - When the retraction occurred
  /// [originalTimestamp] - When the original message was sent
  /// [mamQueryId] - MAM query ID
  /// [mamStanzaId] - MAM stanza ID
  /// [type] - Message type
  static XmlDocument createMAMTombstone({
    required String messageId,
    required String toJid,
    required String fromJid,
    required String retractionMessageId,
    required DateTime retractionTimestamp,
    required DateTime originalTimestamp,
    required String mamQueryId,
    required String mamStanzaId,
    String type = 'groupchat',
  }) {
    final builder = XmlBuilder();
    builder.element('message', attributes: {
      'xmlns': 'jabber:client',
      'id': messageId,
      'to': toJid,
    }, nest: () {
      builder.element('result', attributes: {
        'xmlns': 'urn:xmpp:mam:2',
        'queryid': mamQueryId,
        'id': mamStanzaId,
      }, nest: () {
        builder.element('forwarded', attributes: {
          'xmlns': 'urn:xmpp:forward:0',
        }, nest: () {
          // Add delay for original message timestamp
          builder.element('delay', attributes: {
            'xmlns': 'urn:xmpp:delay',
            'stamp': originalTimestamp.toUtc().toIso8601String(),
          });

          // Add the tombstone message
          builder.element('message', attributes: {
            'type': type,
            'from': fromJid,
            'to': toJid,
            'id': messageId,
          }, nest: () {
            builder.element('retracted', attributes: {
              'xmlns': 'urn:xmpp:message-retract:1',
              'id': retractionMessageId,
              'stamp': retractionTimestamp.toUtc().toIso8601String(),
            });
          });
        });
      });
    });
    return builder.buildDocument();
  }

  /// Add retraction request to an existing message XML
  /// Utility method to convert a regular message into a retraction request
  ///
  /// [messageXml] - The existing message XML document
  /// [originalMessageId] - The ID of the message to retract
  /// [fallbackText] - Optional custom fallback text
  /// [includeStoreHint] - Whether to include store hint
  /// Returns a new XmlDocument with retraction elements added
  static XmlDocument addRetractionToMessage(
    XmlDocument messageXml,
    String originalMessageId, {
    String? fallbackText,
    bool includeStoreHint = true,
  }) {
    final builder = XmlBuilder();
    final rootElement = messageXml.rootElement;

    // Copy the original message structure
    builder.element(rootElement.name.local, attributes: {
      for (final attr in rootElement.attributes) attr.name.local: attr.value,
    }, nest: () {
      // Add retraction element first
      builder.element('retract', attributes: {
        'id': originalMessageId,
        'xmlns': 'urn:xmpp:message-retract:1',
      });

      // Add fallback indication
      builder.element('fallback', attributes: {
        'xmlns': 'urn:xmpp:fallback:0',
        'for': 'urn:xmpp:message-retract:1',
      });

      // Add or replace body with fallback text
      final bodyText = fallbackText ??
          '/me retracted a previous message, but it\'s unsupported by your client.';
      builder.element('body', nest: bodyText);

      // Copy other existing child elements (except body)
      for (final child in rootElement.children) {
        if (child is XmlElement && child.name.local != 'body') {
          _copyElement(builder, child);
        }
      }

      // Add store hint if requested
      if (includeStoreHint) {
        builder.element('store', attributes: {
          'xmlns': 'urn:xmpp:hints',
        });
      }
    });
    return builder.buildDocument();
  }

  /// Helper method to recursively copy XML elements
  static void _copyElement(XmlBuilder builder, XmlElement element) {
    builder.element(element.name.local, attributes: {
      for (final attr in element.attributes) attr.name.local: attr.value,
    }, nest: () {
      for (final child in element.children) {
        if (child is XmlElement) {
          _copyElement(builder, child);
        } else if (child is XmlText) {
          builder.text(child.value);
        }
      }
    });
  }
}
