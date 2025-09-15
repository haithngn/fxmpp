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

class FxmppPlugin: FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var connectionStateEventChannel: EventChannel
    private lateinit var messageEventChannel: EventChannel
    private lateinit var presenceEventChannel: EventChannel
    private lateinit var iqEventChannel: EventChannel
    
    private var connectionStateStreamHandler: ConnectionStateStreamHandler? = null
    private var messageStreamHandler: MessageStreamHandler? = null
    private var presenceStreamHandler: PresenceStreamHandler? = null
    private var iqStreamHandler: IqStreamHandler? = null
    
    private var connection: AbstractXMPPConnection? = null
    private var chatManager: ChatManager? = null
    private var roster: Roster? = null
    
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
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "connect" -> handleConnect(call, result)
            "disconnect" -> handleDisconnect(result)
            "sendMessage" -> handleSendMessage(call, result)
            "sendPresence" -> handleSendPresence(call, result)
            "sendIq" -> handleSendIq(call, result)
            "getConnectionState" -> handleGetConnectionState(result)
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
                    println("FXMPP: Received stanza type: ${stanza.javaClass.simpleName}")
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
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        connectionStateEventChannel.setStreamHandler(null)
        messageEventChannel.setStreamHandler(null)
        presenceEventChannel.setStreamHandler(null)
        iqEventChannel.setStreamHandler(null)
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

// Trust manager for self-signed certificates
class AcceptAllTrustManager : javax.net.ssl.X509TrustManager {
    override fun checkClientTrusted(chain: Array<java.security.cert.X509Certificate>, authType: String) {}
    override fun checkServerTrusted(chain: Array<java.security.cert.X509Certificate>, authType: String) {}
    override fun getAcceptedIssuers(): Array<java.security.cert.X509Certificate> = arrayOf()
}
