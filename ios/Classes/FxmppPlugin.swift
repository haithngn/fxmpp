import Flutter
import UIKit
import XMPPFramework

public class FxmppPlugin: NSObject, FlutterPlugin {
    private var channel: FlutterMethodChannel?
    private var connectionStateEventChannel: FlutterEventChannel?
    private var messageEventChannel: FlutterEventChannel?
    private var presenceEventChannel: FlutterEventChannel?
    private var iqEventChannel: FlutterEventChannel?
    
    private var connectionStateStreamHandler: ConnectionStateStreamHandler?
    private var messageStreamHandler: MessageStreamHandler?
    private var presenceStreamHandler: PresenceStreamHandler?
    private var iqStreamHandler: IqStreamHandler?
    
    private var xmppStream: XMPPStream?
    private var xmppRoster: XMPPRoster?
    private var xmppReconnect: XMPPReconnect?
    
    private var isConnected = false
    private var password: String?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "fxmpp", binaryMessenger: registrar.messenger())
        let instance = FxmppPlugin()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
        
        // Set up event channels
        instance.setupEventChannels(registrar: registrar)
    }
    
    private func setupEventChannels(registrar: FlutterPluginRegistrar) {
        // Connection state event channel
        connectionStateEventChannel = FlutterEventChannel(name: "fxmpp/connection_state", binaryMessenger: registrar.messenger())
        connectionStateStreamHandler = ConnectionStateStreamHandler()
        connectionStateEventChannel?.setStreamHandler(connectionStateStreamHandler)
        
        // Message event channel
        messageEventChannel = FlutterEventChannel(name: "fxmpp/messages", binaryMessenger: registrar.messenger())
        messageStreamHandler = MessageStreamHandler()
        messageEventChannel?.setStreamHandler(messageStreamHandler)
        
        // Presence event channel
        presenceEventChannel = FlutterEventChannel(name: "fxmpp/presence", binaryMessenger: registrar.messenger())
        presenceStreamHandler = PresenceStreamHandler()
        presenceEventChannel?.setStreamHandler(presenceStreamHandler)
        
        // IQ event channel
        iqEventChannel = FlutterEventChannel(name: "fxmpp/iq", binaryMessenger: registrar.messenger())
        iqStreamHandler = IqStreamHandler()
        iqEventChannel?.setStreamHandler(iqStreamHandler)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "connect":
            handleConnect(call: call, result: result)
        case "disconnect":
            handleDisconnect(result: result)
        case "sendMessage":
            handleSendMessage(call: call, result: result)
        case "sendPresence":
            handleSendPresence(call: call, result: result)
        case "sendIq":
            handleSendIq(call: call, result: result)
        case "getConnectionState":
            handleGetConnectionState(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func handleConnect(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
            return
        }
        
        let host = args["host"] as? String ?? ""
        let port = args["port"] as? Int ?? 5222
        let username = args["username"] as? String ?? ""
        let password = args["password"] as? String ?? ""
        let domain = args["domain"] as? String ?? ""
        let useSSL = args["useSSL"] as? Bool ?? true
        let resource = args["resource"] as? String ?? "fxmpp"
        
        self.password = password
        
        // Disconnect existing connection if any
        if xmppStream?.isConnected == true {
            xmppStream?.disconnect()
        }
        
        setupXMPPStream()
        
        xmppStream?.hostName = host
        xmppStream?.hostPort = UInt16(port)
        
        guard let jid = XMPPJID(string: "\(username)@\(domain)/\(resource)") else {
            result(FlutterError(code: "INVALID_JID", message: "Invalid JID format", details: nil))
            return
        }
        
        xmppStream?.myJID = jid
        
        // Configure SSL/TLS
        if useSSL {
            xmppStream?.startTLSPolicy = .required
        } else {
            xmppStream?.startTLSPolicy = .allowed
        }
        
        do {
            connectionStateStreamHandler?.sendConnectionState(1) // connecting
            try xmppStream?.connect(withTimeout: 30.0) // 30 second timeout
            result(true)
        } catch let error {
            debugPrint("Connection error: \(error.localizedDescription)")
            connectionStateStreamHandler?.sendConnectionState(4) // error
            result(FlutterError(code: "CONNECTION_ERROR", message: error.localizedDescription, details: nil))
        }
    }
    
    private func handleDisconnect(result: @escaping FlutterResult) {
        xmppStream?.disconnect()
        connectionStateStreamHandler?.sendConnectionState(0) // disconnected
        result(nil)
    }
    
    private func handleSendMessage(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let xmlString = args["xml"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing XML content", details: nil))
            return
        }
        
        do {
            let xmlElement = try DDXMLElement(xmlString: xmlString)
            xmppStream?.send(xmlElement)
            result(true)
        } catch {
            result(FlutterError(code: "XML_PARSE_ERROR", message: "Failed to parse XML: \(error.localizedDescription)", details: nil))
        }
    }
    
    private func handleSendPresence(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let xmlString = args["xml"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing XML content", details: nil))
            return
        }
        
        do {
            let xmlElement = try DDXMLElement(xmlString: xmlString)
            xmppStream?.send(xmlElement)
            result(true)
        } catch {
            result(FlutterError(code: "XML_PARSE_ERROR", message: "Failed to parse XML: \(error.localizedDescription)", details: nil))
        }
    }
    
    private func handleSendIq(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let xmlString = args["xml"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing XML content", details: nil))
            return
        }
        
        do {
            let xmlElement = try DDXMLElement(xmlString: xmlString)
            xmppStream?.send(xmlElement)
            debugPrint("send xmlElement \(xmlElement)")
            result(true)
        } catch {
            result(FlutterError(code: "XML_PARSE_ERROR", message: "Failed to parse XML: \(error.localizedDescription)", details: nil))
        }
    }
    
    private func handleGetConnectionState(result: @escaping FlutterResult) {
        if isConnected {
            result(2) // connected
        } else if xmppStream?.isConnecting == true {
            result(1) // connecting
        } else {
            result(0) // disconnected
        }
    }
    
    private func setupXMPPStream() {
        xmppStream = XMPPStream()
        xmppStream?.addDelegate(self, delegateQueue: DispatchQueue.main)
        
        xmppStream?.enableBackgroundingOnSocket = true
        
        xmppRoster = XMPPRoster(rosterStorage: XMPPRosterCoreDataStorage.sharedInstance())
        xmppRoster?.activate(xmppStream!)
        xmppRoster?.addDelegate(self, delegateQueue: DispatchQueue.main)
        
        xmppReconnect = XMPPReconnect()
        xmppReconnect?.activate(xmppStream!)
    }
}

