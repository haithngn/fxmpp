package dev.hainguyen.fxmpp

import android.os.Handler
import android.os.Looper
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import org.jivesoftware.smack.AbstractXMPPConnection
import org.jivesoftware.smack.ConnectionConfiguration
import org.jivesoftware.smack.ConnectionListener
import org.jivesoftware.smack.SmackException
import org.jivesoftware.smack.StanzaListener
import org.jivesoftware.smack.XMPPConnection
import org.jivesoftware.smack.XMPPException
import org.jivesoftware.smack.util.PacketParserUtils
import org.jivesoftware.smack.chat2.Chat
import org.jivesoftware.smack.chat2.ChatManager
import org.jivesoftware.smack.chat2.IncomingChatMessageListener
import org.jivesoftware.smack.filter.StanzaTypeFilter
import org.jivesoftware.smack.packet.IQ
import org.jivesoftware.smack.packet.Message
import org.jivesoftware.smack.packet.Presence
import org.jivesoftware.smack.packet.Stanza
import org.jivesoftware.smack.roster.Roster
import org.jivesoftware.smack.tcp.XMPPTCPConnection
import org.jivesoftware.smack.tcp.XMPPTCPConnectionConfiguration
import org.jxmpp.jid.impl.JidCreate
import java.io.IOException
import java.security.cert.X509Certificate
import javax.net.ssl.X509TrustManager
import java.util.*
import org.jivesoftware.smackx.muc.MultiUserChat
import org.jivesoftware.smackx.muc.MultiUserChatManager
import org.jivesoftware.smackx.muc.MucEnterConfiguration
import org.jivesoftware.smackx.muc.ParticipantStatusListener
import org.jivesoftware.smackx.muc.SubjectUpdatedListener
import org.jivesoftware.smackx.muc.UserStatusListener
import org.jxmpp.jid.EntityBareJid
import org.jxmpp.jid.EntityFullJid
import org.jxmpp.jid.Jid
import org.jxmpp.jid.parts.Resourcepart

