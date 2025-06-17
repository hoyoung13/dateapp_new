import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart'; // ✅ 날짜 포맷 라이브러리 추가
import 'package:provider/provider.dart';
import 'user_provider.dart';
import 'constants.dart';
import 'auth_helper.dart';

// ✅ 시간 포맷 함수
String formatTime(String timestamp) {
  DateTime postTime = DateTime.parse(timestamp); // ✅ DB에서 받은 시간 파싱
  DateTime now = DateTime.now();
  Duration difference = now.difference(postTime); // ✅ 현재 시간과 차이 계산

  if (difference.inDays >= 1) {
    // 🔹 하루 이상 지난 경우 → YYYY-MM-DD
    return DateFormat('yyyy-MM-dd').format(postTime);
  } else if (difference.inHours >= 1) {
    // 🔹 1시간 이상 지난 경우 → "X시간 전"
    return '${difference.inHours}시간 전';
  } else if (difference.inMinutes >= 1) {
    // 🔹 1분 이상 지난 경우 → "X분 전"
    return '${difference.inMinutes}분 전';
  } else {
    // 🔹 방금 작성된 경우 → "방금 전"
    return '방금 전';
  }
}

class PostPage extends StatefulWidget {
  final int postId; // ✅ 게시글 ID
  final int? reportId;

  const PostPage({super.key, required this.postId, this.reportId});

  @override
  _PostPageState createState() => _PostPageState();
}

class _PostPageState extends State<PostPage> {
  Map<String, dynamic>? _post; // ✅ 게시글 정보 저장
  List<Map<String, dynamic>> _comments = []; // ✅ 댓글 리스트 저장
  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    print("📌 PostPage에서 받은 postId: ${widget.postId}"); // ✅ postId 확인

