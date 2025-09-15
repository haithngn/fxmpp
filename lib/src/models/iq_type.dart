/// XMPP IQ stanza types
enum IqType {
  /// Get request
  get,
  
  /// Set request
  set,
  
  /// Result response
  result,
  
  /// Error response
  error;
  
  /// Convert enum to string value for XML
  String get value {
    switch (this) {
      case IqType.get:
        return 'get';
      case IqType.set:
        return 'set';
      case IqType.result:
        return 'result';
      case IqType.error:
        return 'error';
    }
  }
}
