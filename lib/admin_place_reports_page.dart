import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'constants.dart';
import 'chat.dart';
import 'package:provider/provider.dart';
import 'user_provider.dart';

class AdminPlaceReportsPage extends StatefulWidget {
  const AdminPlaceReportsPage({Key? key}) : super(key: key);

  @override
  State<AdminPlaceReportsPage> createState() => _AdminPlaceReportsPageState();
}

class _AdminPlaceReportsPageState extends State<AdminPlaceReportsPage> {
  Future<List<dynamic>>? _future;
  int? _adminId;

  @override
  void initState() {
    super.initState();
    _adminId = Provider.of<UserProvider>(context, listen: false).userId ?? 8;

    _future = _loadReports();
  }

  Future<List<dynamic>> _loadReports() async {
    final uri = Uri.parse('$BASE_URL/admin/place-reports');
    final resp = await http.get(uri, headers: {
      'Content-Type': 'application/json',
      'user_id': '${_adminId}'
    });
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      return data['reports'] as List<dynamic>;
    }
    throw Exception('failed');
  }

  Future<void> _update(int id, {bool deletePlace = false}) async {
    final uri = Uri.parse('$BASE_URL/admin/place-reports/$id');
    await http.patch(uri,
        headers: {'Content-Type': 'application/json', 'user_id': '${_adminId}'},
        body: jsonEncode({'status': 'resolved', 'delete_place': deletePlace}));
    setState(() {
      _future = _loadReports();
    });
  }

  Future<void> _startChat(int userId, String nickname) async {
    final resp = await http.post(Uri.parse('$BASE_URL/chat/rooms/1on1'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userA': _adminId, 'userB': userId}));
    if (resp.statusCode == 200) {
      final roomId = jsonDecode(resp.body)['roomId'] as int;
      if (!mounted) return;
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ChatPage(
                  roomId: roomId, peerName: nickname, userId: _adminId ?? 0)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('장소 신고 관리')),
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('신고 내역이 없습니다.'));
          }
          final items = snapshot.data!;
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index] as Map<String, dynamic>;
              return ListTile(
                title: Text(item['place_name'] ?? ''),
                subtitle: Text(item['reason'] ?? ''),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chat),
                      onPressed: () => _startChat(
                          item['user_id'], item['reporter_nickname']),
                    ),
                    IconButton(
                      icon: const Icon(Icons.check),
                      onPressed: () => _update(item['id']),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _update(item['id'], deletePlace: true),
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
}
