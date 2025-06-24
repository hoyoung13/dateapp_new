import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'constants.dart';
import 'chat.dart';
import 'package:provider/provider.dart';
import 'user_provider.dart';
import 'place_report.dart';
import 'auth_helper.dart';

class AdminPlaceReportsPage extends StatefulWidget {
  const AdminPlaceReportsPage({Key? key}) : super(key: key);

  @override
  State<AdminPlaceReportsPage> createState() => _AdminPlaceReportsPageState();
}

class _AdminPlaceReportsPageState extends State<AdminPlaceReportsPage> {
  Future<List<PlaceReport>>? _future;
  int? _adminId;

  @override
  void initState() {
    super.initState();
    _adminId = Provider.of<UserProvider>(context, listen: false).userId ?? 8;

    _future = _loadReports();
  }

  Future<List<PlaceReport>> _loadReports() async {
    final uri = Uri.parse('$BASE_URL/admin/place-reports');
    final headers = await AuthHelper.authHeaders(userId: _adminId);
    final resp = await http.get(uri, headers: headers);
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final list = data['reports'] as List<dynamic>;
      return list
          .map((e) => PlaceReport.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception('failed');
  }

  Future<void> _update(int id, String msg, {bool deletePlace = false}) async {
    final uri = Uri.parse('$BASE_URL/admin/place-reports/$id');
    final headers = await AuthHelper.authHeaders(userId: _adminId);

    await http.patch(uri,
        headers: headers,
        body: jsonEncode({'delete_place': deletePlace, 'message': msg}));
    setState(() {
      _future = _loadReports();
    });
  }

  Future<void> _edit(PlaceReport report) async {
    final result =
        await Navigator.pushNamed(context, '/admin/edit-place', arguments: {
      'placeId': report.placeId,
      'reportId': report.id,
      'reason': report.reason,
      'category': report.category,
    });
    if (result == true) {
      setState(() {
        _future = _loadReports();
      });
    }
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

  void _showReasonDialog(PlaceReport report) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('신고 사유'),
          content: Text(report.reason),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _edit(report);
              },
              child: const Text('장소 수정하기'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _update(report.id, '장소 정보에 문제가 없습니다.');
              },
              child: const Text('문제없음'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('장소 신고 관리')),
      body: FutureBuilder<List<PlaceReport>>(
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
              final item = items[index];
              return ListTile(
                title: Text(item.placeName),
                subtitle: Text('카테고리: ${item.category}'),
                trailing: Text(item.createdAt),
                onTap: () => _showReasonDialog(item),
              );
            },
          );
        },
      ),
    );
  }
}
