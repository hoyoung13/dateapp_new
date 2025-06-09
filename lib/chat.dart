// chat.dart
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'constants.dart';
import 'user_provider.dart';
import 'chat_message.dart';

class ChatPage extends StatefulWidget {
  final int roomId;
  final String peerName;
  final int userId; // ← 추가

  const ChatPage({
    Key? key,
    required this.roomId,
    required this.peerName,
    required this.userId,
  }) : super(key: key);
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  late Timer _poller;

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
    _poller =
        Timer.periodic(const Duration(seconds: 2), (_) => _loadChatHistory());
  }

  @override
  void dispose() {
    _poller.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadChatHistory() async {
    final resp = await http.get(
      Uri.parse('$BASE_URL/chat/rooms/${widget.roomId}/messages'),
    );
    if (resp.statusCode == 200) {
      final data = json.decode(resp.body);
      setState(() {
        _messages = List<Map<String, dynamic>>.from(data['messages']);
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    }
  }

  Future<void> _sendMessage() async {
    final content = _textController.text.trim();
    if (content.isEmpty) return;
    final me = Provider.of<UserProvider>(context, listen: false).userId!;
    final msg = ChatMessage.text(senderId: me, content: content);
    final payload = msg.toJson();
    final resp = await http.post(
      Uri.parse('$BASE_URL/chat/rooms/${widget.roomId}/messages'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(payload),
    );
    if (resp.statusCode == 201) {
      _textController.clear();
      _loadChatHistory();
    }
  }

  Future<void> _pickAndSendPlace() async {
    // (위에 예시 구현하셨던 대로)
  }
  Future<void> _pickAndSendCourse() async {
    // (위에 예시 구현하셨던 대로)
  }

  @override
  Widget build(BuildContext context) {
    final me = Provider.of<UserProvider>(context, listen: false).userId;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.peerName),
        backgroundColor: Colors.cyan[100],
        iconTheme: const IconThemeData(color: Colors.black),
        foregroundColor: Colors.black,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];

                // 이 부분이 핵심입니다!
                final isMine = msg['sender_id'] == me;

                return Align(
                  alignment:
                      isMine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      color: isMine ? Colors.cyan[100] : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: isMine
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        // 내 메시지가 아니면 보낸 사람 닉네임 표시
                        if (!isMine)
                          Text(
                            msg['sender_nickname'],
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 12),
                          ),

                        // 본문
                        Text(msg['content']),

                        // 보낸 시간
                        Text(
                          msg['sent_at'],
                          style:
                              const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // 입력창 + 버튼
          SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: _pickAndSendPlace,
                    icon: const Icon(Icons.place, size: 20),
                    label: const Text('장소 전송'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: _pickAndSendCourse,
                    icon: const Icon(Icons.map, size: 20),
                    label: const Text('코스 전송'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: const InputDecoration(
                        hintText: '메시지 입력...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(8),
                            bottomLeft: Radius.circular(8),
                          ),
                        ),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ),
                  Material(
                    color: Colors.cyan[100],
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(8),
                        bottomRight: Radius.circular(8),
                      ),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