class FxmppPlugin: FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var connectionStateEventChannel: EventChannel
    private lateinit var messageEventChannel: EventChannel
    private lateinit var presenceEventChannel: EventChannel
    private lateinit var iqEventChannel: EventChannel
    private lateinit var mucEventChannel: EventChannel
    
    private var connectionStateStreamHandler: ConnectionStateStreamHandler? = null
    private var messageStreamHandler: MessageStreamHandler? = null
    private var presenceStreamHandler: PresenceStreamHandler? = null
    private var iqStreamHandler: IqStreamHandler? = null
    private var mucEventStreamHandler: MucEventStreamHandler? = null
    
    private var connection: AbstractXMPPConnection? = null
    private var chatManager: ChatManager? = null
    private var roster: Roster? = null
    private var mucManager: MultiUserChatManager? = null
    private val joinedRooms = mutableMapOf<String, MultiUserChat>()
    
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "fxmpp")
        channel.setMethodCallHandler(this)
        
        // Set up event channels
        connectionStateEventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "fxmpp/connection_state")
        connectionStateStreamHandler = ConnectionStateStreamHandler()
        connectionStateEventChannel.setStreamHandler(connectionStateStreamHandler)
        
        messageEventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "fxmpp/messages")
        messageStreamHandler = MessageStreamHandler()
        messageEventChannel.setStreamHandler(messageStreamHandler)
        
        presenceEventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "fxmpp/presence")
        presenceStreamHandler = PresenceStreamHandler()
        presenceEventChannel.setStreamHandler(presenceStreamHandler)
        
        iqEventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "fxmpp/iq")
        iqStreamHandler = IqStreamHandler()
        iqEventChannel.setStreamHandler(iqStreamHandler)
        
        mucEventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "fxmpp/muc_events")
        mucEventStreamHandler = MucEventStreamHandler()
        mucEventChannel.setStreamHandler(mucEventStreamHandler)
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "connect" -> handleConnect(call, result)
            "disconnect" -> handleDisconnect(result)
            "sendMessage" -> handleSendMessage(call, result)
            "sendPresence" -> handleSendPresence(call, result)
            "sendIq" -> handleSendIq(call, result)
            "getConnectionState" -> handleGetConnectionState(result)
            // MUC methods
            "joinMucRoom" -> handleJoinMucRoom(call, result)
            "leaveMucRoom" -> handleLeaveMucRoom(call, result)
            "createMucRoom" -> handleCreateMucRoom(call, result)
            "sendMucMessage" -> handleSendMucMessage(call, result)
            "sendMucPrivateMessage" -> handleSendMucPrivateMessage(call, result)
            "changeMucSubject" -> handleChangeMucSubject(call, result)
            "kickMucParticipant" -> handleKickMucParticipant(call, result)
            "banMucUser" -> handleBanMucUser(call, result)
            "grantMucVoice" -> handleGrantMucVoice(call, result)
            "revokeMucVoice" -> handleRevokeMucVoice(call, result)
            "grantMucModerator" -> handleGrantMucModerator(call, result)
            "grantMucMembership" -> handleGrantMucMembership(call, result)
            "grantMucAdmin" -> handleGrantMucAdmin(call, result)
            "inviteMucUser" -> handleInviteMucUser(call, result)
            "destroyMucRoom" -> handleDestroyMucRoom(call, result)
            else -> result.notImplemented()
        }
    }

    private fun handleConnect(call: MethodCall, result: Result) {
        val args = call.arguments as? Map<String, Any> ?: run {
            result.error("INVALID_ARGUMENTS", "Invalid arguments", null)
            return
        }
        
        val host = args["host"] as? String ?: ""
        val port = args["port"] as? Int ?: 5222
        val username = args["username"] as? String ?: ""
        val password = args["password"] as? String ?: ""
        val domain = args["domain"] as? String ?: ""
        val useSSL = args["useSSL"] as? Boolean ?: true
        val allowSelfSignedCertificates = args["allowSelfSignedCertificates"] as? Boolean ?: false
        val resource = args["resource"] as? String ?: "fxmpp"
        
        Thread {
            try {
                val configBuilder = XMPPTCPConnectionConfiguration.builder()
                    .setHost(host)
                    .setPort(port)
                    .setXmppDomain(domain)
                    .setResource(resource)
                
                if (useSSL) {
                    configBuilder.setSecurityMode(ConnectionConfiguration.SecurityMode.required)
                } else {
                    configBuilder.setSecurityMode(ConnectionConfiguration.SecurityMode.disabled)
                }
                
                if (allowSelfSignedCertificates) {
                    configBuilder.setCustomX509TrustManager(AcceptAllTrustManager())
                }
                
                val config = configBuilder.build()
                connection = XMPPTCPConnection(config)
                
                connection?.addConnectionListener(object : ConnectionListener {
                    override fun connected(connection: XMPPConnection) {
                        mainHandler.post {
                            connectionStateStreamHandler?.sendConnectionState(1) // connecting
                        }
                    }
                    
                    override fun authenticated(connection: XMPPConnection, resumed: Boolean) {
                        mainHandler.post {
                            connectionStateStreamHandler?.sendConnectionState(2) // connected
                        }
                        setupListeners()
                    }
                    
                    override fun connectionClosed() {
                        mainHandler.post {
                            connectionStateStreamHandler?.sendConnectionState(0) // disconnected
                        }
                    }
                    
                    override fun connectionClosedOnError(e: Exception) {
                        mainHandler.post {
                            connectionStateStreamHandler?.sendConnectionState(6) // connection lost
                        }
                    }
                })
                
                connection?.connect()
                connection?.login(username, password)
                
                mainHandler.post {
                    result.success(true)
                }
                
            } catch (e: Exception) {
                mainHandler.post {
                    connectionStateStreamHandler?.sendConnectionState(4) // error
                    result.error("CONNECTION_ERROR", e.message, null)
                }
            }
        }.start()
    }
    
    private fun handleDisconnect(result: Result) {
        Thread {
            try {
                connection?.disconnect()
                mainHandler.post {
                    connectionStateStreamHandler?.sendConnectionState(0) // disconnected
                    result.success(null)
                }
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("DISCONNECT_ERROR", e.message, null)
                }
            }
        }.start()
    }
    
    private fun handleSendMessage(call: MethodCall, result: Result) {
        val args = call.arguments as? Map<String, Any> ?: run {
            result.error("INVALID_ARGUMENTS", "Invalid message arguments", null)
            return
        }
        
        val xmlString = args["xml"] as? String ?: run {
            result.error("INVALID_ARGUMENTS", "Missing XML content", null)
            return
        }
        
        Thread {
            try {
                println("FXMPP: Attempting to send message XML: $xmlString")
                
                // Check connection
                if (connection == null) {
                    throw Exception("No XMPP connection available")
                }
                
                if (!connection!!.isConnected) {
                    throw Exception("XMPP connection is not connected")
                }
                
                // Parse XML string to create proper stanza
                val stanza: Stanza = PacketParserUtils.parseStanza(xmlString)
                println("FXMPP: Parsed stanza: ${stanza.toXML()}")
                
                connection!!.sendStanza(stanza)
                println("FXMPP: Message sent successfully")
                
                mainHandler.post {
                    result.success(true)
                }
            } catch (e: Exception) {
                println("FXMPP: Error sending message: ${e.message}")
                e.printStackTrace()
                mainHandler.post {
                    result.error("SEND_MESSAGE_ERROR", e.message, null)
                }
            }
        }.start()
    }
    
    private fun handleSendPresence(call: MethodCall, result: Result) {
        val args = call.arguments as? Map<String, Any> ?: run {
            result.error("INVALID_ARGUMENTS", "Invalid presence arguments", null)
            return
        }
        
        val xmlString = args["xml"] as? String ?: run {
            result.error("INVALID_ARGUMENTS", "Missing XML content", null)
            return
        }
        
        Thread {
            try {
                // Parse XML string to create proper stanza
                val stanza: Stanza = PacketParserUtils.parseStanza(xmlString)
                connection?.sendStanza(stanza)
                
                mainHandler.post {
                    result.success(true)
                }
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("SEND_PRESENCE_ERROR", e.message, null)
                }
            }
        }.start()
    }
    
    private fun handleSendIq(call: MethodCall, result: Result) {
        val args = call.arguments as? Map<String, Any> ?: run {
            result.error("INVALID_ARGUMENTS", "Invalid IQ arguments", null)
            return
        }
        
        val xmlString = args["xml"] as? String ?: run {
            result.error("INVALID_ARGUMENTS", "Missing XML content", null)
            return
        }
        
        Thread {
            try {
                println("FXMPP: Attempting to send IQ XML: $xmlString")
                
                // Check connection
                if (connection == null) {
                    throw Exception("No XMPP connection available")
                }
                
                if (!connection!!.isConnected) {
                    throw Exception("XMPP connection is not connected")
                }
                
                // Parse XML string to create proper stanza
                val stanza: Stanza = PacketParserUtils.parseStanza(xmlString)
                println("FXMPP: Parsed IQ stanza: ${stanza.toXML()}")
                
                connection!!.sendStanza(stanza)
                println("FXMPP: IQ sent successfully")
                
                mainHandler.post {
                    result.success(true)
                }
            } catch (e: Exception) {
                println("FXMPP: Error sending IQ: ${e.message}")
                e.printStackTrace()
                mainHandler.post {
                    result.error("SEND_IQ_ERROR", e.message, null)
                }
            }
        }.start()
    }
    
    private fun handleGetConnectionState(result: Result) {
        val state = when {
            connection?.isConnected == true && connection?.isAuthenticated == true -> 2 // connected
            connection?.isConnected == true -> 1 // connecting
            else -> 0 // disconnected
        }
        result.success(state)
    }
    
    private fun setupListeners() {
        connection?.let { conn ->
            println("FXMPP: Setting up listeners for connection")
            println("FXMPP: iqStreamHandler is null: ${iqStreamHandler == null}")
            
            // Set up chat manager
            chatManager = ChatManager.getInstanceFor(conn)
            chatManager?.addIncomingListener { from, message, chat ->
                // Send the raw XML of the message
                val xmlString = message.toXML().toString()
                val messageMap = mapOf("from" to from, "xml" to xmlString)
                mainHandler.post {
                    messageStreamHandler?.sendMessage(messageMap)
                }
            }
            
            // Set up presence listener
            conn.addAsyncStanzaListener(object : StanzaListener {
                override fun processStanza(stanza: Stanza) {
                    if (stanza is Presence) {
                        // Send the raw XML of the presence
                        val xmlString = stanza.toXML().toString()
                        println("FXMPP: Received Presence: $xmlString")
                        
                        mainHandler.post {
                            presenceStreamHandler?.sendPresence(xmlString)
                        }
                    }
                }
            }, StanzaTypeFilter(Presence::class.java))
            
            // Set up IQ listener - listen to ALL stanzas to debug
            conn.addAsyncStanzaListener(object : StanzaListener {
                override fun processStanza(stanza: Stanza) {
                    when (stanza) {
                        is Message -> {
                            val xmlString = stanza.toXML().toString()
                            val messageType = stanza.type?.toString() ?: "normal"
                            if (messageType == "groupchat") {
                                println("[XMPP-MUC] <<< Received groupchat message: $xmlString")
                            } else if (messageType == "chat" && stanza.from?.resourceOrNull != null) {
                                println("[XMPP-MUC] <<< Received private message: $xmlString")
                            } else {
                                println("[XMPP-Message] <<< Received message: $xmlString")
                            }
                        }
                        is IQ -> {
                            println("[XMPP-IQ] <<< Received IQ stanza: ${stanza.javaClass.simpleName}")
                        }
                        is Presence -> {
                            println("[XMPP-Presence] <<< Received presence: ${stanza.javaClass.simpleName}")
                        }
                        else -> {
                            println("[XMPP] <<< Received stanza type: ${stanza.javaClass.simpleName}")
                        }
                    }
                    if (stanza is IQ) {
                        // Send the raw XML of the IQ
                        val xmlString = stanza.toXML().toString()
                        println("FXMPP: Received IQ: $xmlString")
                        println("FXMPP: IQ Type: ${stanza.type}, ID: ${stanza.stanzaId}")
                        
                        mainHandler.post {
                            try {
                                iqStreamHandler?.sendIq(xmlString)
                                println("FXMPP: IQ sent to Dart successfully")
                            } catch (e: Exception) {
                                println("FXMPP: Error sending IQ to Dart: ${e.message}")
                                e.printStackTrace()
                            }
                        }
                    }
                }
            }, null) // Listen to ALL stanzas for debugging
            
            // Set up roster
            roster = Roster.getInstanceFor(conn)
            
            // Set up MUC manager
            mucManager = MultiUserChatManager.getInstanceFor(conn)
        }
    }

    // ============================================================================
    // MUC (Multi-User Chat) METHOD HANDLERS
    // ============================================================================

    private fun handleJoinMucRoom(call: MethodCall, result: Result) {
        val args = call.arguments as? Map<String, Any> ?: run {
            result.error("INVALID_ARGUMENTS", "Invalid arguments", null)
            return
        }
        
        val roomJid = args["roomJid"] as? String ?: run {
            result.error("INVALID_ARGUMENTS", "Missing roomJid", null)
            return
        }
        
        val nickname = args["nickname"] as? String ?: run {
            result.error("INVALID_ARGUMENTS", "Missing nickname", null)
            return
        }
        
        val password = args["password"] as? String
        val maxStanzas = args["maxStanzas"] as? Int
        val since = args["since"] as? Long
        
        Thread {
            try {
                val entityBareJid = JidCreate.entityBareFrom(roomJid)
                val resourcepart = Resourcepart.from(nickname)
                val muc = mucManager?.getMultiUserChat(entityBareJid)
                
                if (muc == null) {
                    throw Exception("Failed to get MultiUserChat instance")
                }
                
                // Set up listeners for this room
                setupMucListeners(muc, roomJid)
                
                // Configure join parameters
                val enterConfigBuilder = muc.getEnterConfigurationBuilder(resourcepart)
                
                if (password != null) {
                    enterConfigBuilder.withPassword(password)
                }
                
                if (maxStanzas != null) {
                    enterConfigBuilder.requestMaxStanzasHistory(maxStanzas)
                }
                
                if (since != null) {
                    enterConfigBuilder.requestHistorySince(Date(since))
                }
                
                val enterConfig = enterConfigBuilder.build()
                muc.join(enterConfig)
                
                // Store the joined room
                joinedRooms[roomJid] = muc
                
                mainHandler.post {
                    result.success(true)
                }
                
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("JOIN_MUC_ERROR", e.message, null)
                }
            }
        }.start()
    }
    
    private fun handleLeaveMucRoom(call: MethodCall, result: Result) {
        val args = call.arguments as? Map<String, Any> ?: run {
            result.error("INVALID_ARGUMENTS", "Invalid arguments", null)
            return
        }
        
        val roomJid = args["roomJid"] as? String ?: run {
            result.error("INVALID_ARGUMENTS", "Missing roomJid", null)
            return
        }
        
        val reason = args["reason"] as? String
        
        Thread {
            try {
                val muc = joinedRooms[roomJid] ?: run {
                    throw Exception("Not joined to room $roomJid")
                }
                
                muc.leave()
                
                joinedRooms.remove(roomJid)
                
                mainHandler.post {
                    result.success(true)
                }
                
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("LEAVE_MUC_ERROR", e.message, null)
                }
            }
        }.start()
    }
    
    private fun handleCreateMucRoom(call: MethodCall, result: Result) {
        val args = call.arguments as? Map<String, Any> ?: run {
            result.error("INVALID_ARGUMENTS", "Invalid arguments", null)
            return
        }
        
        val roomJid = args["roomJid"] as? String ?: run {
            result.error("INVALID_ARGUMENTS", "Missing roomJid", null)
            return
        }
        
        val nickname = args["nickname"] as? String ?: run {
            result.error("INVALID_ARGUMENTS", "Missing nickname", null)
            return
        }
        
        val password = args["password"] as? String
        
        Thread {
            try {
                val entityBareJid = JidCreate.entityBareFrom(roomJid)
                val resourcepart = Resourcepart.from(nickname)
                val muc = mucManager?.getMultiUserChat(entityBareJid)
                
                if (muc == null) {
                    throw Exception("Failed to get MultiUserChat instance")
                }
                
                // Set up listeners for this room
                setupMucListeners(muc, roomJid)
                
                // Create and join the room
                val enterConfigBuilder = muc.getEnterConfigurationBuilder(resourcepart)
                if (password != null) {
                    enterConfigBuilder.withPassword(password)
                }
                
                val enterConfig = enterConfigBuilder.build()
                muc.create(resourcepart)
                
                // Store the joined room
                joinedRooms[roomJid] = muc
                
                mainHandler.post {
                    result.success(true)
                }
                
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("CREATE_MUC_ERROR", e.message, null)
                }
            }
        }.start()
    }
    
    private fun handleSendMucMessage(call: MethodCall, result: Result) {
        val args = call.arguments as? Map<String, Any> ?: run {
            result.error("INVALID_ARGUMENTS", "Invalid arguments", null)
            return
        }
        
        val xmlString = args["xml"] as? String ?: run {
            result.error("INVALID_ARGUMENTS", "Missing xml", null)
            return
        }
        
        Thread {
            try {
                val stanza = PacketParserUtils.parseStanza(xmlString) as Stanza
                if (stanza is Message) {
                    connection!!.sendStanza(stanza)
                    mainHandler.post {
                        result.success(true)
                    }
                } else {
                    throw Exception("Invalid message stanza")
                }
                
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("SEND_MUC_MESSAGE_ERROR", e.message, null)
                }
            }
        }.start()
    }
    
    private fun handleSendMucPrivateMessage(call: MethodCall, result: Result) {
        val args = call.arguments as? Map<String, Any> ?: run {
            result.error("INVALID_ARGUMENTS", "Invalid arguments", null)
            return
        }
        
        val xmlString = args["xml"] as? String ?: run {
            result.error("INVALID_ARGUMENTS", "Missing xml", null)
            return
        }
        
        Thread {
            try {
                val stanza = PacketParserUtils.parseStanza(xmlString) as Stanza
                if (stanza is Message) {
                    connection!!.sendStanza(stanza)
                    mainHandler.post {
                        result.success(true)
                    }
                } else {
                    throw Exception("Invalid message stanza")
                }
                
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("SEND_MUC_PRIVATE_MESSAGE_ERROR", e.message, null)
                }
            }
        }.start()
    }
    
    private fun handleChangeMucSubject(call: MethodCall, result: Result) {
        val args = call.arguments as? Map<String, Any> ?: run {
            result.error("INVALID_ARGUMENTS", "Invalid arguments", null)
            return
        }
        
        val roomJid = args["roomJid"] as? String ?: run {
            result.error("INVALID_ARGUMENTS", "Missing roomJid", null)
            return
        }
        
        val subject = args["subject"] as? String ?: run {
            result.error("INVALID_ARGUMENTS", "Missing subject", null)
            return
        }
        
        Thread {
            try {
                val muc = joinedRooms[roomJid] ?: run {
                    throw Exception("Not joined to room $roomJid")
                }
                
                muc.changeSubject(subject)
                
                mainHandler.post {
                    result.success(true)
                }
                
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("CHANGE_MUC_SUBJECT_ERROR", e.message, null)
                }
            }
        }.start()
    }
    
    private fun handleKickMucParticipant(call: MethodCall, result: Result) {
        val args = call.arguments as? Map<String, Any> ?: run {
            result.error("INVALID_ARGUMENTS", "Invalid arguments", null)
            return
        }
        
        val roomJid = args["roomJid"] as? String ?: run {
            result.error("INVALID_ARGUMENTS", "Missing roomJid", null)
            return
        }
        
        val nickname = args["nickname"] as? String ?: run {
            result.error("INVALID_ARGUMENTS", "Missing nickname", null)
            return
        }
        
        val reason = args["reason"] as? String
        
        Thread {
            try {
                val muc = joinedRooms[roomJid] ?: run {
                    throw Exception("Not joined to room $roomJid")
                }
                
                val resourcepart = Resourcepart.from(nickname)
                if (reason != null) {
                    muc.kickParticipant(resourcepart, reason)
                } else {
                    muc.kickParticipant(resourcepart, "")
                }
                
                mainHandler.post {
                    result.success(true)
                }
                
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("KICK_MUC_PARTICIPANT_ERROR", e.message, null)
                }
            }
        }.start()
    }
    
    private fun handleBanMucUser(call: MethodCall, result: Result) {
        val args = call.arguments as? Map<String, Any> ?: run {
            result.error("INVALID_ARGUMENTS", "Invalid arguments", null)
            return
        }
        
        val roomJid = args["roomJid"] as? String ?: run {
            result.error("INVALID_ARGUMENTS", "Missing roomJid", null)
            return
        }
        
        val userJid = args["userJid"] as? String ?: run {
            result.error("INVALID_ARGUMENTS", "Missing userJid", null)
            return
        }
        
        val reason = args["reason"] as? String
        
        Thread {
            try {
                val muc = joinedRooms[roomJid] ?: run {
                    throw Exception("Not joined to room $roomJid")
                }
                
                val jid = JidCreate.from(userJid)
                if (reason != null) {
                    muc.banUser(jid, reason)
                } else {
                    muc.banUser(jid, "")
                }
                
                mainHandler.post {
                    result.success(true)
                }
                
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("BAN_MUC_USER_ERROR", e.message, null)
                }
            }
        }.start()
    }
    
    private fun handleGrantMucVoice(call: MethodCall, result: Result) {
        val args = call.arguments as? Map<String, Any> ?: run {
            result.error("INVALID_ARGUMENTS", "Invalid arguments", null)
            return
        }
        
        val roomJid = args["roomJid"] as? String ?: run {
            result.error("INVALID_ARGUMENTS", "Missing roomJid", null)
            return
        }
        
        val nickname = args["nickname"] as? String ?: run {
            result.error("INVALID_ARGUMENTS", "Missing nickname", null)
            return
        }
        
        val reason = args["reason"] as? String
        
        Thread {
            try {
                val muc = joinedRooms[roomJid] ?: run {
                    throw Exception("Not joined to room $roomJid")
                }
                
                val resourcepart = Resourcepart.from(nickname)
                muc.grantVoice(resourcepart)
                
                mainHandler.post {
                    result.success(true)
                }
                
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("GRANT_MUC_VOICE_ERROR", e.message, null)
                }
            }
        }.start()
    }
    
    private fun handleRevokeMucVoice(call: MethodCall, result: Result) {
        val args = call.arguments as? Map<String, Any> ?: run {
            result.error("INVALID_ARGUMENTS", "Invalid arguments", null)
            return
        }
        
        val roomJid = args["roomJid"] as? String ?: run {
            result.error("INVALID_ARGUMENTS", "Missing roomJid", null)
            return
        }
        
        val nickname = args["nickname"] as? String ?: run {
            result.error("INVALID_ARGUMENTS", "Missing nickname", null)
            return
        }
        
        val reason = args["reason"] as? String
        
        Thread {
            try {
                val muc = joinedRooms[roomJid] ?: run {
                    throw Exception("Not joined to room $roomJid")
                }
                
                val resourcepart = Resourcepart.from(nickname)
                muc.revokeVoice(resourcepart)
                
                mainHandler.post {
                    result.success(true)
                }
                
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("REVOKE_MUC_VOICE_ERROR", e.message, null)
                }
            }
        }.start()
    }
    
    private fun handleGrantMucModerator(call: MethodCall, result: Result) {
        val args = call.arguments as? Map<String, Any> ?: run {
            result.error("INVALID_ARGUMENTS", "Invalid arguments", null)
            return
        }
        
        val roomJid = args["roomJid"] as? String ?: run {
            result.error("INVALID_ARGUMENTS", "Missing roomJid", null)
            return
        }
        
        val nickname = args["nickname"] as? String ?: run {
            result.error("INVALID_ARGUMENTS", "Missing nickname", null)
            return
        }
        
        val reason = args["reason"] as? String
        
        Thread {
            try {
                val muc = joinedRooms[roomJid] ?: run {
                    throw Exception("Not joined to room $roomJid")
                }
                
                val resourcepart = Resourcepart.from(nickname)
                muc.grantModerator(resourcepart)
                
                mainHandler.post {
                    result.success(true)
                }
                
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("GRANT_MUC_MODERATOR_ERROR", e.message, null)
                }
            }
        }.start()
    }
    
    private fun handleGrantMucMembership(call: MethodCall, result: Result) {
        val args = call.arguments as? Map<String, Any> ?: run {
            result.error("INVALID_ARGUMENTS", "Invalid arguments", null)
            return
        }
        
        val roomJid = args["roomJid"] as? String ?: run {
            result.error("INVALID_ARGUMENTS", "Missing roomJid", null)
            return
        }
        
        val userJid = args["userJid"] as? String ?: run {
            result.error("INVALID_ARGUMENTS", "Missing userJid", null)
            return
        }
        
        val reason = args["reason"] as? String
        
        Thread {
            try {
                val muc = joinedRooms[roomJid] ?: run {
                    throw Exception("Not joined to room $roomJid")
                }
                
                val jid = JidCreate.from(userJid)
                muc.grantMembership(jid)
                
                mainHandler.post {
                    result.success(true)
                }
                
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("GRANT_MUC_MEMBERSHIP_ERROR", e.message, null)
                }
            }
        }.start()
    }
    
    private fun handleGrantMucAdmin(call: MethodCall, result: Result) {
        val args = call.arguments as? Map<String, Any> ?: run {
            result.error("INVALID_ARGUMENTS", "Invalid arguments", null)
            return
        }
        
        val roomJid = args["roomJid"] as? String ?: run {
            result.error("INVALID_ARGUMENTS", "Missing roomJid", null)
            return
        }
        
        val userJid = args["userJid"] as? String ?: run {
            result.error("INVALID_ARGUMENTS", "Missing userJid", null)
            return
        }
        
        val reason = args["reason"] as? String
        
        Thread {
            try {
                val muc = joinedRooms[roomJid] ?: run {
                    throw Exception("Not joined to room $roomJid")
                }
                
                val jid = JidCreate.from(userJid)
                muc.grantAdmin(jid)
                
                mainHandler.post {
                    result.success(true)
                }
                
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("GRANT_MUC_ADMIN_ERROR", e.message, null)
                }
            }
        }.start()
    }
    
    private fun handleInviteMucUser(call: MethodCall, result: Result) {
        val args = call.arguments as? Map<String, Any> ?: run {
            result.error("INVALID_ARGUMENTS", "Invalid arguments", null)
            return
        }
        
        val roomJid = args["roomJid"] as? String ?: run {
            result.error("INVALID_ARGUMENTS", "Missing roomJid", null)
            return
        }
        
        val userJid = args["userJid"] as? String ?: run {
            result.error("INVALID_ARGUMENTS", "Missing userJid", null)
            return
        }
        
        val reason = args["reason"] as? String ?: ""
        
        Thread {
            try {
                val muc = joinedRooms[roomJid] ?: run {
                    throw Exception("Not joined to room $roomJid")
                }
                
                val entityBareJid = JidCreate.entityBareFrom(userJid)
                muc.invite(entityBareJid, reason)
                
                mainHandler.post {
                    result.success(true)
                }
                
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("INVITE_MUC_USER_ERROR", e.message, null)
                }
            }
        }.start()
    }
    
    private fun handleDestroyMucRoom(call: MethodCall, result: Result) {
        val args = call.arguments as? Map<String, Any> ?: run {
            result.error("INVALID_ARGUMENTS", "Invalid arguments", null)
            return
        }
        
        val roomJid = args["roomJid"] as? String ?: run {
            result.error("INVALID_ARGUMENTS", "Missing roomJid", null)
            return
        }
        
        val reason = args["reason"] as? String
        val alternativeRoom = args["alternativeRoom"] as? String
        
        Thread {
            try {
                val muc = joinedRooms[roomJid] ?: run {
                    throw Exception("Not joined to room $roomJid")
                }
                
                val alternativeJid = if (alternativeRoom != null) {
                    JidCreate.entityBareFrom(alternativeRoom)
                } else null
                
                muc.destroy(reason ?: "", alternativeJid)
                joinedRooms.remove(roomJid)
                
                mainHandler.post {
                    result.success(true)
                }
                
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("DESTROY_MUC_ROOM_ERROR", e.message, null)
                }
            }
        }.start()
    }
    
    private fun setupMucListeners(muc: MultiUserChat, roomJid: String) {
        // Set up participant status listener
        muc.addParticipantStatusListener(object : ParticipantStatusListener {
            override fun joined(participant: EntityFullJid) {
                val event = mapOf(
                    "type" to "participant_joined",
                    "roomJid" to roomJid,
                    "participant" to participant.toString()
                )
                mainHandler.post {
                    mucEventStreamHandler?.sendEvent(event)
                }
            }
            
            override fun left(participant: EntityFullJid) {
                val event = mapOf(
                    "type" to "participant_left",
                    "roomJid" to roomJid,
                    "participant" to participant.toString()
                )
                mainHandler.post {
                    mucEventStreamHandler?.sendEvent(event)
                }
            }
            
            override fun kicked(participant: EntityFullJid, actor: Jid?, reason: String?) {
                val event = mapOf(
                    "type" to "participant_kicked",
                    "roomJid" to roomJid,
                    "participant" to participant.toString(),
                    "actor" to (actor?.toString() ?: ""),
                    "reason" to (reason ?: "")
                )
                mainHandler.post {
                    mucEventStreamHandler?.sendEvent(event)
                }
            }
            
            override fun banned(participant: EntityFullJid, actor: Jid?, reason: String?) {
                val event = mapOf(
                    "type" to "participant_banned",
                    "roomJid" to roomJid,
                    "participant" to participant.toString(),
                    "actor" to (actor?.toString() ?: ""),
                    "reason" to (reason ?: "")
                )
                mainHandler.post {
                    mucEventStreamHandler?.sendEvent(event)
                }
            }
            
            override fun membershipGranted(participant: EntityFullJid) {
                val event = mapOf(
                    "type" to "membership_granted",
                    "roomJid" to roomJid,
                    "participant" to participant.toString()
                )
                mainHandler.post {
                    mucEventStreamHandler?.sendEvent(event)
                }
            }
            
            override fun membershipRevoked(participant: EntityFullJid) {
                val event = mapOf(
                    "type" to "membership_revoked",
                    "roomJid" to roomJid,
                    "participant" to participant.toString()
                )
                mainHandler.post {
                    mucEventStreamHandler?.sendEvent(event)
                }
            }
            
            override fun moderatorGranted(participant: EntityFullJid) {
                val event = mapOf(
                    "type" to "moderator_granted",
                    "roomJid" to roomJid,
                    "participant" to participant.toString()
                )
                mainHandler.post {
                    mucEventStreamHandler?.sendEvent(event)
                }
            }
            
            override fun moderatorRevoked(participant: EntityFullJid) {
                val event = mapOf(
                    "type" to "moderator_revoked",
                    "roomJid" to roomJid,
                    "participant" to participant.toString()
                )
                mainHandler.post {
                    mucEventStreamHandler?.sendEvent(event)
                }
            }
            
            override fun ownershipGranted(participant: EntityFullJid) {
                val event = mapOf(
                    "type" to "ownership_granted",
                    "roomJid" to roomJid,
                    "participant" to participant.toString()
                )
                mainHandler.post {
                    mucEventStreamHandler?.sendEvent(event)
                }
            }
            
            override fun ownershipRevoked(participant: EntityFullJid) {
                val event = mapOf(
                    "type" to "ownership_revoked",
                    "roomJid" to roomJid,
                    "participant" to participant.toString()
                )
                mainHandler.post {
                    mucEventStreamHandler?.sendEvent(event)
                }
            }
            
            override fun adminGranted(participant: EntityFullJid) {
                val event = mapOf(
                    "type" to "admin_granted",
                    "roomJid" to roomJid,
                    "participant" to participant.toString()
                )
                mainHandler.post {
                    mucEventStreamHandler?.sendEvent(event)
                }
            }
            
            override fun adminRevoked(participant: EntityFullJid) {
                val event = mapOf(
                    "type" to "admin_revoked",
                    "roomJid" to roomJid,
                    "participant" to participant.toString()
                )
                mainHandler.post {
                    mucEventStreamHandler?.sendEvent(event)
                }
            }
            
            override fun voiceGranted(participant: EntityFullJid) {
                val event = mapOf(
                    "type" to "voice_granted",
                    "roomJid" to roomJid,
                    "participant" to participant.toString()
                )
                mainHandler.post {
                    mucEventStreamHandler?.sendEvent(event)
                }
            }
            
            override fun voiceRevoked(participant: EntityFullJid) {
                val event = mapOf(
                    "type" to "voice_revoked",
                    "roomJid" to roomJid,
                    "participant" to participant.toString()
                )
                mainHandler.post {
                    mucEventStreamHandler?.sendEvent(event)
                }
            }
            
            override fun nicknameChanged(participant: EntityFullJid, newNickname: Resourcepart) {
                val event = mapOf(
                    "type" to "nickname_changed",
                    "roomJid" to roomJid,
                    "participant" to participant.toString(),
                    "newNickname" to newNickname.toString()
                )
                mainHandler.post {
                    mucEventStreamHandler?.sendEvent(event)
                }
            }
        })
        
        // Set up subject updated listener
        muc.addSubjectUpdatedListener { subject, from ->
            val event = mapOf(
                "type" to "subject_updated",
                "roomJid" to roomJid,
                "subject" to subject,
                "from" to from.toString()
            )
            mainHandler.post {
                mucEventStreamHandler?.sendEvent(event)
            }
        }
        
        // Set up user status listener
        muc.addUserStatusListener(object : UserStatusListener {
            override fun kicked(actor: Jid?, reason: String?) {
                val event = mapOf(
                    "type" to "user_kicked",
                    "roomJid" to roomJid,
                    "actor" to (actor?.toString() ?: ""),
                    "reason" to (reason ?: "")
                )
                mainHandler.post {
                    mucEventStreamHandler?.sendEvent(event)
                }
            }
            
            override fun banned(actor: Jid?, reason: String?) {
                val event = mapOf(
                    "type" to "user_banned",
                    "roomJid" to roomJid,
                    "actor" to (actor?.toString() ?: ""),
                    "reason" to (reason ?: "")
                )
                mainHandler.post {
                    mucEventStreamHandler?.sendEvent(event)
                }
            }
            
            override fun roomDestroyed(alternateMUC: MultiUserChat?, reason: String?) {
                val event = mapOf(
                    "type" to "room_destroyed",
                    "roomJid" to roomJid,
                    "alternateRoom" to (alternateMUC?.room?.toString() ?: ""),
                    "reason" to (reason ?: "")
                )
                mainHandler.post {
                    mucEventStreamHandler?.sendEvent(event)
                }
            }
        })
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        connectionStateEventChannel.setStreamHandler(null)
        messageEventChannel.setStreamHandler(null)
        presenceEventChannel.setStreamHandler(null)
        iqEventChannel.setStreamHandler(null)
        mucEventChannel.setStreamHandler(null)
        
        // Leave all joined rooms and disconnect
        joinedRooms.values.forEach { muc ->
            try {
                muc.leave()
            } catch (e: Exception) {
                // Ignore errors when leaving rooms during cleanup
            }
        }
        joinedRooms.clear()
        
        connection?.disconnect()
    }
}

