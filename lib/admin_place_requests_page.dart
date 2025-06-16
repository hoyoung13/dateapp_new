import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'constants.dart';
import 'package:provider/provider.dart';
import 'user_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'admin_place_request_detail_page.dart';

class AdminPlaceRequestsPage extends StatefulWidget {
  const AdminPlaceRequestsPage({Key? key}) : super(key: key);

  @override
  State<AdminPlaceRequestsPage> createState() => _AdminPlaceRequestsPageState();
}

class _AdminPlaceRequestsPageState extends State<AdminPlaceRequestsPage> {
  Future<List<dynamic>>? _future;
  int? _adminId;
  Future<Map<String, String>> _authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final headers = {
      'Content-Type': 'application/json',
      'user_id': '$_adminId',
    };
    if (token != null) headers['Authorization'] = 'Bearer $token';
    return headers;
  }

  @override
  void initState() {
    super.initState();
    _adminId = Provider.of<UserProvider>(context, listen: false).userId ?? 8;

    _future = _loadRequests();
  }

  Future<List<dynamic>> _loadRequests() async {
    final uri = Uri.parse('$BASE_URL/admin/place-requests');
    final headers = await _authHeaders();
    final resp = await http.get(uri, headers: headers);
    // 🔍 응답 상태코드와 본문 출력
    print('응답 상태 코드: ${resp.statusCode}');
    print('응답 본문: ${resp.body}');

    if (resp.statusCode == 200) {
      try {
        final decoded = jsonDecode(resp.body) as List<dynamic>;
        print('디코딩 성공, 요청 개수: ${decoded.length}');
        return decoded;
      } catch (e) {
        print('JSON 파싱 에러: $e');
        throw Exception('JSON 디코딩 실패');
      }
    }

    print('서버 요청 실패: ${resp.statusCode}');
    throw Exception('failed');
  }

  Future<void> _approve(int id) async {
    final uri = Uri.parse('$BASE_URL/admin/place-requests/$id/approve');
    final headers = await _authHeaders();
    await http.post(uri, headers: headers);
    setState(() {
      _future = _loadRequests();
    });
  }

  Future<void> _reject(int id) async {
    final uri = Uri.parse('$BASE_URL/admin/place-requests/$id/reject');
    final headers = await _authHeaders();
    await http.post(uri, headers: headers);
    setState(() {
      _future = _loadRequests();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('장소 승인 요청')),
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('대기 중인 요청이 없습니다.'));
          }
          final items = snapshot.data!;
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index] as Map<String, dynamic>;
              return ListTile(
                title: Text(item['place_name'] ?? ''),
                subtitle: Text(item['address'] ?? ''),
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AdminPlaceRequestDetailPage(
                          placeId: item['id'] as int),
                    ),
                  );
                  if (result == true) {
                    setState(() {
                      _future = _loadRequests();
                    });
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}
