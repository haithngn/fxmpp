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

  const XmppConnectionConfig({
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    required this.domain,
    this.useSSL = true,
    this.allowSelfSignedCertificates = false,
    this.resource,
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
    );
  }

  @override
  String toString() {
    return 'XmppConnectionConfig(host: $host, port: $port, username: $username, domain: $domain, useSSL: $useSSL, resource: $resource)';
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
        other.resource == resource;
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
    );
  }
}
