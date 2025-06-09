import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'constants.dart';
import 'user_provider.dart';
import 'chat.dart';

class FriPage extends StatefulWidget {
  const FriPage({Key? key}) : super(key: key);
  @override
  _FriPageState createState() => _FriPageState();
}

class _FriPageState extends State<FriPage> {
  late Future<List<dynamic>> _friendsFuture;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  void _loadFriends() {
    final userId = Provider.of<UserProvider>(context, listen: false).userId;
    _friendsFuture = _fetchFriends(userId!);
  }

  Future<List<dynamic>> _fetchFriends(int userId) async {
    final resp = await http.get(Uri.parse('$BASE_URL/fri/friends/$userId'));
    if (resp.statusCode != 200) return [];
    final json = jsonDecode(resp.body);
    return json['friends'];
  }

  Future<void> _deleteFriend(int friendId) async {
    final userId = Provider.of<UserProvider>(context, listen: false).userId!;
    await http.delete(Uri.parse('$BASE_URL/fri/$userId/$friendId'));
    _loadFriends();
    setState(() {});
  }

  void _openChat(int friendId, String friendNick) async {
    final me = Provider.of<UserProvider>(context, listen: false).userId;
    if (me == null) return;

    final resp = await http.post(
      Uri.parse('$BASE_URL/chat/rooms/1on1'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'userA': me, 'userB': friendId}),
    );

