import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:fxmpp/fxmpp.dart';
import 'dart:async';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FXMPP Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'FXMPP Example'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final Fxmpp _fxmpp = Fxmpp();
  final TextEditingController _hostController =
      TextEditingController(text: 'localhost');
  final TextEditingController _portController =
      TextEditingController(text: '5222');
  final TextEditingController _usernameController =
      TextEditingController(text: 'user1');
  final TextEditingController _passwordController =
      TextEditingController(text: 'user1');
  final TextEditingController _domainController =
      TextEditingController(text: 'localhost');
  final TextEditingController _messageController =
      TextEditingController(text: 'Hello, user2!');
  final TextEditingController _recipientController =
      TextEditingController(text: 'user2@localhost');

  XmppConnectionState _connectionState = XmppConnectionState.disconnected;
  final List<XmlDocument> _messages = [];
  final List<XmlDocument> _presences = [];
  final List<XmlDocument> _iqs = [];

  StreamSubscription<XmppConnectionState>? _connectionStateSubscription;
  StreamSubscription<XmlDocument>? _messageSubscription;
  StreamSubscription<XmlDocument>? _presenceSubscription;
  StreamSubscription<XmlDocument>? _iqSubscription;

  @override
  void initState() {
    super.initState();
    _initializePlugin();
  }

  Future<void> _initializePlugin() async {
    await _fxmpp.initialize();

    _connectionStateSubscription = _fxmpp.connectionStateStream.listen((state) {
      setState(() {
        _connectionState = state;
      });
    });

    _messageSubscription = _fxmpp.messageStream.listen((xmlMessage) {
      setState(() {
        _messages.insert(0, xmlMessage);
      });
    });

    _presenceSubscription = _fxmpp.presenceStream.listen((xmlPresence) {
      setState(() {
        _presences.insert(0, xmlPresence);
      });
    });

    _iqSubscription = _fxmpp.iqStream.listen((xmlIq) {
      setState(() {
        _iqs.insert(0, xmlIq);
      });
    });
  }

  Future<void> _connect() async {
    if (_usernameController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _domainController.text.isEmpty) {
      _showSnackBar('Please fill in all connection fields');
      return;
    }

    final config = XmppConnectionConfig(
      host: _hostController.text,
      port: int.tryParse(_portController.text) ?? 5222,
      username: _usernameController.text,
      password: _passwordController.text,
      domain: _domainController.text,
      useSSL: true,
      allowSelfSignedCertificates: true,
      resource: 'fxmpp_example',
    );

    try {
      final success = await _fxmpp.connect(config);
      if (success) {
        _showSnackBar('Connection initiated');
      } else {
        _showSnackBar('Failed to connect');
      }
    } catch (e) {
      _showSnackBar('Connection error: $e');
    }
  }

  Future<void> _disconnect() async {
    await _fxmpp.disconnect();
    _showSnackBar('Disconnected');
  }

  // Helper functions to extract data from XML
  String _getMessageFrom(XmlDocument xmlDoc) {
    return xmlDoc.rootElement.getAttribute('from') ?? '';
  }

  String _getMessageTo(XmlDocument xmlDoc) {
    return xmlDoc.rootElement.getAttribute('to') ?? '';
  }

  String _getMessageBody(XmlDocument xmlDoc) {
    return xmlDoc.rootElement.findElements('body').first.innerText;
  }

  String _getPresenceFrom(XmlDocument xmlDoc) {
    return xmlDoc.rootElement.getAttribute('from') ?? '';
  }

  String _getPresenceShow(XmlDocument xmlDoc) {
    final showElement = xmlDoc.rootElement.findElements('show');
    return showElement.isNotEmpty ? showElement.first.innerText : 'online';
  }

  String _getPresenceStatus(XmlDocument xmlDoc) {
    final statusElement = xmlDoc.rootElement.findElements('status');
    return statusElement.isNotEmpty ? statusElement.first.innerText : '';
  }

  // Helper functions to create XMPP XML using new utility methods
  XmlDocument _createMessageXml(String to, String body) {
    return Fxmpp.createMessage(
      messageId: Fxmpp.generateId('msg'),
      type: MessageType.chat,
      fromJid: '${_usernameController.text}@${_domainController.text}',
      toJid: to,
      content: body,
    );
  }

  XmlDocument _createPresenceXml({String? show, String? status}) {
    PresenceShow presenceShow = PresenceShow.available;
    if (show != null) {
      switch (show) {
        case 'away':
          presenceShow = PresenceShow.away;
          break;
        case 'dnd':
          presenceShow = PresenceShow.dnd;
          break;
        case 'xa':
          presenceShow = PresenceShow.xa;
          break;
        case 'chat':
          presenceShow = PresenceShow.chat;
          break;
        default:
          presenceShow = PresenceShow.available;
      }
    }

    return Fxmpp.createPresence(
      presenceId: Fxmpp.generateId('pres'),
      type: PresenceType.available,
      fromJid: '${_usernameController.text}@${_domainController.text}',
      show: presenceShow,
      status: status,
      priority: 0,
    );
  }

  XmlDocument _createIqBindResourceXml(String type, String to, String resource,
      {String? queryNamespace}) {
    //<iq type='set' id='purple18f99190'><bind xmlns='urn:ietf:params:xml:ns:xmpp-bind'><resource>CraftsDev</resource></bind></iq>
    final builder = XmlBuilder();
    builder.element('iq', nest: () {
      builder.attribute('type', 'set');
      builder.attribute('id', DateTime.now().millisecondsSinceEpoch.toString());

      builder.element('bind', nest: () {
        builder.attribute('xmlns', 'urn:ietf:params:xml:ns:xmpp-bind');
        builder.element('resource', nest: resource);
      });
    });

    return builder.buildDocument();
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty || _recipientController.text.isEmpty) {
      _showSnackBar('Please enter both message and recipient');
      return;
    }

    final messageXml =
        _createMessageXml(_recipientController.text, _messageController.text);

    try {
      final success = await _fxmpp.sendMessage(messageXml);
      if (success) {
        _messageController.clear();
        _showSnackBar('Message sent');
      } else {
        _showSnackBar('Failed to send message');
      }
    } catch (e) {
      _showSnackBar('Error sending message: $e');
      print('FXMPP Debug: Send error: $e');
    }
  }

  Future<void> _sendPresence(String show) async {
    final presenceXml = _createPresenceXml(show: show);

    try {
      final success = await _fxmpp.sendPresence(presenceXml);
      if (success) {
        _showSnackBar('Presence sent');
      } else {
        _showSnackBar('Failed to send presence');
      }
    } catch (e) {
      _showSnackBar('Error sending presence: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _connectionStateSubscription?.cancel();
    _messageSubscription?.cancel();
    _presenceSubscription?.cancel();
    _iqSubscription?.cancel();
    _fxmpp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: DefaultTabController(
        length: 5,
        child: Column(
          children: [
            Container(
              color: _connectionState.isConnected
                  ? Colors.green.shade100
                  : _connectionState.hasError
                      ? Colors.red.shade100
                      : Colors.grey.shade100,
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Icon(
                    _connectionState.isConnected
                        ? Icons.wifi
                        : _connectionState.isConnecting
                            ? Icons.wifi_find
                            : Icons.wifi_off,
                    color: _connectionState.isConnected
                        ? Colors.green
                        : _connectionState.hasError
                            ? Colors.red
                            : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Status: ${_connectionState.description}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _connectionState.isConnected
                          ? Colors.green.shade700
                          : _connectionState.hasError
                              ? Colors.red.shade700
                              : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.settings), text: 'Connection'),
                Tab(icon: Icon(Icons.message), text: 'Messages'),
                Tab(icon: Icon(Icons.people), text: 'Presence'),
                Tab(icon: Icon(Icons.help_outline), text: 'IQ'),
                Tab(icon: Icon(Icons.code), text: 'Utils'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildConnectionTab(),
                  _buildMessagesTab(),
                  _buildPresenceTab(),
                  _buildIqTab(),
                  _buildUtilsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _hostController,
            decoration: const InputDecoration(
              labelText: 'Host',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _portController,
            decoration: const InputDecoration(
              labelText: 'Port',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _usernameController,
            decoration: const InputDecoration(
              labelText: 'Username',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _passwordController,
            decoration: const InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _domainController,
            decoration: const InputDecoration(
              labelText: 'Domain',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _connectionState.isConnected ? null : _connect,
                  child: const Text('Connect'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _connectionState.isConnected ? _disconnect : null,
                  child: const Text('Disconnect'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesTab() {
    return Column(
      children: [
        if (_connectionState.isConnected) ...[
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _recipientController,
                  decoration: const InputDecoration(
                    labelText: 'Recipient (e.g., user@domain.com)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          labelText: 'Message',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _sendMessage,
                      child: const Text('Send'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        Expanded(
          child: _messages.isEmpty
              ? const Center(child: Text('No messages yet'))
              : ListView.builder(
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    final from = _getMessageFrom(message);
                    final to = _getMessageTo(message);
                    final body = _getMessageBody(message);
                    final isOutgoing = from.contains(_usernameController.text);

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      child: ListTile(
                        leading: Icon(
                          isOutgoing ? Icons.send : Icons.inbox,
                          color: isOutgoing ? Colors.blue : Colors.green,
                        ),
                        title: Text(
                          isOutgoing ? 'To: $to' : 'From: $from',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(body),
                            const SizedBox(height: 4),
                            Text(
                              DateTime.now().toString().substring(11, 16),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPresenceTab() {
    return Column(
      children: [
        if (_connectionState.isConnected) ...[
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const Text(
                  'Update Your Presence:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ElevatedButton(
                      onPressed: () => _sendPresence('online'),
                      child: const Text('Online'),
                    ),
                    ElevatedButton(
                      onPressed: () => _sendPresence('away'),
                      child: const Text('Away'),
                    ),
                    ElevatedButton(
                      onPressed: () => _sendPresence('dnd'),
                      child: const Text('Do Not Disturb'),
                    ),
                    ElevatedButton(
                      onPressed: () => _sendPresence('xa'),
                      child: const Text('Extended Away'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(),
        ],
        Expanded(
          child: _presences.isEmpty
              ? const Center(child: Text('No presence updates yet'))
              : ListView.builder(
                  itemCount: _presences.length,
                  itemBuilder: (context, index) {
                    final presence = _presences[index];
                    final from = _getPresenceFrom(presence);
                    final show = _getPresenceShow(presence);
                    final status = _getPresenceStatus(presence);

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      child: ListTile(
                        leading: Icon(
                          _getPresenceIcon(show),
                          color: _getPresenceColor(show),
                        ),
                        title: Text(
                          'From: $from',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Status: $show'),
                            if (status.isNotEmpty) Text('Message: $status'),
                            Text(
                              DateTime.now().toString().substring(11, 16),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  IconData _getPresenceIcon(String show) {
    switch (show) {
      case 'online':
        return Icons.circle;
      case 'away':
        return Icons.schedule;
      case 'dnd':
        return Icons.do_not_disturb;
      case 'xa':
        return Icons.schedule_outlined;
      case 'chat':
        return Icons.chat;
      default:
        return Icons.circle;
    }
  }

  Color _getPresenceColor(String show) {
    switch (show) {
      case 'online':
        return Colors.green;
      case 'away':
        return Colors.orange;
      case 'dnd':
        return Colors.red;
      case 'xa':
        return Colors.grey;
      case 'chat':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Widget _buildIqTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed:
                          _connectionState.isConnected ? _sendVersionIq : null,
                      child: const Text('Send Version IQ'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed:
                          _connectionState.isConnected ? _sendTimeIq : null,
                      child: const Text('Send Time IQ'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed:
                    _connectionState.isConnected ? _sendDiscoInfoIq : null,
                child: const Text('Send Disco Info IQ'),
              ),
              //Send Resource Bind IQ
              ElevatedButton(
                onPressed:
                    _connectionState.isConnected ? _sendResourceBindIq : null,
                child: const Text('Send Resource Bind IQ'),
              ),
              // Send Ping IQ (simple test)
              ElevatedButton(
                onPressed: _connectionState.isConnected ? _sendPingIq : null,
                child: const Text('Send Ping IQ'),
              ),
              // Send Roster IQ
              ElevatedButton(
                onPressed: _connectionState.isConnected ? _sendRosterIq : null,
                child: const Text('Get Roster List'),
              ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: _iqs.isEmpty
              ? const Center(child: Text('No IQ stanzas received'))
              : ListView.builder(
                  itemCount: _iqs.length,
                  itemBuilder: (context, index) {
                    final iq = _iqs[index];
                    final type =
                        iq.rootElement.getAttribute('type') ?? 'unknown';
                    final from =
                        iq.rootElement.getAttribute('from') ?? 'unknown';
                    final id = iq.rootElement.getAttribute('id') ?? 'no-id';

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  type == 'result'
                                      ? Icons.check_circle
                                      : type == 'error'
                                          ? Icons.error
                                          : type == 'get'
                                              ? Icons.download
                                              : Icons.upload,
                                  color: type == 'result'
                                      ? Colors.green
                                      : type == 'error'
                                          ? Colors.red
                                          : Colors.blue,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'IQ $type from $from',
                                    style:
                                        Theme.of(context).textTheme.titleSmall,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'ID: $id',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              iq.toXmlString(),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    fontFamily: 'monospace',
                                  ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _sendVersionIq() async {
    try {
      final iq = Fxmpp.createVersionQuery(
        iqId: Fxmpp.generateId('version'),
        fromJid: '${_usernameController.text}@${_domainController.text}',
        toJid: _domainController.text,
      );
      await _fxmpp.sendIq(iq);
      _showSnackBar('Version IQ sent');
    } catch (e) {
      _showSnackBar('Error sending version IQ: $e');
    }
  }

  Future<void> _sendTimeIq() async {
    try {
      final iq = Fxmpp.createTimeQuery(
        iqId: Fxmpp.generateId('time'),
        fromJid: '${_usernameController.text}@${_domainController.text}',
        toJid: _domainController.text,
      );
      await _fxmpp.sendIq(iq);
      _showSnackBar('Time IQ sent');
    } catch (e) {
      _showSnackBar('Error sending time IQ: $e');
    }
  }

  Future<void> _sendDiscoInfoIq() async {
    try {
      final iq = Fxmpp.createDiscoInfoQuery(
        iqId: Fxmpp.generateId('disco'),
        fromJid: '${_usernameController.text}@${_domainController.text}',
        toJid: _domainController.text,
      );
      await _fxmpp.sendIq(iq);
      _showSnackBar('Disco Info IQ sent');
    } catch (e) {
      _showSnackBar('Error sending disco info IQ: $e');
    }
  }

  Future<void> _sendResourceBindIq() async {
    try {
      final iq = _createIqBindResourceXml(
          'set', _domainController.text, 'Mobile',
          queryNamespace: 'urn:ietf:params:xml:ns:xmpp-bind');
      await _fxmpp.sendIq(iq);
      _showSnackBar('Resource Bind IQ sent');
    } catch (e) {
      _showSnackBar('Error sending resource bind IQ: $e');
    }
  }

  Future<void> _sendPingIq() async {
    try {
      // Create a custom ping IQ using the general createIq method
      final pingBuilder = XmlBuilder();
      pingBuilder.element('ping', attributes: {
        'xmlns': 'urn:xmpp:ping',
      });
      final pingElement = pingBuilder.buildFragment().firstChild as XmlElement;

      final iq = Fxmpp.createIq(
        iqId: Fxmpp.generateId('ping'),
        type: IqType.get,
        fromJid: '${_usernameController.text}@${_domainController.text}',
        toJid: _domainController.text,
        queryElement: pingElement,
      );

      log('FXMPP Debug: Ping IQ XML: ${iq.toXmlString()}');
      await _fxmpp.sendIq(iq);
      _showSnackBar('Ping IQ sent');
    } catch (e) {
      _showSnackBar('Error sending ping IQ: $e');
    }
  }

  Future<void> _sendRosterIq() async {
    try {
      // Create a roster query using the general createIq method
      final rosterBuilder = XmlBuilder();
      rosterBuilder.element('query', attributes: {
        'xmlns': 'jabber:iq:roster',
      });
      final rosterElement =
          rosterBuilder.buildFragment().firstChild as XmlElement;

      final iq = Fxmpp.createIq(
        iqId: Fxmpp.generateId('roster'),
        type: IqType.get,
        fromJid: '${_usernameController.text}@${_domainController.text}',
        toJid: _domainController.text,
        queryElement: rosterElement,
      );

      log('FXMPP Debug: Roster IQ XML: ${iq.toXmlString()}');
      await _fxmpp.sendIq(iq);
      _showSnackBar('Roster IQ sent');
    } catch (e) {
      _showSnackBar('Error sending roster IQ: $e');
    }
  }

  Widget _buildUtilsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FXMPP Utility Methods',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),

          // Message Creation Example
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create Message Stanza',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Instead of manually building XML, use:',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '''final message = Fxmpp.createMessage(
  messageId: Fxmpp.generateId('msg'),
  type: MessageType.chat,
  fromJid: 'user@domain.com',
  toJid: 'friend@domain.com',
  content: 'Hello, World!',
  subject: 'Optional subject',
  thread: 'conversation-123',
);''',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _connectionState.isConnected
                        ? () {
                            final demoMessage = Fxmpp.createMessage(
                              messageId: Fxmpp.generateId('demo'),
                              type: MessageType.chat,
                              fromJid:
                                  '${_usernameController.text}@${_domainController.text}',
                              toJid: _recipientController.text.isNotEmpty
                                  ? _recipientController.text
                                  : 'demo@${_domainController.text}',
                              content:
                                  'Demo message created with utility method!',
                              subject: 'Demo Subject',
                            );
                            _fxmpp.sendMessage(demoMessage);
                            _showSnackBar(
                                'Demo message sent using utility method');
                          }
                        : null,
                    child: const Text('Send Demo Message'),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Presence Creation Example
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create Presence Stanza',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '''final presence = Fxmpp.createPresence(
  presenceId: Fxmpp.generateId('pres'),
  type: PresenceType.available,
  fromJid: 'user@domain.com',
  show: PresenceShow.dnd,
  status: 'Busy working on FXMPP',
  priority: 5,
);''',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ElevatedButton(
                        onPressed: _connectionState.isConnected
                            ? () {
                                final demoPresence = Fxmpp.createPresence(
                                  presenceId: Fxmpp.generateId('demo'),
                                  type: PresenceType.available,
                                  fromJid:
                                      '${_usernameController.text}@${_domainController.text}',
                                  show: PresenceShow.chat,
                                  status:
                                      'Available for chat via utility method!',
                                  priority: 10,
                                );
                                _fxmpp.sendPresence(demoPresence);
                                _showSnackBar('Demo presence sent');
                              }
                            : null,
                        child: const Text('Chat Status'),
                      ),
                      ElevatedButton(
                        onPressed: _connectionState.isConnected
                            ? () {
                                final demoPresence = Fxmpp.createPresence(
                                  presenceId: Fxmpp.generateId('demo'),
                                  type: PresenceType.available,
                                  fromJid:
                                      '${_usernameController.text}@${_domainController.text}',
                                  show: PresenceShow.dnd,
                                  status:
                                      'Do not disturb - using utility methods!',
                                  priority: 0,
                                );
                                _fxmpp.sendPresence(demoPresence);
                                _showSnackBar('DND presence sent');
                              }
                            : null,
                        child: const Text('DND Status'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // IQ Creation Example
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create IQ Stanzas',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '''// Built-in IQ queries
final versionIq = Fxmpp.createVersionQuery(
  iqId: Fxmpp.generateId('version'),
  fromJid: 'user@domain.com',
  toJid: 'server.com',
);

final timeIq = Fxmpp.createTimeQuery(
  iqId: Fxmpp.generateId('time'),
  fromJid: 'user@domain.com',
  toJid: 'server.com',
);

final discoIq = Fxmpp.createDiscoInfoQuery(
  iqId: Fxmpp.generateId('disco'),
  fromJid: 'user@domain.com',
  toJid: 'server.com',
);''',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ElevatedButton(
                        onPressed: _connectionState.isConnected
                            ? () {
                                final versionIq = Fxmpp.createVersionQuery(
                                  iqId: Fxmpp.generateId('demo_version'),
                                  fromJid:
                                      '${_usernameController.text}@${_domainController.text}',
                                  toJid: _domainController.text,
                                );
                                _fxmpp.sendIq(versionIq);
                                _showSnackBar('Version query sent via utility');
                              }
                            : null,
                        child: const Text('Version'),
                      ),
                      ElevatedButton(
                        onPressed: _connectionState.isConnected
                            ? () {
                                final timeIq = Fxmpp.createTimeQuery(
                                  iqId: Fxmpp.generateId('demo_time'),
                                  fromJid:
                                      '${_usernameController.text}@${_domainController.text}',
                                  toJid: _domainController.text,
                                );
                                _fxmpp.sendIq(timeIq);
                                _showSnackBar('Time query sent via utility');
                              }
                            : null,
                        child: const Text('Time'),
                      ),
                      ElevatedButton(
                        onPressed: _connectionState.isConnected
                            ? () {
                                final discoIq = Fxmpp.createDiscoInfoQuery(
                                  iqId: Fxmpp.generateId('demo_disco'),
                                  fromJid:
                                      '${_usernameController.text}@${_domainController.text}',
                                  toJid: _domainController.text,
                                );
                                _fxmpp.sendIq(discoIq);
                                _showSnackBar(
                                    'Disco info query sent via utility');
                              }
                            : null,
                        child: const Text('Disco Info'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ID Generation Example
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ID Generation',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '''// Generate unique IDs for stanzas
final id1 = Fxmpp.generateId(); // Default prefix
final id2 = Fxmpp.generateId('custom'); // Custom prefix''',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      final id1 = Fxmpp.generateId();
                      final id2 = Fxmpp.generateId('demo');
                      _showSnackBar('Generated IDs: $id1, $id2');
                    },
                    child: const Text('Generate Sample IDs'),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Benefits Section
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Benefits of Utility Methods',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('✓ No manual XML construction'),
                  const Text('✓ Type-safe stanza creation'),
                  const Text('✓ Automatic ID generation'),
                  const Text('✓ Proper XMPP namespace handling'),
                  const Text('✓ Reduced boilerplate code'),
                  const Text('✓ Built-in validation'),
                  const Text('✓ Consistent stanza formatting'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
