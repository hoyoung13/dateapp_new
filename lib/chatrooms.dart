import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../constants.dart';
import 'chat.dart'; // 개별 채팅 화면으로 이동할 때 필요

class ChatRoomsPage extends StatefulWidget {
  final int userId;
  const ChatRoomsPage({Key? key, required this.userId}) : super(key: key);

  @override
  _ChatRoomsPageState createState() => _ChatRoomsPageState();
}

class _ChatRoomsPageState extends State<ChatRoomsPage> {
  bool _loading = true;
  String? _error;
  List<ChatRoom> _rooms = [];

  @override
  void initState() {
    super.initState();
    _fetchRooms();
  }

  Future<void> _fetchRooms() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await http.get(
        Uri.parse('$BASE_URL/chat/rooms/user/${widget.userId}'),
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final rows = data['rooms'] as List<dynamic>;
        _rooms = rows.map((r) => ChatRoom.fromJson(r)).toList();
      } else {
        _error = '조회 실패: ${res.statusCode}';
      }
    } catch (e) {
      _error = '오류: $e';
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('채팅 목록'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView.separated(
                  itemCount: _rooms.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final room = _rooms[i];

                    final sentAt = room.lastMessageAt?.toLocal();
                    String timeStr = '';
                    if (sentAt != null) {
                      final now = DateTime.now();
                      final diff = now.difference(sentAt);

                      if (diff.inDays == 0 && sentAt.day == now.day) {
                        // 오늘 보낸 메시지
                        timeStr = DateFormat('HH:mm').format(sentAt);
                      } else if (diff.inDays == 1 ||
                          (diff.inDays == 0 && now.day - sentAt.day == 1)) {
                        // 어제 보낸 메시지
                        timeStr = '하루 전';
                      } else {
                        // 그 이전 (월·일 표시)
                        timeStr = DateFormat('M월 d일').format(sentAt);
                      }
                    }

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        // 예시: roomName의 앞 글자를 찍어줍니다. 실제로는 프로필 URL을 넣으세요.
                        child: Text(room.roomName.substring(0, 1)),
                      ),
                      title: Text(
                        room.roomName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        room.lastMessageText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (timeStr.isNotEmpty)
                            Text(
                              timeStr,
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 12),
                            ),
                          const SizedBox(height: 4),
                          if (room.unreadCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                room.unreadCount > 99
                                    ? '99+'
                                    : room.unreadCount.toString(),
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatPage(
                              roomId: room.roomId,
                              peerName: room.roomName,
                              userId: widget.userId, // ← 여기에 인자 추가
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}

/// chatRoomsController.listUserRooms의 결과를 매핑할 모델
// lib/models/chat_room.dart

class ChatRoom {
  final int roomId;
  final String roomName; // 상대 닉네임
  final String lastMessageText; // 마지막 보내진 메시지 요약
  final DateTime? lastMessageAt; // 마지막 메시지 시간
  final int unreadCount; // 읽지 않은 메시지 개수

  ChatRoom({
    required this.roomId,
    required this.roomName,
    required this.lastMessageText,
    this.lastMessageAt,
    this.unreadCount = 0,
  });

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    return ChatRoom(
      roomId: json['room_id'] as int,
      roomName: json['room_name'] as String? ?? '이름 없음',
      lastMessageText: json['last_message'] as String? ?? '',
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'] as String)
          : null,
      unreadCount: json['unread_count'] as int? ?? 0,
    );
  }
}
