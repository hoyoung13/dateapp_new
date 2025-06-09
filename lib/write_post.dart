import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'user_provider.dart';
import 'constants.dart';

class WritePostPage extends StatefulWidget {
  const WritePostPage({super.key});

  @override
  _WritePostPageState createState() => _WritePostPageState();
}

class _WritePostPageState extends State<WritePostPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  int? _selectedBoardId; // ✅ 선택된 게시판 ID
  final List<Map<String, dynamic>> _boardTypes = [
    {"name": "자유 게시판", "id": 1},
    {"name": "질문 게시판", "id": 2},
    {"name": "추천 게시판", "id": 3},
  ];

  Future<void> _submitPost() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    int? userId = userProvider.userId;

    print("📌 현재 로그인된 유저 ID: $userId");
    print("📌 선택된 게시판 ID: $_selectedBoardId");

    if (_titleController.text.isEmpty ||
        _contentController.text.isEmpty ||
        _selectedBoardId == null ||
        userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("제목, 내용, 게시판을 선택하세요.")),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse("$BASE_URL/boards"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "title": _titleController.text,
          "content": _contentController.text,
          "board_id": _selectedBoardId, // ✅ 올바르게 전달되는지 확인
          "user_id": userId,
        }),
      );

      print("📌 서버 응답 상태 코드: ${response.statusCode}");
      print("📌 서버 응답 본문: ${response.body}");

      if (response.statusCode == 201) {
        Navigator.pop(context, true);
      } else {
        print("❌ 게시글 작성 실패: ${response.body}");
      }
    } catch (e) {
      print("❌ 게시글 작성 오류: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("게시글 작성"),
        backgroundColor: Colors.cyan[100],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ✅ 게시판 선택 드롭다운 (board_id 사용)
            DropdownButtonFormField<int>(
              decoration: const InputDecoration(labelText: "게시판 선택"),
              value: _selectedBoardId,
              items: _boardTypes.map((board) {
                return DropdownMenuItem<int>(
                  value: board["id"],
                  child: Text(board["name"]),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedBoardId = value;
                });
                print("📌 선택된 게시판 ID: $_selectedBoardId");
              },
            ),

            const SizedBox(height: 10),

            // ✅ 제목 입력
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: "제목"),
            ),
            const SizedBox(height: 10),

            // ✅ 내용 입력
            TextField(
              controller: _contentController,
              decoration: const InputDecoration(labelText: "내용"),
              maxLines: 5,
            ),
            const SizedBox(height: 20),

            // ✅ 게시글 작성 버튼
            ElevatedButton(
              onPressed: _submitPost,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyan[200],
              ),
              child: const Text("게시글 작성"),
            ),
          ],
        ),
      ),
    );
  }
}
