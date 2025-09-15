# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0-alpha] - 2025-01-15

### Added
- **IQ Stanza Support**: Complete implementation of XMPP IQ (Info/Query) stanzas
  - Send and receive IQ stanzas with proper XML handling
  - Support for get, set, result, and error IQ types
  - Cross-platform implementation for both iOS and Android
- **Enhanced Example App**: New IQ tab with multiple IQ examples
  - Version IQ (`jabber:iq:version`)
  - Time IQ (`urn:xmpp:time`) with proper XML structure
  - Disco Info IQ (`http://jabber.org/protocol/disco#info`)
  - Ping IQ (`urn:xmpp:ping`)
  - Resource Bind IQ (`urn:ietf:params:xml:ns:xmpp-bind`)
  - Roster IQ (`jabber:iq:roster`) for contact list retrieval
- **Improved Debugging**: Enhanced logging for troubleshooting IQ communication
- **Platform-Specific Fixes**: 
  - iOS: Proper XMPPFramework delegate implementation for IQ handling
  - Android: Fixed XML parsing and stream handler consistency

### Fixed
- **XML Malformation**: Fixed Time IQ XML structure causing connection drops
- **Stream Handler Consistency**: Unified XML string handling across all stanza types
- **iOS IQ Reception**: Added missing IqStreamHandler class for iOS platform
- **Connection Stability**: Resolved XML parsing errors that caused XMPP disconnections

### Technical Improvements
- Stream-based IQ architecture matching message and presence patterns
- Proper XML namespace handling for different IQ types
- Enhanced error handling and debugging capabilities
- Cross-platform compatibility improvements

## [0.1.0] - 2024-12-09

### Added
- Initial release of FXMPP Flutter plugin
- Cross-platform XMPP support for iOS and Android
- Real-time messaging capabilities
- Presence management system
- Connection state monitoring with detailed states
- SSL/TLS encryption support
- Stream-based architecture for real-time updates
- Comprehensive example application
- iOS implementation using XMPPFramework
- Android implementation using Smack library
- Support for various message types (chat, groupchat, headline, normal, error)
- Support for presence types (available, unavailable, subscribe, etc.)
- Configurable connection parameters
- Self-signed certificate support for testing
- Resource management and cleanup
- Complete API documentation
- MIT License

### Features
- **Connection Management**: Connect/disconnect to XMPP servers with full configuration options
- **Real-time Messaging**: Send and receive messages with timestamp and type information
- **Presence System**: Send and receive presence updates with show states and status messages
- **Stream Architecture**: Event-driven architecture using Dart streams for real-time updates
- **Security**: SSL/TLS support with optional self-signed certificate handling
- **Cross-platform**: Native implementations for both iOS (XMPPFramework) and Android (Smack)
- **Example App**: Complete example application demonstrating all features

### Platform Support
- iOS 11.0+
- Android API 16+
- Flutter 3.3.0+
- Dart 3.0.0+
