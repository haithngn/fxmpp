import 'package:xml/xml.dart';

// ============================================================================
// XEP-0313: MESSAGE ARCHIVE MANAGEMENT UTILITY METHODS
// ============================================================================
class XEP_0313 {
  /// Create a MAM query IQ (XEP-0313)
  ///
  /// [iqId] - Unique identifier for the IQ stanza
  /// [toJid] - Target JID (account or server hosting the archive)
  /// [fromJid] - Sender's JID
  /// [queryId] - Optional query ID to match results
  /// [withJid] - Optional JID filter for messages to/from specific contact
  /// [start] - Optional start timestamp (ISO 8601 format)
  /// [end] - Optional end timestamp (ISO 8601 format)
  /// [beforeId] - Optional before-id filter (requires extended support)
  /// [afterId] - Optional after-id filter (requires extended support)
  /// [ids] - Optional list of specific message IDs (requires extended support)
  /// [maxResults] - Optional RSM max results per page
  /// [rsmAfter] - Optional RSM after UID for paging
  /// [rsmBefore] - Optional RSM before UID for paging
  /// [customFields] - Optional custom form fields map
  static XmlDocument createMAMQuery({
    required String iqId,
    required String toJid,
    required String fromJid,
    String? queryId,
    String? withJid,
    String? start,
    String? end,
    String? beforeId,
    String? afterId,
    List<String>? ids,
    int? maxResults,
    String? rsmAfter,
    String? rsmBefore,
    Map<String, String>? customFields,
  }) {
    final builder = XmlBuilder();
    builder.element('iq', attributes: {
      'xmlns': 'jabber:client',
      'id': iqId,
      'type': 'set',
      'from': fromJid,
      'to': toJid,
    }, nest: () {
      builder.element('query', attributes: {
        'xmlns': 'urn:xmpp:mam:2',
        if (queryId != null) 'queryid': queryId,
      }, nest: () {
        // Add data form if any filters are specified
        if (withJid != null ||
            start != null ||
            end != null ||
            beforeId != null ||
            afterId != null ||
            ids != null ||
            customFields != null) {
          builder.element('x', attributes: {
            'xmlns': 'jabber:x:data',
            'type': 'submit',
          }, nest: () {
            // FORM_TYPE field (required)
            builder.element('field', attributes: {
              'var': 'FORM_TYPE',
              'type': 'hidden',
            }, nest: () {
              builder.element('value', nest: 'urn:xmpp:mam:2');
            });

            // with field (JID filter)
            if (withJid != null) {
              builder.element('field', attributes: {
                'var': 'with',
              }, nest: () {
                builder.element('value', nest: withJid);
              });
            }

            // start field (timestamp filter)
            if (start != null) {
              builder.element('field', attributes: {
                'var': 'start',
              }, nest: () {
                builder.element('value', nest: start);
              });
            }

            // end field (timestamp filter)
            if (end != null) {
              builder.element('field', attributes: {
                'var': 'end',
              }, nest: () {
                builder.element('value', nest: end);
              });
            }

            // before-id field (extended feature)
            if (beforeId != null) {
              builder.element('field', attributes: {
                'var': 'before-id',
              }, nest: () {
                builder.element('value', nest: beforeId);
              });
            }

            // after-id field (extended feature)
            if (afterId != null) {
              builder.element('field', attributes: {
                'var': 'after-id',
              }, nest: () {
                builder.element('value', nest: afterId);
              });
            }

            // ids field (extended feature)
            if (ids != null && ids.isNotEmpty) {
              builder.element('field', attributes: {
                'var': 'ids',
                'type': 'list-multi',
              }, nest: () {
                for (final id in ids) {
                  builder.element('value', nest: id);
                }
              });
            }

            // Custom fields
            if (customFields != null) {
              for (final entry in customFields.entries) {
                builder.element('field', attributes: {
                  'var': entry.key,
                }, nest: () {
                  builder.element('value', nest: entry.value);
                });
              }
            }
          });
        }

        // Add RSM set if paging parameters are specified
        if (maxResults != null || rsmAfter != null || rsmBefore != null) {
          builder.element('set', attributes: {
            'xmlns': 'http://jabber.org/protocol/rsm',
          }, nest: () {
            if (maxResults != null) {
              builder.element('max', nest: maxResults.toString());
            }
            if (rsmAfter != null) {
              builder.element('after', nest: rsmAfter);
            }
            if (rsmBefore != null) {
              builder.element('before', nest: rsmBefore);
            }
          });
        }
      });
    });
    return builder.buildDocument();
  }

