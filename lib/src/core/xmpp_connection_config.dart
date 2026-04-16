/// Configuration for XMPP connection
class XmppConnectionConfig {
  final String host;
  final int port;
  final String username;
  final String password;
  final String domain;
  final bool useSSL;
  final bool allowSelfSignedCertificates;
  final String? resource;

  /// WebSocket URL for web platform (e.g. `wss://example.com:5443/ws`).
  /// Required on web, ignored on iOS/Android.
  final String? wsUrl;

  const XmppConnectionConfig({
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    required this.domain,
    this.useSSL = true,
    this.allowSelfSignedCertificates = false,
    this.resource,
    this.wsUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'host': host,
      'port': port,
      'username': username,
      'password': password,
      'domain': domain,
      'useSSL': useSSL,
      'allowSelfSignedCertificates': allowSelfSignedCertificates,
      'resource': resource,
      'wsUrl': wsUrl,
    };
  }

  factory XmppConnectionConfig.fromMap(Map<String, dynamic> map) {
    return XmppConnectionConfig(
      host: map['host'] ?? '',
      port: map['port'] ?? 5222,
      username: map['username'] ?? '',
      password: map['password'] ?? '',
      domain: map['domain'] ?? '',
      useSSL: map['useSSL'] ?? true,
      allowSelfSignedCertificates: map['allowSelfSignedCertificates'] ?? false,
      resource: map['resource'],
      wsUrl: map['wsUrl'],
    );
  }

  @override
  String toString() {
    return 'XmppConnectionConfig(host: $host, port: $port, username: $username, domain: $domain, useSSL: $useSSL, resource: $resource, wsUrl: $wsUrl)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is XmppConnectionConfig &&
        other.host == host &&
        other.port == port &&
        other.username == username &&
        other.password == password &&
        other.domain == domain &&
        other.useSSL == useSSL &&
        other.allowSelfSignedCertificates == allowSelfSignedCertificates &&
        other.resource == resource &&
        other.wsUrl == wsUrl;
  }

  @override
  int get hashCode {
    return Object.hash(
      host,
      port,
      username,
      password,
      domain,
      useSSL,
      allowSelfSignedCertificates,
      resource,
      wsUrl,
    );
  }
}
