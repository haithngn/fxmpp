import 'dart:convert';

/// SASL PLAIN mechanism encoder (RFC 4616).
///
/// Produces a base64-encoded payload: `\0username\0password`
class SaslPlain {
  /// Encode SASL PLAIN credentials as base64.
  ///
  /// [username] is the localpart of the JID (without domain).
  /// [password] is the account password.
  static String encode(String username, String password) {
    final payload = '\u0000$username\u0000$password';
    return base64Encode(utf8.encode(payload));
  }
}
