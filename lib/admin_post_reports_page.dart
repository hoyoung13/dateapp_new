import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'constants.dart';
import 'user_provider.dart';
import 'post_report.dart';
import 'post.dart';

class AdminPostReportsPage extends StatefulWidget {
  const AdminPostReportsPage({Key? key}) : super(key: key);

  @override
  State<AdminPostReportsPage> createState() => _AdminPostReportsPageState();
}

class _AdminPostReportsPageState extends State<AdminPostReportsPage> {
  Future<List<PostReport>>? _future;
  int? _adminId;

  @override
  void initState() {
    super.initState();
    _adminId = Provider.of<UserProvider>(context, listen: false).userId ?? 8;
    _future = _loadReports();
  }

  Future<List<PostReport>> _loadReports() async {
    final uri = Uri.parse('$BASE_URL/admin/post-reports');
    final resp = await http.get(uri,
        headers: {'Content-Type': 'application/json', 'user_id': '$_adminId'});
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final list = data['reports'] as List<dynamic>;
      return list
          .map((e) => PostReport.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception('failed');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('게시글 신고 관리')),
      body: FutureBuilder<List<PostReport>>(
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
                title: Text(item.postTitle),
                subtitle: Text(item.reason),
                trailing: Text(item.createdAt),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          PostPage(postId: item.postId, reportId: item.id),
                    ),
                  );
                  setState(() {
                    _future = _loadReports();
                  });
                },
              );
            },
          );
        },
      ),
    );
  }
}