    if (resp.statusCode == 200) {
      final roomId = json.decode(resp.body)['roomId'] as int;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ChatPage(roomId: roomId, peerName: friendNick, userId: me),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('채팅방 생성/조회 실패: ${resp.statusCode}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.cyan[100],
        title: const Text('친구 관리', style: TextStyle(color: Colors.black)),
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          TextButton(
            onPressed: () => _showAddFriendDialog(context),
            child: const Text('친구 추가', style: TextStyle(color: Colors.black)),
          ),
          TextButton(
            onPressed: () => _showRequestManagementDialog(context),
            child: const Text('신청 관리', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _friendsFuture,
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done)
            return const Center(child: CircularProgressIndicator());
          final friends = snap.data ?? [];
          if (friends.isEmpty) {
            return const Center(
              child: Text(
                '친구 목록이 없습니다.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }
          return ListView.separated(
            itemCount: friends.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (ctx, i) {
              final f = friends[i];
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: f['profile_image'] != null
                      ? NetworkImage(f['profile_image'])
                      : null,
                  child: f['profile_image'] == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                title: Text(f['nickname']),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chat_bubble_outline),
                      onPressed: () => _openChat(f['id'], f['nickname']),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _deleteFriend(f['id']),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddFriendDialog(BuildContext context) {
    final TextEditingController _nickController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('친구 추가'),
          content: TextField(
            controller: _nickController,
            decoration: const InputDecoration(
              labelText: '친구 닉네임 입력',
              hintText: '상대방 닉네임을 입력하세요',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('취소'),
            ),
            ElevatedButton(
              // AlertDialog 안의 “신청” 버튼 onPressed 예시
              onPressed: () async {
                final nick = _nickController.text.trim();
                if (nick.isEmpty) {
                  Navigator.of(ctx).pop(); // 다이얼로그 닫기
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('닉네임을 입력해주세요.')));
                  return;
                }

                Navigator.of(ctx).pop(); // 다이얼로그 닫고
                // (선택) 로딩 인디케이터 띄우기…

                try {
                  // 1) 닉네임으로 사용자 조회
                  final userResp = await http.get(
                    Uri.parse('$BASE_URL/fri/search?nickname=$nick'),
                  );
                  print(
                      '🔍 GET /fri/search?nickname=$nick → ${userResp.statusCode}, body=${userResp.body}');

                  if (userResp.statusCode == 404) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('사용자를 찾을 수 없습니다.')));
                    return;
                  }
                  if (userResp.statusCode != 200) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('서버 오류: ${userResp.statusCode}')));
                    return;
                  }
                  final userJson = json.decode(userResp.body);
                  final recipientId = userJson['id'] as int?;

                  // 2) 내 아이디 가져오기
                  final userProvider =
                      Provider.of<UserProvider>(context, listen: false);
                  final requesterId = userProvider.userId;
                  if (requesterId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('로그인 정보가 없습니다.')));
                    return;
                  }

                  // 3) 친구 요청 보내기
                  final reqResp = await http.post(
                    Uri.parse('$BASE_URL/fri'),
                    headers: {'Content-Type': 'application/json'},
                    body: json.encode({
                      'requesterId': requesterId,
                      'recipientId': recipientId,
                    }),
                  );
                  if (reqResp.statusCode == 201) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('친구 요청을 보냈습니다.')));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('요청 실패: ${reqResp.statusCode}')));
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('네트워크 오류: $e')));
                }
              },

              child: const Text('신청'),
            ),
          ],
        );
      },
    );
  }

  void _showRequestManagementDialog(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final int? me = userProvider.userId;
    if (me == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 정보가 없습니다.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return DefaultTabController(
          length: 2,
          child: AlertDialog(
            title: const Text('신청 관리'),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: Column(
                children: [
                  const TabBar(tabs: [
                    Tab(text: '받은 요청'),
                    Tab(text: '신청 목록'),
                  ]),
                  Expanded(
                    child: TabBarView(children: [
                      // ─── 받은 요청 탭 ─────────────────────────
                      FutureBuilder<List<dynamic>>(
                        future: _fetchReceived(ctx, me),
                        builder: (ctx, snap) {
                          if (snap.connectionState != ConnectionState.done)
                            return const Center(
                                child: CircularProgressIndicator());
                          final recs = snap.data ?? [];
                          if (recs.isEmpty)
                            return const Center(child: Text('받은 요청이 없습니다.'));
                          return ListView.builder(
                            itemCount: recs.length,
                            itemBuilder: (c, i) {
                              final r = recs[i];
                              return ListTile(
                                title: Text(r['requester_nickname']),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextButton(
                                      onPressed: () async {
                                        await _acceptRequest(r['id']);
                                        Navigator.of(ctx).pop();
                                        _showRequestManagementDialog(context);
                                      },
                                      child: const Text('확인'),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        await _rejectRequest(r['id']);
                                        Navigator.of(ctx).pop();
                                        _showRequestManagementDialog(context);
                                      },
                                      child: const Text('삭제',
                                          style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                      // ─── 신청 목록 탭 ─────────────────────────
                      FutureBuilder<List<dynamic>>(
                        future: _fetchSent(ctx, me),
                        builder: (ctx, snap) {
                          if (snap.connectionState != ConnectionState.done)
                            return const Center(
                                child: CircularProgressIndicator());
                          final sent = snap.data ?? [];
                          if (sent.isEmpty)
                            return const Center(child: Text('신청한 내역이 없습니다.'));
                          return ListView.builder(
                            itemCount: sent.length,
                            itemBuilder: (c, i) {
                              final r = sent[i];
                              final status =
                                  r['status']; // pending, accepted, rejected
                              return ListTile(
                                title: Text(r['recipient_nickname']),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      status == 'pending'
                                          ? '대기중'
                                          : status == 'accepted'
                                              ? '수락됨'
                                              : '거절됨',
                                      style: TextStyle(
                                        color: status == 'pending'
                                            ? Colors.grey
                                            : status == 'accepted'
                                                ? Colors.green
                                                : Colors.red,
                                      ),
                                    ),
                                    if (status == 'pending')
                                      IconButton(
                                        icon: const Icon(Icons.cancel,
                                            color: Colors.grey),
                                        onPressed: () async {
                                          await _rejectRequest(r['id']);
                                          Navigator.of(ctx).pop();
                                          _showRequestManagementDialog(context);
                                        },
                                      ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ]),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('닫기')),
            ],
          ),
        );
      },
    );
  }

  Future<List<dynamic>> _fetchReceived(BuildContext ctx, int me) async {
    final resp = await http.get(Uri.parse('$BASE_URL/fri/pending/$me'));
    if (resp.statusCode != 200) return [];
    final json = jsonDecode(resp.body);
    return (json['requests'] as List);
  }

  Future<List<dynamic>> _fetchSent(BuildContext ctx, int me) async {
    final resp = await http.get(Uri.parse('$BASE_URL/fri/sent/$me'));
    if (resp.statusCode != 200) return [];
    final json = jsonDecode(resp.body);
    return (json['requests'] as List);
  }

  Future<void> _acceptRequest(int id) async {
    await http.post(Uri.parse('$BASE_URL/fri/$id/accept'));
  }

  Future<void> _rejectRequest(int id) async {
    await http.post(Uri.parse('$BASE_URL/fri/$id/reject'));
  }
}