  /// Create a MAM result message (XEP-0313)
  /// Used by servers to send archived messages to clients
  ///
  /// [messageId] - Unique identifier for this result message
  /// [toJid] - Recipient's JID (querying client)
  /// [queryId] - Query ID to match with original query
  /// [resultId] - Archive UID of this message
  /// [forwardedMessage] - The original archived message XML
  /// [delayStamp] - When the original message was received (ISO 8601)
  static XmlDocument createMAMResult({
    required String messageId,
    required String toJid,
    required String queryId,
    required String resultId,
    required XmlDocument forwardedMessage,
    required String delayStamp,
  }) {
    final builder = XmlBuilder();
    builder.element('message', attributes: {
      'xmlns': 'jabber:client',
      'id': messageId,
      'to': toJid,
    }, nest: () {
      builder.element('result', attributes: {
        'xmlns': 'urn:xmpp:mam:2',
        'queryid': queryId,
        'id': resultId,
      }, nest: () {
        builder.element('forwarded', attributes: {
          'xmlns': 'urn:xmpp:forward:0',
        }, nest: () {
          // Add delay element
          builder.element('delay', attributes: {
            'xmlns': 'urn:xmpp:delay',
            'stamp': delayStamp,
          });

          // Add the forwarded message
          _copyElement(builder, forwardedMessage.rootElement);
        });
      });
    });
    return builder.buildDocument();
  }

  /// Create a MAM fin IQ result (XEP-0313)
  /// Indicates the end of query results with RSM information
  ///
  /// [iqId] - IQ identifier (should match the query ID)
  /// [toJid] - Recipient's JID (original requester)
  /// [fromJid] - Sender's JID (archive host)
  /// [complete] - Whether this is the complete result set
  /// [firstId] - UID of first message in result set
  /// [lastId] - UID of last message in result set
  /// [count] - Optional total count of matching messages
  /// [index] - Optional index of first result in complete set
  static XmlDocument createMAMFin({
    required String iqId,
    required String toJid,
    required String fromJid,
    bool complete = false,
    String? firstId,
    String? lastId,
    int? count,
    int? index,
  }) {
    final builder = XmlBuilder();
    builder.element('iq', attributes: {
      'xmlns': 'jabber:client',
      'id': iqId,
      'type': 'result',
      'from': fromJid,
      'to': toJid,
    }, nest: () {
      builder.element('fin', attributes: {
        'xmlns': 'urn:xmpp:mam:2',
        if (complete) 'complete': 'true',
      }, nest: () {
        // Add RSM set if any RSM data is provided
        if (firstId != null || lastId != null || count != null) {
          builder.element('set', attributes: {
            'xmlns': 'http://jabber.org/protocol/rsm',
          }, nest: () {
            if (firstId != null) {
              builder.element('first',
                  attributes: {
                    if (index != null) 'index': index.toString(),
                  },
                  nest: firstId);
            }
            if (lastId != null) {
              builder.element('last', nest: lastId);
            }
            if (count != null) {
              builder.element('count', nest: count.toString());
            }
          });
        }
      });
    });
    return builder.buildDocument();
  }

  /// Create a simple MAM query with basic filters
  /// Convenience method for common MAM queries
  ///
  /// [iqId] - Unique identifier for the IQ stanza
  /// [toJid] - Target JID (account or server)
  /// [fromJid] - Sender's JID
  /// [queryId] - Optional query ID
  /// [withJid] - Optional contact JID filter
  /// [maxResults] - Optional max results per page
  static XmlDocument createSimpleMAMQuery({
    required String iqId,
    required String toJid,
    required String fromJid,
    String? queryId,
    String? withJid,
    int maxResults = 50,
  }) {
    return createMAMQuery(
      iqId: iqId,
      toJid: toJid,
      fromJid: fromJid,
      queryId: queryId,
      withJid: withJid,
      maxResults: maxResults,
    );
  }

