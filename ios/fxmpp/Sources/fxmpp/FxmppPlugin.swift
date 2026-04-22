import Flutter
import UIKit
import XMPPFramework

public class FxmppPlugin: NSObject, FlutterPlugin {
    private var channel: FlutterMethodChannel?
    private var connectionStateEventChannel: FlutterEventChannel?
    private var messageEventChannel: FlutterEventChannel?
    private var presenceEventChannel: FlutterEventChannel?
    private var iqEventChannel: FlutterEventChannel?
    private var mucEventChannel: FlutterEventChannel?
    
    private var connectionStateStreamHandler: ConnectionStateStreamHandler?
    private var messageStreamHandler: MessageStreamHandler?
    private var presenceStreamHandler: PresenceStreamHandler?
    private var iqStreamHandler: IqStreamHandler?
    private var mucEventStreamHandler: MucEventStreamHandler?
    
    private var xmppStream: XMPPStream?
    private var xmppRoster: XMPPRoster?
    private var xmppReconnect: XMPPReconnect?
    private var xmppMUC: XMPPMUC?
    
    private var joinedRooms: [String: XMPPRoom] = [:]
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
        
        // MUC event channel
        mucEventChannel = FlutterEventChannel(name: "fxmpp/muc_events", binaryMessenger: registrar.messenger())
        mucEventStreamHandler = MucEventStreamHandler()
        mucEventChannel?.setStreamHandler(mucEventStreamHandler)
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
        // MUC methods
        case "joinMucRoom":
            handleJoinMucRoom(call: call, result: result)
        case "leaveMucRoom":
            handleLeaveMucRoom(call: call, result: result)
        case "createMucRoom":
            handleCreateMucRoom(call: call, result: result)
        case "sendMucMessage":
            handleSendMucMessage(call: call, result: result)
        case "sendMucPrivateMessage":
            handleSendMucPrivateMessage(call: call, result: result)
        case "kickMucParticipant":
            handleKickMucParticipant(call: call, result: result)
        case "banMucUser":
            handleBanMucUser(call: call, result: result)
        case "grantMucVoice":
            handleGrantMucVoice(call: call, result: result)
        case "revokeMucVoice":
            handleRevokeMucVoice(call: call, result: result)
        case "grantMucModerator":
            handleGrantMucModerator(call: call, result: result)
        case "grantMucMembership":
            handleGrantMucMembership(call: call, result: result)
        case "grantMucAdmin":
            handleGrantMucAdmin(call: call, result: result)
        case "inviteMucUser":
            handleInviteMucUser(call: call, result: result)
        case "destroyMucRoom":
            handleDestroyMucRoom(call: call, result: result)
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
        