// Stream Handlers
class ConnectionStateStreamHandler : EventChannel.StreamHandler {
    private var eventSink: EventChannel.EventSink? = null
    
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }
    
    override fun onCancel(arguments: Any?) {
        eventSink = null
    }
    
    fun sendConnectionState(state: Int) {
        eventSink?.success(state)
    }
}

class MessageStreamHandler : EventChannel.StreamHandler {
    private var eventSink: EventChannel.EventSink? = null
    
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }
    
    override fun onCancel(arguments: Any?) {
        eventSink = null
    }
    
    fun sendMessage(message: Map<String, Any>) {
        eventSink?.success(message)
    }
}

class PresenceStreamHandler : EventChannel.StreamHandler {
    private var eventSink: EventChannel.EventSink? = null
    
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }
    
    override fun onCancel(arguments: Any?) {
        eventSink = null
    }
    
    fun sendPresence(xmlString: String) {
        eventSink?.success(xmlString)
    }
}

class IqStreamHandler : EventChannel.StreamHandler {
    private var eventSink: EventChannel.EventSink? = null
    
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }
    
    override fun onCancel(arguments: Any?) {
        eventSink = null
    }
    
    fun sendIq(xmlString: String) {
        eventSink?.success(xmlString)
    }
}

class MucEventStreamHandler : EventChannel.StreamHandler {
    private var eventSink: EventChannel.EventSink? = null
    
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }
    
    override fun onCancel(arguments: Any?) {
        eventSink = null
    }
    
    fun sendEvent(event: Map<String, Any>) {
        eventSink?.success(event)
    }
}

// Trust manager for self-signed certificates
class AcceptAllTrustManager : javax.net.ssl.X509TrustManager {
    override fun checkClientTrusted(chain: Array<java.security.cert.X509Certificate>, authType: String) {}
    override fun checkServerTrusted(chain: Array<java.security.cert.X509Certificate>, authType: String) {}
    override fun getAcceptedIssuers(): Array<java.security.cert.X509Certificate> = arrayOf()
}