  /// Create a MAM query with time range filter
  /// Convenience method for time-based queries
  ///
  /// [iqId] - Unique identifier for the IQ stanza
  /// [toJid] - Target JID (account or server)
  /// [fromJid] - Sender's JID
  /// [queryId] - Optional query ID
  /// [startTime] - Start of time range
  /// [endTime] - End of time range
  /// [withJid] - Optional contact JID filter
  /// [maxResults] - Optional max results per page
  static XmlDocument createTimeRangeMAMQuery({
    required String iqId,
    required String toJid,
    required String fromJid,
    String? queryId,
    required DateTime startTime,
    required DateTime endTime,
    String? withJid,
    int maxResults = 50,
  }) {
    return createMAMQuery(
      iqId: iqId,
      toJid: toJid,
      fromJid: fromJid,
      queryId: queryId,
      withJid: withJid,
      start: startTime.toUtc().toIso8601String(),
      end: endTime.toUtc().toIso8601String(),
      maxResults: maxResults,
    );
  }

  /// Create a MAM query for next page using RSM
  /// Convenience method for paging through results
  ///
  /// [iqId] - Unique identifier for the IQ stanza
  /// [toJid] - Target JID (account or server)
  /// [fromJid] - Sender's JID
  /// [queryId] - Query ID (should match original query)
  /// [afterId] - UID of last message from previous page
  /// [maxResults] - Max results per page
  /// [withJid] - Optional contact JID filter (should match original query)
  /// [start] - Optional start timestamp (should match original query)
  /// [end] - Optional end timestamp (should match original query)
  static XmlDocument createNextPageMAMQuery({
    required String iqId,
    required String toJid,
    required String fromJid,
    String? queryId,
    required String afterId,
    int maxResults = 50,
    String? withJid,
    String? start,
    String? end,
  }) {
    return createMAMQuery(
      iqId: iqId,
      toJid: toJid,
      fromJid: fromJid,
      queryId: queryId,
      withJid: withJid,
      start: start,
      end: end,
      maxResults: maxResults,
      rsmAfter: afterId,
    );
  }

  /// Create a MAM query with extended features
  /// For servers supporting 'urn:xmpp:mam:2#extended'
  ///
  /// [iqId] - Unique identifier for the IQ stanza
  /// [toJid] - Target JID (account or server)
  /// [fromJid] - Sender's JID
  /// [queryId] - Optional query ID
  /// [beforeId] - Messages before this archive UID
  /// [afterId] - Messages after this archive UID
  /// [specificIds] - List of specific message IDs to retrieve
  /// [maxResults] - Optional max results per page
  static XmlDocument createExtendedMAMQuery({
    required String iqId,
    required String toJid,
    required String fromJid,
    String? queryId,
    String? beforeId,
    String? afterId,
    List<String>? specificIds,
    int maxResults = 50,
  }) {
    return createMAMQuery(
      iqId: iqId,
      toJid: toJid,
      fromJid: fromJid,
      queryId: queryId,
      beforeId: beforeId,
      afterId: afterId,
      ids: specificIds,
      maxResults: maxResults,
    );
  }

  /// Create error response for MAM query
  /// Used when archive UID is not found or other errors occur
  ///
  /// [iqId] - IQ identifier (should match the query ID)
  /// [toJid] - Recipient's JID (original requester)
  /// [fromJid] - Sender's JID (archive host)
  /// [errorType] - Type of error (cancel, auth, etc.)
  /// [errorCondition] - Specific error condition
  static XmlDocument createMAMError({
    required String iqId,
    required String toJid,
    required String fromJid,
    String errorType = 'cancel',
    String errorCondition = 'item-not-found',
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
        'type': errorType,
      }, nest: () {
        builder.element(errorCondition, attributes: {
          'xmlns': 'urn:ietf:params:xml:ns:xmpp-stanzas',
        });
      });
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