    _fetchPostDetails();
  }

  // ✅ 게시글 정보 및 댓글 불러오기
  Future<void> _fetchPostDetails() async {
    final url = "$BASE_URL/boards/posts/${widget.postId}";
    print("📌 요청할 URL: $url"); // ✅ API 요청 URL 출력

    try {
      final response = await http.get(Uri.parse(url));

      print("📌 서버 응답 상태 코드: ${response.statusCode}"); // ✅ 응답 코드 확인
      print("📌 서버 응답 본문: ${response.body}"); // ✅ 응답 데이터 확인

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        setState(() {
          _post = responseData["post"];
          _comments = List<Map<String, dynamic>>.from(responseData["comments"]);
        });
      } else {
        print("❌ 게시글 상세 정보 불러오기 실패 (응답 코드: ${response.statusCode})");
      }
    } catch (e) {
      print("❌ 서버 요청 오류: $e");
    }
  }

  // ✅ 댓글 작성 기능
  Future<void> _submitComment() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    int? userId = userProvider.userId;

    if (userId == null || _commentController.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("댓글을 입력하세요.")));
      return;
    }

    try {
      // 📌 요청 URL 확인
      //String apiUrl = "$BASE_URL/posts/${widget.postId}/comments";
      String apiUrl = "$BASE_URL/boards/${widget.postId}/comments";

      print("📌 요청할 API URL: $apiUrl");

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": userId,
          "content": _commentController.text,
        }),
      );

      print("📌 서버 응답 상태 코드: ${response.statusCode}");
      print("📌 서버 응답 본문: ${response.body}");

      if (response.statusCode == 201) {
        _commentController.clear();
        _fetchPostDetails(); // ✅ 댓글 작성 후 다시 불러오기
      } else {
        print("❌ 댓글 작성 실패: ${response.body}");
      }
    } catch (e) {
      print("❌ 댓글 작성 오류: $e");
    }
  }

  void _showReportDialog() {
    const reasons = [
      '게시판에 부적절한 게시글',
      '음란성 게시글',
      '욕설',
      '도박',
      '광고/사기',
      '기타',
    ];
    String selectedReason = reasons.first;
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: const Text('게시글 신고'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: reasons
                    .map(
                      (r) => RadioListTile<String>(
                        title: Text(r),
                        value: r,
                        groupValue: selectedReason,
                        onChanged: (val) {
                          if (val != null) setState(() => selectedReason = val);
                        },
                      ),
                    )
                    .toList(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('취소'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogCtx);
                    _reportPost(selectedReason);
                  },
                  child: const Text('신고'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deletePost({bool navigateBack = true}) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    int? userId = userProvider.userId;
    try {
      final response = await http.delete(
        Uri.parse('$BASE_URL/boards/${widget.postId}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId}),
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('게시글이 삭제되었습니다.')));
        if (navigateBack) Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('삭제에 실패했습니다.')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('서버 오류가 발생했습니다.')));
    }
  }

  Future<void> _reportPost(String reason) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    int? userId = userProvider.userId;
    if (userId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('로그인이 필요합니다.')));
      return;
    }
    try {
      final response = await http.post(
        Uri.parse('$BASE_URL/boards/${widget.postId}/report'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'category': reason,
          'reason': reason,
        }),
      );
      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('신고가 접수되었습니다.')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('신고 실패: ${response.statusCode}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('서버 오류가 발생했습니다.')));
    }
  }

  Future<void> _updateReport(bool deletePost) async {
    if (widget.reportId == null) return;
    final adminId = Provider.of<UserProvider>(context, listen: false).userId;
    final uri = Uri.parse('$BASE_URL/admin/post-reports/${widget.reportId}');
    final headers = await AuthHelper.authHeaders(userId: adminId);

    await http.patch(uri,
        headers: headers,
        body: jsonEncode({
          'delete_post': deletePost,
          'message': deletePost
              ? '해당 게시글은 신고 사유로 인해 삭제되었습니다.'
              : '유저님이 신고하신 게시글은 문제가 없습니다.'
        }));
  }

  @override
  Widget build(BuildContext context) {
    if (_post == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userId = userProvider.userId;
    final isAdmin = userProvider.isAdmin;

    return Scaffold(
      appBar: AppBar(
        title: const Text("게시글 보기"),
        backgroundColor: Colors.cyan[100],
        actions: [
          if (isAdmin && widget.reportId != null)
            Row(
              children: [
                TextButton(
                  onPressed: () async {
                    await _deletePost(navigateBack: false);
                    await _updateReport(true);
                    if (!mounted) return;
                    Navigator.pop(context, true);
                  },
                  child: const Text('삭제', style: TextStyle(color: Colors.red)),
                ),
                TextButton(
                  onPressed: () async {
                    await _updateReport(false);
                    if (!mounted) return;
                    Navigator.pop(context, true);
                  },
                  child: const Text('문제 없음'),
                ),
              ],
            )
          else if (_post!["user_id"] == userId)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: const Text("게시글 삭제"),
                      content: const Text("정말로 삭제하시겠습니까?"),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text("취소"),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _deletePost();
                          },
                          child: const Text("삭제",
                              style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    );
                  },
                );
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.flag),
              onPressed: _showReportDialog,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ 작성자 정보
            Row(
              children: [
                const CircleAvatar(child: Icon(Icons.person)),
                const SizedBox(width: 10),
                Text(_post!["nickname"] ?? "익명",
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                Text(formatTime(_post!["created_at"] ?? "")),
              ],
            ),
            const SizedBox(height: 10),

            // ✅ 제목
            Text(
              _post!["title"] ?? "제목 없음",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            // ✅ 본문 내용
            Text(_post!["content"] ?? "내용 없음"),
            const SizedBox(height: 10),

            // ✅ 좋아요 / 싫어요 버튼
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.thumb_up,
                      color: _post!["user_reaction"] == 1
                          ? Colors.blue
                          : Colors.grey),
                  onPressed: () {},
                ),
                Text("${_post!["likes"] ?? 0}"),
                IconButton(
                  icon: Icon(Icons.thumb_down,
                      color: _post!["user_reaction"] == -1
                          ? Colors.red
                          : Colors.grey),
                  onPressed: () {},
                ),
                Text("${_post!["dislikes"] ?? 0}"),
              ],
            ),
            const Divider(),

            // ✅ 댓글 목록
            Expanded(
              child: ListView.builder(
                itemCount: _comments.length,
                itemBuilder: (context, index) {
                  final comment = _comments[index];
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(comment["nickname"] ?? "익명"),
                    subtitle: Text(comment["content"]),
                    trailing: Text(formatTime(comment["created_at"] ?? "")),
                  );
                },
              ),
            ),

            // ✅ 댓글 입력창
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: InputDecoration(
                        hintText: "댓글을 입력하세요.",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _submitComment,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
