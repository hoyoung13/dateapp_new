// chat.dart
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'constants.dart';
import 'user_provider.dart';
import 'chat_message.dart';
import 'course_detail_loader.dart';
import 'zzimlist.dart';
import 'selectplace.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'zzimdetail.dart';
import 'chat_course_card.dart';
import 'chat_collection_card.dart';
import 'chat_place_card.dart';
import 'package:intl/intl.dart';
import 'theme_colors.dart';

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
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userId = userProvider.userId;
    final nickname = userProvider.nickname ?? '';
    if (userId == null) return;

    Future<List<dynamic>> fetchPlaces() async {
      final resp = await http.get(Uri.parse('$BASE_URL/places'));
      if (resp.statusCode == 200) {
        return json.decode(resp.body) as List<dynamic>;
      }
      return [];
    }

    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return FutureBuilder<List<dynamic>>(
          future: fetchPlaces(),
          builder: (c, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final places = snap.data ?? [];
            if (places.isEmpty) {
              return const SizedBox(
                height: 200,
                child: Center(child: Text('장소가 없습니다.')),
              );
            }
            return SizedBox(
              height: 400,
              child: ListView.builder(
                itemCount: places.length,
                itemBuilder: (c, i) {
                  final p = places[i];
                  return ListTile(
                    title: Text(p['place_name'] ?? ''),
                    onTap: () => Navigator.pop(c, p as Map<String, dynamic>),
                  );
                },
              ),
            );
          },
        );
      },
    );

    if (selected == null) return;

    final placeId = selected['id'];
    final placeName = selected['place_name'] ?? '';

    final resp = await http.post(
      Uri.parse('$BASE_URL/chat/rooms/${widget.roomId}/messages'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'sender_id': userId,
        'type': 'place',
        'place_id': placeId,
        'content': '${nickname}님이 $placeName 장소를 공유했습니다.',
      }),
    );

    if (resp.statusCode == 200 || resp.statusCode == 201) {
      _loadChatHistory();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('장소 전송 실패')),
      );
    }
  }

  Future<void> _pickAndSendCourse() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userId = userProvider.userId;
    final nickname = userProvider.nickname ?? '';
    if (userId == null) return;

    Future<List<dynamic>> fetchCourses() async {
      final resp = await http.get(Uri.parse('$BASE_URL/course/allcourse'));
      if (resp.statusCode == 200) {
        final decoded = json.decode(resp.body) as Map<String, dynamic>;
        return decoded['courses'] as List<dynamic>;
      }
      return [];
    }

    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return FutureBuilder<List<dynamic>>(
          future: fetchCourses(),
          builder: (c, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final courses = snap.data ?? [];
            if (courses.isEmpty) {
              return const SizedBox(
                height: 200,
                child: Center(child: Text('코스가 없습니다.')),
              );
            }
            return SizedBox(
              height: 400,
              child: ListView.builder(
                itemCount: courses.length,
                itemBuilder: (c, i) {
                  final course = courses[i];
                  final name =
                      course['courseName'] ?? course['course_name'] ?? '';

                  return ListTile(
                    title: Text(name),
                    onTap: () =>
                        Navigator.pop(c, course as Map<String, dynamic>),
                  );
                },
              ),
            );
          },
        );
      },
    );

    if (selected == null) return;

    final courseId = selected['id'];
    final name = selected['courseName'] ?? selected['course_name'] ?? '';

    final resp = await http.post(
      Uri.parse('$BASE_URL/chat/rooms/${widget.roomId}/messages'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'sender_id': userId,
        'type': 'course',
        'course_id': courseId,
        'content': '${nickname}님이 $name 코스를 공유했습니다.',
      }),
    );

    if (resp.statusCode == 200 || resp.statusCode == 201) {
      _loadChatHistory();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('코스 전송 실패')),
      );
    }
  }

  Future<void> _pickAndSendPhoto() async {
    // TODO: implement photo sending logic
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;
    final request =
        http.MultipartRequest('POST', Uri.parse('$BASE_URL/chat/upload-image'));
    request.files
        .add(await http.MultipartFile.fromPath('image', pickedFile.path));

    final resp = await request.send();
    if (resp.statusCode != 200) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('이미지 업로드 실패')));
      return;
    }
    final body = await resp.stream.bytesToString();
    final data = json.decode(body) as Map<String, dynamic>;
    final imageUrl = data['image_url'];
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userId = userProvider.userId;
    if (userId == null) return;

    await http.post(
      Uri.parse('$BASE_URL/chat/rooms/${widget.roomId}/messages'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'sender_id': userId,
        'type': 'image',
        'image_url': imageUrl,
      }),
    );
    _loadChatHistory();
  }

  Future<void> _pickAndSendZzim() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userId = userProvider.userId;
    final nickname = userProvider.nickname ?? '';
    if (userId == null) return;

    Map<String, dynamic>? result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ZzimListDialog(userId: userId),
    );

    if (result == null) return;

    if (!result.containsKey('place_name')) {
      result = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (_) => SelectplacePage(collection: result!),
        ),
      );
      if (result == null) return;
    }

    final placeId = result['id'];
    final placeName = result['place_name'] ?? '';

    final resp = await http.post(
      Uri.parse('$BASE_URL/chat/rooms/${widget.roomId}/messages'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'sender_id': userId,
        'type': 'place',
        'place_id': placeId,
        'content': '${nickname}님이 $placeName 장소를 공유했습니다.',
      }),
    );

    if (resp.statusCode == 200 || resp.statusCode == 201) {
      _loadChatHistory();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('장소 전송 실패')),
      );
    }
  }

  Future<void> _pickAndSendCollection() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userId = userProvider.userId;
    final nickname = userProvider.nickname ?? '';
    if (userId == null) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ZzimListDialog(userId: userId),
    );

    if (result == null) return;

    final collId = result['id'];
    final collName = result['collection_name'] ?? '';

    final resp = await http.post(
      Uri.parse('$BASE_URL/chat/rooms/${widget.roomId}/messages'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'sender_id': userId,
        'type': 'collection',
        'collection_id': collId,
        'content': '${nickname}님이 $collName 컬렉션을 공유했습니다.',
      }),
    );

    if (resp.statusCode == 200 || resp.statusCode == 201) {
      _loadChatHistory();
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('컬렉션 전송 실패')));
    }
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo),
                title: const Text('사진'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndSendPhoto();
                },
              ),
              ListTile(
                leading: const Icon(Icons.map),
                title: const Text('코스'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndSendCourse();
                },
              ),
              ListTile(
                leading: const Icon(Icons.collections_bookmark),
                title: const Text('컬렉션'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndSendCollection();
                },
              ),
              ListTile(
                leading: const Icon(Icons.favorite),
                title: const Text('찜목록'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndSendZzim();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = Provider.of<UserProvider>(context, listen: false).userId;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.peerName),
        backgroundColor: AppColors.accentLight,
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

                final sentAt = DateTime.parse(msg['sent_at']).toLocal();
                final prevSentAt = index > 0
                    ? DateTime.parse(_messages[index - 1]['sent_at']).toLocal()
                    : null;
                final showDateHeader = prevSentAt == null ||
                    sentAt.year != prevSentAt.year ||
                    sentAt.month != prevSentAt.month ||
                    sentAt.day != prevSentAt.day;

                final isTextMsg = msg['image_url'] == null &&
                    msg['place_id'] == null &&
                    msg['course_id'] == null &&
                    msg['collection_id'] == null;

                final messageBubble = Align(
                  alignment:
                      isMine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: isTextMsg
                        ? BoxDecoration(
                            color: isMine
                                ? AppColors.accentLight
                                : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                          )
                        : null,
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
                        if (msg['image_url'] != null)
                          Image.network(
                            msg['image_url'].toString().startsWith('http')
                                ? msg['image_url']
                                : '$BASE_URL${msg['image_url']}',
                            width: 200,
                          )
                        else if (msg['place_id'] != null)
                          ChatPlaceCard(
                            placeId: msg['place_id'],
                            fallbackText: msg['content'] ?? '',
                          )
                        else if (msg['course_id'] != null)
                          ChatCourseCard(courseId: msg['course_id'])
                        else if (msg['collection_id'] != null)
                          ChatCollectionCard(
                              collectionId: msg['collection_id'],
                              senderId: msg['sender_id'])
                        else
                          Text(msg['content'] ?? ''),
                        // 보낸 시간
                        Text(
                          DateFormat('HH:mm').format(sentAt),
                          style:
                              const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                );
                if (showDateHeader) {
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          DateFormat('yyyy년 M월 d일').format(sentAt),
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                      messageBubble,
                    ],
                  );
                }
                return messageBubble;
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
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _showAttachmentMenu,
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
                    color: AppColors.accentLight,
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
