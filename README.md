# FXMPP

A Flutter plugin for XMPP (Extensible Messaging and Presence Protocol) communication, supporting both iOS and Android platforms with real-time messaging capabilities.

![mobile](./example/assets/mobile_clients.png)

## Features

- ✅ Minimal dependencies (xml(Dart), [Smack](https://github.com/igniterealtime/Smack) for Android, [XMPPFramework](https://github.com/robbiehanson/XMPPFramework) for iOS)
- ✅ Pure XMPP interpreter.
- ✅ Easy to customize.
- ✅ Stream-based architecture

### Built-in Stanza Builders

- Core XMPP Stanzas(IQ, Message, Presence).
- [XEP-0012 Last Activity](https://xmpp.org/extensions/xep-0012.html)
- [XEP-0085 Chat State Notifications](https://xmpp.org/extensions/xep-0085.html)
- [XEP-0184 Message Delivery Receipts](https://xmpp.org/extensions/xep-0184.html)
- [XEP-0313 Message Archive Management](https://xmpp.org/extensions/xep-0313.html)

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  fxmpp: ^1.0.0
```

Then run:

```bash
flutter pub get
```

## Usage

### Basic Setup

```dart
import 'package:fxmpp/fxmpp.dart';

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final Fxmpp _fxmpp = Fxmpp();

  @override
  void initState() {
    super.initState();
    _initializeXMPP();
  }

  Future<void> _initializeXMPP() async {
    await _fxmpp.initialize();
    
    // Listen to connection state changes
    _fxmpp.connectionStateStream.listen((state) {
      print('Connection state: ${state.description}');
    });
    
    // Listen to incoming messages
    _fxmpp.messageStream.listen((message) {
      print('Received message: ${message.body}');
    });
    
    // Listen to presence updates
    _fxmpp.presenceStream.listen((presence) {
      print('Presence update: ${presence.from} is ${presence.show.name}');
    });
    
    // Listen to IQ stanzas
    _fxmpp.iqStream.listen((iq) {
      print('Received IQ: ${iq.toXmlString()}');
    });
  }

  @override
  void dispose() {
    _fxmpp.dispose();
    super.dispose();
  }
}
```

### Connecting to XMPP Server

```dart
final config = XmppConnectionConfig(
  host: 'your-xmpp-server.com',
  port: 5222,
  username: 'your-username',
  password: 'your-password',
  domain: 'your-domain.com',
  useSSL: true,
  resource: 'your-app-name',
);

try {
  final success = await _fxmpp.connect(config);
  if (success) {
    print('Connected successfully');
  }
} catch (e) {
  print('Connection failed: $e');
}
```

### Sending Messages
#### Using built-in message builder
```dart
final message = XmppMessage(
  id: DateTime.now().millisecondsSinceEpoch.toString(),
  from: 'sender@domain.com',
  to: 'recipient@domain.com',
  body: 'Hello, World!',
  timestamp: DateTime.now(),
  type: XmppMessageType.chat,
);

final success = await _fxmpp.sendMessage(message);
if (success) {
  print('Message sent successfully');
}
```
#### Using XML builder
```dart
import 'package:xml/xml.dart';

final builder = XmlBuilder();
builder.element('message', nest: () {
   builder.attribute('type', 'chat');
   builder.attribute('to', 'recipient@domain.com');
   builder.attribute('id', 'message_${DateTime.now().millisecondsSinceEpoch}');
   builder.element('body', nest: 'content');
};

await _fxmpp.sendMessage(builder.buildDocument());
```

### Sending IQ Stanzas

```dart
import 'package:xml/xml.dart';

// Create a ping IQ
final builder = XmlBuilder();
builder.element('iq', nest: () {
  builder.attribute('type', 'get');
  builder.attribute('to', 'server.example.com');
  builder.attribute('id', 'ping_${DateTime.now().millisecondsSinceEpoch}');
  builder.element('ping', nest: () {
    builder.attribute('xmlns', 'urn:xmpp:ping');
  });
});
final iq = builder.buildDocument();

final success = await _fxmpp.sendIq(iq);
if (success) {
  print('IQ sent successfully');
}
```

### Managing Presence

```dart
final presence = XmppPresence(
  from: 'user@domain.com',
  show: XmppPresenceShow.online,
  status: 'Available',
  timestamp: DateTime.now(),
);

final success = await _fxmpp.sendPresence(presence);
if (success) {
  print('Presence updated');
}
```

### Disconnecting

```dart
await _fxmpp.disconnect();
```

## Example App

The package includes a comprehensive example app that demonstrates all features. To run the example:

```bash
cd example
flutter run
```

The example app includes:
- Connection management UI
- Real-time messaging interface
- Presence management controls
- IQ stanza examples (Ping, Version, Time, Disco Info, Roster)
- Connection state monitoring

## Platform-Specific Setup

### iOS

The iOS implementation uses XMPPFramework. No additional setup is required as the framework is automatically included via CocoaPods.

### Android

The Android implementation uses the Smack library. The required dependencies are automatically included in the plugin.

Required permissions are automatically added to your app's `AndroidManifest.xml`:
- `INTERNET` - For network communication
- `ACCESS_NETWORK_STATE` - For network state monitoring

## Security Considerations

- Always use SSL/TLS in production (`useSSL: true`)
- Avoid using `allowSelfSignedCertificates: true` in production
- Store credentials securely (consider using flutter_secure_storage)
- Validate all incoming messages and presence updates

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For issues and questions, please use the [GitHub Issues](https://github.com/haithngn/fxmpp/issues) page.

## Changelog
### 1.0.0
- Core XMPP Features.
- MUC.
- Stanza Builders: IQ, Message, Presence, XEP-0012, XEP-0085, XEP-0184, XEP-0313.

### 1.0.0-alpha.2
- **BREAKING**: Support MUC.

### 1.0.0-alpha
- Added IQ (Info/Query) stanza support
- Enhanced example app with IQ examples
- Fixed XML parsing issues
- Improved cross-platform compatibility
- Added comprehensive IQ documentation

### 0.1.0
- Initial release
- Cross-platform XMPP support
- Real-time messaging
- Presence management
- Connection state monitoring
- SSL/TLS support
- Comprehensive example app