        // Setup MUC
        xmppMUC = XMPPMUC()
        xmppMUC?.activate(xmppStream!)
        xmppMUC?.addDelegate(self, delegateQueue: DispatchQueue.main)
    }
    
    // MARK: - MUC Method Handlers
    
    private func handleJoinMucRoom(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let roomJid = args["roomJid"] as? String,
              let nickname = args["nickname"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing required arguments", details: nil))
            return
        }
        
        let password = args["password"] as? String
        
        DispatchQueue.global(qos: .background).async {
            do {
                guard let roomJidObj = XMPPJID(string: roomJid) else {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "INVALID_JID", message: "Invalid room JID", details: nil))
                    }
                    return
                }
                
                let room = XMPPRoom(roomStorage: XMPPRoomMemoryStorage(), jid: roomJidObj, dispatchQueue: DispatchQueue.main)
                room.activate(self.xmppStream!)
                room.addDelegate(self, delegateQueue: DispatchQueue.main)
                
                if let password = password {
                    try room.join(usingNickname: nickname, history: nil, password: password)
                } else {
                    try room.join(usingNickname: nickname, history: nil)
                }
                
                self.joinedRooms[roomJid] = room
                
                DispatchQueue.main.async {
                    result(true)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "JOIN_MUC_ERROR", message: error.localizedDescription, details: nil))
                }
            }
        }
    }
    
    private func handleLeaveMucRoom(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let roomJid = args["roomJid"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing roomJid", details: nil))
            return
        }
        
        DispatchQueue.global(qos: .background).async {
            guard let room = self.joinedRooms[roomJid] else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "ROOM_NOT_FOUND", message: "Room not joined", details: nil))
                }
                return
            }
            
            room.leave()
            room.deactivate()
            self.joinedRooms.removeValue(forKey: roomJid)
            
            DispatchQueue.main.async {
                result(true)
            }
        }
    }
    
    private func handleCreateMucRoom(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let roomJid = args["roomJid"] as? String,
              let nickname = args["nickname"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing required arguments", details: nil))
            return
        }
        
        let password = args["password"] as? String
        
        DispatchQueue.global(qos: .background).async {
            do {
                guard let roomJidObj = XMPPJID(string: roomJid) else {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "INVALID_JID", message: "Invalid room JID", details: nil))
                    }
                    return
                }
                
                let room = XMPPRoom(roomStorage: XMPPRoomMemoryStorage(), jid: roomJidObj, dispatchQueue: DispatchQueue.main)
                room.activate(self.xmppStream!)
                room.addDelegate(self, delegateQueue: DispatchQueue.main)
                
                if let password = password {
                    try room.join(usingNickname: nickname, history: nil, password: password)
                } else {
                    try room.join(usingNickname: nickname, history: nil)
                }
                
                self.joinedRooms[roomJid] = room
                
                DispatchQueue.main.async {
                    result(true)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "CREATE_MUC_ERROR", message: error.localizedDescription, details: nil))
                }
            }
        }
    }
    
    private func handleSendMucMessage(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let xmlString = args["xml"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing xml argument", details: nil))
            return
        }
        
        DispatchQueue.global(qos: .background).async {
            do {
                guard let xmlData = xmlString.data(using: .utf8),
                      let xmlDoc = try? XMLDocument(data: xmlData, options: 0),
                      let rootElement = xmlDoc.rootElement() else {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "XML_PARSE_ERROR", message: "Failed to parse XML", details: nil))
                    }
                    return
                }
                
                let xmppMessage = XMPPMessage(from: rootElement)
                self.xmppStream?.send(xmppMessage)
                
                DispatchQueue.main.async {
                    result(true)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "SEND_MUC_MESSAGE_ERROR", message: error.localizedDescription, details: nil))
                }
            }
        }
    }
    
    private func handleSendMucPrivateMessage(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let xmlString = args["xml"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing xml argument", details: nil))
            return
        }
        
        DispatchQueue.global(qos: .background).async {
            do {
                guard let xmlData = xmlString.data(using: .utf8),
                      let xmlDoc = try? XMLDocument(data: xmlData, options: 0),
                      let rootElement = xmlDoc.rootElement() else {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "XML_PARSE_ERROR", message: "Failed to parse XML", details: nil))
                    }
                    return
                }
                
                let xmppMessage = XMPPMessage(from: rootElement)
                self.xmppStream?.send(xmppMessage)
                
                DispatchQueue.main.async {
                    result(true)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "SEND_MUC_PRIVATE_MESSAGE_ERROR", message: error.localizedDescription, details: nil))
                }
            }
        }
    }
    
    private func handleKickMucParticipant(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let roomJid = args["roomJid"] as? String,
              let nickname = args["nickname"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing required arguments", details: nil))
            return
        }
        
        let reason = args["reason"] as? String
        
        DispatchQueue.global(qos: .background).async {
            guard let room = self.joinedRooms[roomJid] else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "ROOM_NOT_FOUND", message: "Room not joined", details: nil))
                }
                return
            }
            
            // XMPPFramework doesn't have direct kick method, send IQ manually
            let kickIQ = self.createKickIQ(roomJid: roomJid, nickname: nickname, reason: reason)
            self.xmppStream?.send(kickIQ)
            
            DispatchQueue.main.async {
                result(true)
            }
        }
    }
    
    private func handleBanMucUser(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let roomJid = args["roomJid"] as? String,
              let userJid = args["userJid"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing required arguments", details: nil))
            return
        }
        
        let reason = args["reason"] as? String
        
        DispatchQueue.global(qos: .background).async {
            guard let room = self.joinedRooms[roomJid] else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "ROOM_NOT_FOUND", message: "Room not joined", details: nil))
                }
                return
            }
            
            guard let jid = XMPPJID(string: userJid) else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "INVALID_JID", message: "Invalid user JID", details: nil))
                }
                return
            }
            
            // XMPPFramework doesn't have direct ban method, send IQ manually
            let banIQ = self.createBanIQ(roomJid: roomJid, userJid: userJid, reason: reason)
            self.xmppStream?.send(banIQ)
            
            DispatchQueue.main.async {
                result(true)
            }
        }
    }
    
    private func handleGrantMucVoice(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let roomJid = args["roomJid"] as? String,
              let nickname = args["nickname"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing required arguments", details: nil))
            return
        }
        
        DispatchQueue.global(qos: .background).async {
            guard let room = self.joinedRooms[roomJid] else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "ROOM_NOT_FOUND", message: "Room not joined", details: nil))
                }
                return
            }
            
            // XMPPFramework doesn't have direct grantVoice method, send IQ manually
            let voiceIQ = self.createGrantVoiceIQ(roomJid: roomJid, nickname: nickname)
            self.xmppStream?.send(voiceIQ)
            
            DispatchQueue.main.async {
                result(true)
            }
        }
    }
    
    private func handleRevokeMucVoice(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let roomJid = args["roomJid"] as? String,
              let nickname = args["nickname"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing required arguments", details: nil))
            return
        }
        
        DispatchQueue.global(qos: .background).async {
            guard let room = self.joinedRooms[roomJid] else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "ROOM_NOT_FOUND", message: "Room not joined", details: nil))
                }
                return
            }
            
            // XMPPFramework doesn't have direct revokeVoice method, send IQ manually
            let revokeVoiceIQ = self.createRevokeVoiceIQ(roomJid: roomJid, nickname: nickname)
            self.xmppStream?.send(revokeVoiceIQ)
            
            DispatchQueue.main.async {
                result(true)
            }
        }
    }
    
    private func handleGrantMucModerator(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let roomJid = args["roomJid"] as? String,
              let nickname = args["nickname"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing required arguments", details: nil))
            return
        }
        
        DispatchQueue.global(qos: .background).async {
            guard let room = self.joinedRooms[roomJid] else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "ROOM_NOT_FOUND", message: "Room not joined", details: nil))
                }
                return
            }
            
            // XMPPFramework doesn't have direct grantModerator method, send IQ manually
            let moderatorIQ = self.createGrantModeratorIQ(roomJid: roomJid, nickname: nickname)
            self.xmppStream?.send(moderatorIQ)
            
            DispatchQueue.main.async {
                result(true)
            }
        }
    }
    
    private func handleGrantMucMembership(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let roomJid = args["roomJid"] as? String,
              let userJid = args["userJid"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing required arguments", details: nil))
            return
        }
        
        DispatchQueue.global(qos: .background).async {
            guard let room = self.joinedRooms[roomJid] else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "ROOM_NOT_FOUND", message: "Room not joined", details: nil))
                }
                return
            }
            
            guard let jid = XMPPJID(string: userJid) else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "INVALID_JID", message: "Invalid user JID", details: nil))
                }
                return
            }
            
            // XMPPFramework doesn't have direct grantMembership method, send IQ manually
            let membershipIQ = self.createGrantMembershipIQ(roomJid: roomJid, userJid: userJid)
            self.xmppStream?.send(membershipIQ)
            
            DispatchQueue.main.async {
                result(true)
            }
        }
    }
    
    private func handleGrantMucAdmin(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let roomJid = args["roomJid"] as? String,
              let userJid = args["userJid"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing required arguments", details: nil))
            return
        }
        
        DispatchQueue.global(qos: .background).async {
            guard let room = self.joinedRooms[roomJid] else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "ROOM_NOT_FOUND", message: "Room not joined", details: nil))
                }
                return
            }
            
            guard let jid = XMPPJID(string: userJid) else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "INVALID_JID", message: "Invalid user JID", details: nil))
                }
                return
            }
            
            // XMPPFramework doesn't have direct grantAdmin method, send IQ manually
            let adminIQ = self.createGrantAdminIQ(roomJid: roomJid, userJid: userJid)
            self.xmppStream?.send(adminIQ)
            
            DispatchQueue.main.async {
                result(true)
            }
        }
    }
    
    private func handleInviteMucUser(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let roomJid = args["roomJid"] as? String,
              let userJid = args["userJid"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing required arguments", details: nil))
            return
        }
        
        let reason = args["reason"] as? String ?? ""
        
        DispatchQueue.global(qos: .background).async {
            guard let room = self.joinedRooms[roomJid] else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "ROOM_NOT_FOUND", message: "Room not joined", details: nil))
                }
                return
            }
            
            guard let jid = XMPPJID(string: userJid) else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "INVALID_JID", message: "Invalid user JID", details: nil))
                }
                return
            }
            
            room.inviteUser(jid, withMessage: reason)
            
            DispatchQueue.main.async {
                result(true)
            }
        }
    }
    
    private func handleDestroyMucRoom(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let roomJid = args["roomJid"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing roomJid", details: nil))
            return
        }
        
        let reason = args["reason"] as? String
        let alternativeRoom = args["alternativeRoom"] as? String
        
        DispatchQueue.global(qos: .background).async {
            guard let room = self.joinedRooms[roomJid] else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "ROOM_NOT_FOUND", message: "Room not joined", details: nil))
                }
                return
            }
            
            var alternativeJid: XMPPJID? = nil
            if let altRoom = alternativeRoom {
                alternativeJid = XMPPJID(string: altRoom)
            }
            
            // XMPPFramework doesn't have direct destroyRoom method, send IQ manually
            let destroyIQ = self.createDestroyRoomIQ(roomJid: roomJid, alternativeRoom: alternativeRoom, reason: reason)
            self.xmppStream?.send(destroyIQ)
            self.joinedRooms.removeValue(forKey: roomJid)
            
            DispatchQueue.main.async {
                result(true)
            }
        }
    }
    
    // MARK: - Helper Methods for MUC IQ Creation
    
    private func createKickIQ(roomJid: String, nickname: String, reason: String?) -> XMPPIQ {
        let iq = XMPPIQ(type: "set", to: XMPPJID(string: roomJid))
        let query = DDXMLElement(name: "query", xmlns: "http://jabber.org/protocol/muc#admin")
        let item = DDXMLElement(name: "item")
        item.addAttribute(withName: "nick", stringValue: nickname)
        item.addAttribute(withName: "role", stringValue: "none")
        if let reason = reason {
            let reasonElement = DDXMLElement(name: "reason", stringValue: reason)
            item.addChild(reasonElement)
        }
        query.addChild(item)
        iq.addChild(query)
        return iq
    }
    
    private func createBanIQ(roomJid: String, userJid: String, reason: String?) -> XMPPIQ {
        let iq = XMPPIQ(type: "set", to: XMPPJID(string: roomJid))
        let query = DDXMLElement(name: "query", xmlns: "http://jabber.org/protocol/muc#admin")
        let item = DDXMLElement(name: "item")
        item.addAttribute(withName: "jid", stringValue: userJid)
        item.addAttribute(withName: "affiliation", stringValue: "outcast")
        if let reason = reason {
            let reasonElement = DDXMLElement(name: "reason", stringValue: reason)
            item.addChild(reasonElement)
        }
        query.addChild(item)
        iq.addChild(query)
        return iq
    }
    
    private func createGrantVoiceIQ(roomJid: String, nickname: String) -> XMPPIQ {
        let iq = XMPPIQ(type: "set", to: XMPPJID(string: roomJid))
        let query = DDXMLElement(name: "query", xmlns: "http://jabber.org/protocol/muc#admin")
        let item = DDXMLElement(name: "item")
        item.addAttribute(withName: "nick", stringValue: nickname)
        item.addAttribute(withName: "role", stringValue: "participant")
        query.addChild(item)
        iq.addChild(query)
        return iq
    }
    
    private func createRevokeVoiceIQ(roomJid: String, nickname: String) -> XMPPIQ {
        let iq = XMPPIQ(type: "set", to: XMPPJID(string: roomJid))
        let query = DDXMLElement(name: "query", xmlns: "http://jabber.org/protocol/muc#admin")
        let item = DDXMLElement(name: "item")
        item.addAttribute(withName: "nick", stringValue: nickname)
        item.addAttribute(withName: "role", stringValue: "visitor")
        query.addChild(item)
        iq.addChild(query)
        return iq
    }
    
    private func createGrantModeratorIQ(roomJid: String, nickname: String) -> XMPPIQ {
        let iq = XMPPIQ(type: "set", to: XMPPJID(string: roomJid))
        let query = DDXMLElement(name: "query", xmlns: "http://jabber.org/protocol/muc#admin")
        let item = DDXMLElement(name: "item")
        item.addAttribute(withName: "nick", stringValue: nickname)
        item.addAttribute(withName: "role", stringValue: "moderator")
        query.addChild(item)
        iq.addChild(query)
        return iq
    }
    
    private func createGrantMembershipIQ(roomJid: String, userJid: String) -> XMPPIQ {
        let iq = XMPPIQ(type: "set", to: XMPPJID(string: roomJid))
        let query = DDXMLElement(name: "query", xmlns: "http://jabber.org/protocol/muc#admin")
        let item = DDXMLElement(name: "item")
        item.addAttribute(withName: "jid", stringValue: userJid)
        item.addAttribute(withName: "affiliation", stringValue: "member")
        query.addChild(item)
        iq.addChild(query)
        return iq
    }
    
    private func createGrantAdminIQ(roomJid: String, userJid: String) -> XMPPIQ {
        let iq = XMPPIQ(type: "set", to: XMPPJID(string: roomJid))
        let query = DDXMLElement(name: "query", xmlns: "http://jabber.org/protocol/muc#admin")
        let item = DDXMLElement(name: "item")
        item.addAttribute(withName: "jid", stringValue: userJid)
        item.addAttribute(withName: "affiliation", stringValue: "admin")
        query.addChild(item)
        iq.addChild(query)
        return iq
    }
    
    private func createDestroyRoomIQ(roomJid: String, alternativeRoom: String?, reason: String?) -> XMPPIQ {
        let iq = XMPPIQ(type: "set", to: XMPPJID(string: roomJid))
        let query = DDXMLElement(name: "query", xmlns: "http://jabber.org/protocol/muc#owner")
        let destroy = DDXMLElement(name: "destroy")
        if let altRoom = alternativeRoom {
            destroy.addAttribute(withName: "jid", stringValue: altRoom)
        }
        if let reason = reason {
            let reasonElement = DDXMLElement(name: "reason", stringValue: reason)
            destroy.addChild(reasonElement)
        }
        query.addChild(destroy)
        iq.addChild(query)
        return iq
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

// MARK: - XMPPMUCDelegate
extension FxmppPlugin: XMPPMUCDelegate {
    // Implement MUC delegate methods as needed
}

// MARK: - XMPPRoomDelegate
extension FxmppPlugin: XMPPRoomDelegate {
    public func xmppRoomDidJoin(_ sender: XMPPRoom) {
        let event: [String: Any] = [
            "type": "room_joined",
            "roomJid": sender.roomJID.bare
        ]
        mucEventStreamHandler?.sendEvent(event)
    }
    
    public func xmppRoomDidLeave(_ sender: XMPPRoom) {
        let event: [String: Any] = [
            "type": "room_left",
            "roomJid": sender.roomJID.bare
        ]
        mucEventStreamHandler?.sendEvent(event)
    }
    
    public func xmppRoom(_ sender: XMPPRoom, didReceiveMessage message: XMPPMessage) {
        let event: [String: Any] = [
            "type": "muc_message",
            "roomJid": sender.roomJID.bare,
            "from": message.from?.full ?? "",
            "body": message.body ?? "",
            "messageType": message.type ?? "groupchat"
        ]
        mucEventStreamHandler?.sendEvent(event)
    }
    
    public func xmppRoom(_ sender: XMPPRoom, occupantDidJoin occupantJID: XMPPJID) {
        let event: [String: Any] = [
            "type": "participant_joined",
            "roomJid": sender.roomJID.bare,
            "participant": occupantJID.full
        ]
        mucEventStreamHandler?.sendEvent(event)
    }
    
    public func xmppRoom(_ sender: XMPPRoom, occupantDidLeave occupantJID: XMPPJID) {
        let event: [String: Any] = [
            "type": "participant_left",
            "roomJid": sender.roomJID.bare,
            "participant": occupantJID.full
        ]
        mucEventStreamHandler?.sendEvent(event)
    }
    
    public func xmppRoom(_ sender: XMPPRoom, occupantDidUpdate occupantJID: XMPPJID, with presence: XMPPPresence) {
        let event: [String: Any] = [
            "type": "participant_updated",
            "roomJid": sender.roomJID.bare,
            "participant": occupantJID.full,
            "presence": presence.xmlString
        ]
        mucEventStreamHandler?.sendEvent(event)
    }
    
    public func xmppRoom(_ sender: XMPPRoom, didReceiveInvitation message: XMPPMessage) {
        let event: [String: Any] = [
            "type": "room_invitation",
            "roomJid": sender.roomJID.bare,
            "from": message.from?.full ?? "",
            "reason": message.body ?? ""
        ]
        mucEventStreamHandler?.sendEvent(event)
    }
    
    public func xmppRoom(_ sender: XMPPRoom, didReceiveInvitationDecline message: XMPPMessage) {
        let event: [String: Any] = [
            "type": "invitation_declined",
            "roomJid": sender.roomJID.bare,
            "from": message.from?.full ?? "",
            "reason": message.body ?? ""
        ]
        mucEventStreamHandler?.sendEvent(event)
    }
    
    public func xmppRoomDidCreate(_ sender: XMPPRoom) {
        let event: [String: Any] = [
            "type": "room_created",
            "roomJid": sender.roomJID.bare
        ]
        mucEventStreamHandler?.sendEvent(event)
    }
    
    public func xmppRoomDidDestroy(_ sender: XMPPRoom) {
        let event: [String: Any] = [
            "type": "room_destroyed",
            "roomJid": sender.roomJID.bare
        ]
        mucEventStreamHandler?.sendEvent(event)
    }
    
    public func xmppRoom(_ sender: XMPPRoom, didChangeSubject subject: String?) {
        let event: [String: Any] = [
            "type": "subject_changed",
            "roomJid": sender.roomJID.bare,
            "subject": subject ?? ""
        ]
        mucEventStreamHandler?.sendEvent(event)
    }
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

class MucEventStreamHandler: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
    
    func sendEvent(_ event: [String: Any]) {
        eventSink?(event)
    }
}
