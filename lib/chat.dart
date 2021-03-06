import 'package:flutter/material.dart';
import 'package:kuzzle/kuzzle.dart';
import 'chat_view.dart';
import 'message.dart';

class Chat extends StatelessWidget {
  final String username;

  const Chat(this.username);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chat app',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: ChatPage(title: 'Chat app', username: username),
    );
  }
}

class ChatPage extends StatefulWidget {
  const ChatPage({Key? key, required this.title, required this.username})
      : super(key: key);

  final String title;
  final String username;

  @override
  _ChatPage createState() => _ChatPage();
}

class _ChatPage extends State<ChatPage> {
  late Kuzzle _kuzzle;
  List<Message> _messages = [];
  late String _roomId;
  final _chatController = TextEditingController();

  @override
  void dispose() {
    _chatController.dispose();
    _kuzzle.realtime.unsubscribe(_roomId);
    super.dispose();
  }

  @override
  void initState() {
    _kuzzle = Kuzzle(WebSocketProtocol(Uri(
      scheme: 'ws',
      host: 'localhost',
      port: 7512,
    )));
    // Etablish the connection
    _kuzzle.connect().then((_) {
      _initData();
      _fetchMessages();
      _subscribeToNewMessages();
    });
    super.initState();
  }

  void _initData() async {
    // Check if 'chat' index exists
    if (!(await _kuzzle.index.exists('chat'))) {
      // If not, create 'chat' index and 'messages' collection
      await _kuzzle.index.create('chat');
      await _kuzzle.collection.create('chat', 'messages');
    }
  }

  void _fetchMessages() async {
    // Call the search method of the document controller
    final results = await _kuzzle.document.search(
      'chat', // Name of the index
      'messages', // Name of the collection
      query: {
        'sort': {
          '_kuzzle_info.createdAt': {'order': 'asc'}
        }
      }, // Query => Sort the messages by creation date
      size: 100, // Options => get a maximum of 100 messages
    );
    // Add messages to our array after formating them
    setState(() {
      _messages =
          results.hits!.map((message) => Message.fromJson(message)).toList();
    });
  }

  void _subscribeToNewMessages() async {
    // Call the subscribe method of the realtime controller and receive the roomId
    // Save the id of our subscription (we could need it to unsubscribe)
    _roomId = await _kuzzle.realtime.subscribe(
        'chat', // Name of the index
        'messages', // Name of the collection
        {}, // Filter
        (notification) {
      if (notification.action != 'create') return;
      if (notification.controller != 'document') return;
      setState(() {
        _messages.add(Message.fromJson(notification.result));
      });
    }, subscribeToSelf: true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
        ),
        body: Center(
          child: Column(
            children: <Widget>[
              Expanded(
                child: SizedBox(
                  width: double.infinity,
                  child: ChatView(
                    messages: _messages,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Form(
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: TextField(
                            controller: _chatController,
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          await _kuzzle.document.create('chat', 'messages', {
                            'username': widget.username,
                            'value': _chatController.text
                          });
                          _chatController.clear();
                        },
                        child: const Icon(Icons.send),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}
