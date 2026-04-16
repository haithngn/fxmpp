# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

fxmpp is a Flutter plugin providing XMPP (Extensible Messaging and Presence Protocol) communication for iOS and Android. It is a fork of [haithngn/fxmpp](https://github.com/haithngn/fxmpp). The plugin exposes a stream-based Dart API that bridges to native XMPP libraries via Flutter's platform channel mechanism.

## Build & Development Commands

```bash
# Get dependencies
flutter pub get

# Run the example app
cd example && flutter run

# Analyze Dart code
flutter analyze

# Run tests (no test directory currently exists)
flutter test
```

iOS native dependencies are managed via CocoaPods (`ios/fxmpp.podspec`). Android dependencies are in `android/build.gradle`. Neither requires manual setup beyond `flutter pub get`.

## Architecture

### Three-layer platform channel design

1. **Dart API layer** (`lib/src/fxmpp.dart`) — `Fxmpp` singleton exposing streams and async methods. This is the public interface consumers use. It also contains static stanza builder methods (`createMessage`, `createPresence`, `createIq`, `createMucMessage`, etc.).

2. **Platform interface** (`lib/src/fxmpp_platform_interface.dart`) — Abstract contract using `plugin_platform_interface`. Defines every method the native side must implement.

3. **Method channel implementation** (`lib/src/fxmpp_method_channel.dart`) — Bridges Dart to native via:
   - `MethodChannel('fxmpp')` for request/response calls (connect, send, MUC operations)
   - `EventChannel`s for streamed data from native: `fxmpp/connection_state`, `fxmpp/messages`, `fxmpp/presence`, `fxmpp/iq`, `fxmpp/muc_events`

### Native implementations

- **Android** (`android/.../FxmppPlugin.kt`) — Uses [Smack](https://github.com/igniterealtime/Smack) library. Networking runs on background `Thread`s, results posted to main via `Handler(Looper.getMainLooper())`. Stanzas are sent by parsing XML strings with `PacketParserUtils.parseStanza()`.

- **iOS** (`ios/Classes/FxmppPlugin.swift`) — Uses [XMPPFramework](https://github.com/robbiehanson/XMPPFramework) (CocoaPods, ~> 4.0). Stanzas are sent by parsing XML strings into `DDXMLElement`. MUC admin operations (kick, ban, grant roles) are implemented as manually-constructed IQ stanzas since XMPPFramework lacks direct methods for them.

### Key design pattern: XML-centric stanza passing

All stanzas (messages, presence, IQ) are serialized to XML strings on the Dart side, passed through the method channel as `{'xml': xmlString}`, and parsed back to native stanza objects. Incoming stanzas follow the reverse path. The `xml` Dart package is re-exported from the library for consumers.

### Connection state mapping

Native platforms emit integer state codes through the `fxmpp/connection_state` EventChannel, mapped to `XmppConnectionState` enum indices: 0=disconnected, 1=connecting, 2=connected, 4=error, 5=authenticationFailed, 6=connectionLost.

### XEP extensions (`lib/src/extensions/`)

Static utility classes that build XmlDocument stanzas for specific XMPP extensions. Each file is a self-contained stanza builder (no state, no side effects):
- XEP-0012 (Last Activity), XEP-0085 (Chat State), XEP-0184 (Delivery Receipts), XEP-0313 (MAM), XEP-0424 (Message Retraction)

### MUC (Multi-User Chat)

`MucManager` (`lib/src/muc_manager.dart`) maintains local room/participant state and builds MUC-specific stanzas. The `Fxmpp` class delegates MUC operations to both `MucManager` (for stanza building) and `FxmppPlatform` (for native execution). MUC events from native flow through the `fxmpp/muc_events` EventChannel.