// MARK: - XMPPStreamDelegate
extension FxmppPlugin: XMPPStreamDelegate {
    public func xmppStream(_ sender: XMPPStream, didReceive trust: SecTrust, completionHandler: @escaping (Bool) -> Void) {
        completionHandler(true)
    }
    
    public func xmppStream(_ sender: XMPPStream, willSecureWithSettings settings: NSMutableDictionary) {
        settings.setValue(true, forKey: GCDAsyncSocketManuallyEvaluateTrust)
    }
    
    public func xmppStreamDidConnect(_ sender: XMPPStream) {
        do {
            try xmppStream?.authenticate(withPassword: password ?? "")
        } catch let error {
            debugPrint("Authentication error: \(error.localizedDescription)")
            connectionStateStreamHandler?.sendConnectionState(4) // error
        }
    }
    
    public func xmppStreamDidAuthenticate(_ sender: XMPPStream) {
        isConnected = true
        connectionStateStreamHandler?.sendConnectionState(2) // connected
        
        // Send initial presence
        let presence = XMPPPresence()
        xmppStream?.send(presence)
    }
    
    public func xmppStream(_ sender: XMPPStream, didNotAuthenticate error: DDXMLElement) {
        debugPrint("XMPP stream authentication failed: \(error)")
        connectionStateStreamHandler?.sendConnectionState(5) // authentication failed
    }
    
    public func xmppStreamDidDisconnect(_ sender: XMPPStream, withError error: Error?) {
        debugPrint("XMPP stream disconnected with error: \(error?.localizedDescription ?? "No error")")
        isConnected = false
        if let error = error {
            debugPrint("Disconnect error details: \(error)")
            connectionStateStreamHandler?.sendConnectionState(6) // connection lost
        } else {
            connectionStateStreamHandler?.sendConnectionState(0) // disconnected
        }
    }
    
    public func xmppStream(_ sender: XMPPStream, didReceive message: XMPPMessage) {
        let xmlString = message.xmlString
        messageStreamHandler?.sendMessage(xmlString)
    }
    
    public func xmppStream(_ sender: XMPPStream, didReceive presence: XMPPPresence) {
        let xmlString = presence.xmlString
        presenceStreamHandler?.sendPresence(xmlString)
    }
        
    // Additional XMPPFramework delegate methods for comprehensive IQ handling
    public func xmppStream(_ sender: XMPPStream, didFailToSend iq: XMPPIQ, error: any Error) {
        debugPrint("iOS FXMPP: Failed to send IQ: \(iq.xmlString), error: \(error.localizedDescription)")
    }
    
    public func xmppStream(_ sender: XMPPStream, willSend iq: XMPPIQ) -> XMPPIQ? {
        return iq
    }
    
    public func xmppStream(_ sender: XMPPStream, didReceive iq: XMPPIQ) -> Bool {
        let xmlString = iq.xmlString
        iqStreamHandler?.sendIq(xmlString)
        
        return true
    }
}

// MARK: - XMPPRosterDelegate
extension FxmppPlugin: XMPPRosterDelegate {
    // Implement roster delegate methods as needed
}

// MARK: - Stream Handlers
class ConnectionStateStreamHandler: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events

        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil

        return nil
    }
    
    func sendConnectionState(_ state: Int) {
        eventSink?(state)
    }
}

class MessageStreamHandler: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        
        return nil
    }
    
    func sendMessage(_ xmlString: String) {
        eventSink?(xmlString)
    }
}

class PresenceStreamHandler: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
    
    func sendPresence(_ xmlString: String) {
        eventSink?(xmlString)
    }
}

class IqStreamHandler: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
    
    func sendIq(_ xmlString: String) {
        eventSink?(xmlString)
    }
}
