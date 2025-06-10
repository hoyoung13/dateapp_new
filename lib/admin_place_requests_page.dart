import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'constants.dart';

class AdminPlaceRequestsPage extends StatefulWidget {
  const AdminPlaceRequestsPage({Key? key}) : super(key: key);

  @override
  State<AdminPlaceRequestsPage> createState() => _AdminPlaceRequestsPageState();
}

class _AdminPlaceRequestsPageState extends State<AdminPlaceRequestsPage> {
  Future<List<dynamic>>? _future;

  @override
  void initState() {
    super.initState();
    _future = _loadRequests();
  }

  Future<List<dynamic>> _loadRequests() async {
    final uri = Uri.parse('$BASE_URL/admin/place-requests');
    final resp = await http.get(uri,
        headers: {'Content-Type': 'application/json', 'user_id': '1'});
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as List<dynamic>;
    }
    throw Exception('failed');
  }

  Future<void> _approve(int id) async {
    final uri = Uri.parse('$BASE_URL/admin/place-requests/$id/approve');
    await http.post(uri,
        headers: {'Content-Type': 'application/json', 'user_id': '1'});
    setState(() {
      _future = _loadRequests();
    });
  }

  Future<void> _reject(int id) async {
    final uri = Uri.parse('$BASE_URL/admin/place-requests/$id/reject');
    await http.post(uri,
        headers: {'Content-Type': 'application/json', 'user_id': '1'});
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
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check),
                      onPressed: () => _approve(item['id']),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => _reject(item['id']),
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
