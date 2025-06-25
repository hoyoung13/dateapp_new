import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart'; // ✅ 날짜 포맷 라이브러리 추가
import 'write_post.dart';
import 'home.dart';
import 'my.dart';
import 'constants.dart';
import 'package:provider/provider.dart';
import 'user_provider.dart';
import 'post.dart'; // ✅ 게시글 상세 페이지 import 추가
import 'theme_colors.dart';

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

class BoardPage extends StatefulWidget {
  const BoardPage({super.key});

  @override
  _BoardPageState createState() => _BoardPageState();
}

class _BoardPageState extends State<BoardPage> {
  int _selectedTabIndex = 0; // ✅ 선택된 탭 인덱스
  int _selectedIndex = 1; // ✅ 기본 선택값 (커뮤니티)
  String _searchKeyword = '';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _tabTitles = ["모든 게시판", "질문 게시판", "추천 게시판", "자유 게시판"];
  List<Map<String, dynamic>> _posts = []; // ✅ 게시글 데이터 저장할 리스트

  final List<Widget> _pages = [
    const HomeContent(),
    const Center(child: Text('💬 커뮤니티 화면')),
    const Center(child: Text('❤️ 찜 목록 화면')),
    const Center(child: Text('🎉 EVENT 화면')),
    const MyPage(),
  ];

  @override
  void initState() {
    super.initState();
    _fetchPosts(); // ✅ 초기화할 때 데이터 가져오기
  }

  // ✅ 게시글 데이터 가져오는 함수
  // ✅ 게시글 데이터 가져오는 함수
  Future<void> _fetchPosts() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    int? userId = userProvider.userId;

    try {
      String boardType = _tabTitles[_selectedTabIndex];
      String apiUrl = "$BASE_URL/boards?user_id=$userId"; // ✅ userId 추가

      if (boardType != "모든 게시판") {
        Map<String, int> boardMap = {
          "자유 게시판": 1,
          "질문 게시판": 2,
          "추천 게시판": 3,
        };

        int? boardId = boardMap[boardType];
        if (boardId != null) {
          apiUrl += "&boardId=$boardId";
        }
      }
      if (_searchKeyword.isNotEmpty) {
        apiUrl += "&search=${Uri.encodeComponent(_searchKeyword)}";
      }
      print("📌 요청할 API URL: $apiUrl");

      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        List<Map<String, dynamic>> newPosts =
            List<Map<String, dynamic>>.from(jsonDecode(response.body));

        setState(() {
          _posts = newPosts;
        });

        print("✅ 서버에서 받은 게시글 개수: ${newPosts.length}");
      } else {
        print("❌ 게시글 불러오기 실패");
      }
    } catch (e) {
      print("❌ 서버 요청 오류: $e");
    }
  }

// ✅ 좋아요/싫어요 업데이트 함수
  Future<void> _updateReaction(int postId, int reactionType) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    int? userId = userProvider.userId;

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("로그인이 필요합니다.")),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse("$BASE_URL/boards/$postId/reaction"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": userId,
          "reaction": reactionType,
        }),
      );

      print("📌 요청한 데이터: { user_id: $userId, reaction: $reactionType }");
      print("📌 서버 응답 상태 코드: ${response.statusCode}");
      print("📌 서버 응답 본문: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);

        setState(() {
          for (var post in _posts) {
            if (post["id"] == postId) {
              post["likes"] = responseData["likes"]; // ✅ 서버에서 받은 값 적용
              post["dislikes"] = responseData["dislikes"];
              post["user_reaction"] = reactionType;
            }
          }
        });

        print("✅ 좋아요 갱신 완료! 현재 좋아요 수: ${responseData["likes"]}");
      } else {
        print("❌ 반응 업데이트 실패: ${response.body}");
      }
    } catch (e) {
      print("❌ 반응 요청 오류: $e");
    }
  }

  void _showSearchDialog() {
    _searchController.text = _searchKeyword;
    showDialog(
      context: context,
      builder: (context) {
        String temp = _searchKeyword;
        return AlertDialog(
          title: const Text('검색'),
          content: TextField(
            controller: _searchController,
            autofocus: true,
            onChanged: (v) => temp = v,
            decoration: const InputDecoration(hintText: '검색어 입력'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _searchKeyword = temp;
                });
                _fetchPosts();
              },
              child: const Text('검색'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.appBar,
        title: const Text('게시판'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const WritePostPage()),
              );

              if (result == true) {
                _fetchPosts(); // ✅ 새 글 작성 후 게시글 목록 갱신
              }
            },
          ),
          IconButton(
              icon: const Icon(Icons.search), onPressed: _showSearchDialog),
        ],
      ),
      body: Column(
        children: [
          // ✅ 게시판 탭
          Container(
            color: AppColors.accentLight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(
                _tabTitles.length,
                (index) => GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedTabIndex = index;
                    });
                    _fetchPosts(); // ✅ 탭 변경 시 데이터 다시 불러오기
                  },
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
                    child: Text(
                      _tabTitles[index],
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: _selectedTabIndex == index
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: _selectedTabIndex == index
                            ? Colors.blue
                            : Colors.black,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ✅ 게시글 리스트
          Expanded(
            child: _posts.isEmpty
                ? const Center(child: CircularProgressIndicator()) // ✅ 로딩 표시
                : ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: _posts.length,
                    itemBuilder: (context, index) {
                      return _buildPostCard(_posts[index]);
                    },
                  ),
          ),
        ],
      ),
      // ✅ 🔹 하단 네비게이션 바 추가 (home.dart에서 가져옴)
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: (index) {
          if (index != _selectedIndex) {
            if (index == 1) {
              // 커뮤니티 이동 시 BoardPage로 네비게이션
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const BoardPage()),
              );
            } else if (index == 0) {
              // 홈으로 이동 시 HomePage 로 네비게이션
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const HomePage()),
              );
            } else {
              setState(() {
                _selectedIndex = index;
              });
            }
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'HOME'),
          BottomNavigationBarItem(icon: Icon(Icons.forum), label: '커뮤니티'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: '찜 목록'),
          BottomNavigationBarItem(icon: Icon(Icons.event), label: 'EVENT'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'MY'),
        ],
      ),
    );
  }

  // ✅ 게시글 카드 UI (수정 & 삭제 버튼 추가)
  // ✅ 게시글 카드 UI
  Widget _buildPostCard(Map<String, dynamic> post) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PostPage(postId: post["id"]),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ 상단 (닉네임, 날짜, 삭제 버튼)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Colors.grey,
                      radius: 15,
                      child: Icon(Icons.person, color: Colors.white, size: 15),
                    ),
                    const SizedBox(width: 8),
                    Text(post["nickname"] ?? "닉네임",
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),

                // ✅ 본인이 작성한 게시글이면 삭제 버튼 표시
                Row(
                  children: [
                    Text(
                      formatTime(post["created_at"] ?? "날짜"),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    if (post["is_owner"] ==
                        true) // ✅ is_owner 값이 true이면 삭제 버튼 표시
                      IconButton(
                        icon: const Icon(Icons.delete,
                            color: Colors.red, size: 18),
                        onPressed: () => _confirmDelete(post["id"]),
                      ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 8),

            // ✅ 게시판 이름 + 제목
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
                  decoration: BoxDecoration(
                    color: AppColors.accentLight,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    post["board_name"] ?? "게시판",
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.black),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    post["title"] ?? "게시글 제목",
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 5),

            // ✅ 게시글 내용 (최대 2줄)
            Text(
              post["content"] ?? "게시글 내용",
              style: const TextStyle(fontSize: 13, color: Colors.black),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 8),

            // ✅ 하단 (조회수, 좋아요, 싫어요)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text("조회수: ${post["views"] ?? 0}",
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(width: 15),
                    IconButton(
                      icon: Icon(Icons.thumb_up,
                          size: 20,
                          color: post["user_reaction"] == 1
                              ? Colors.blue
                              : Colors.grey),
                      onPressed: () => _updateReaction(post["id"], 1),
                    ),
                    Text("${post["likes"] ?? 0}"),
                    IconButton(
                      icon: Icon(Icons.thumb_down,
                          size: 20,
                          color: post["user_reaction"] == -1
                              ? Colors.red
                              : Colors.grey),
                      onPressed: () => _updateReaction(post["id"], -1),
                    ),
                    Text("${post["dislikes"] ?? 0}"),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(int postId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("게시글 삭제"),
          content: const Text("정말로 삭제하시겠습니까?"),
          actions: [
            TextButton(
              child: const Text("취소"),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text("삭제", style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
                _deletePost(postId);
              },
            ),
          ],
        );
      },
    );
  }

  // ✅ 게시글 삭제 함수
  // ✅ 게시글 삭제 함수
  Future<void> _deletePost(int postId) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    int? userId = userProvider.userId; // ✅ 현재 로그인한 사용자 ID

    try {
      final response = await http.delete(
        Uri.parse("$BASE_URL/boards/$postId"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"user_id": userId}), // ✅ user_id 전달
      );

      if (response.statusCode == 200) {
        setState(() {
          _posts.removeWhere((post) => post["id"] == postId);
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("게시글이 삭제되었습니다.")));
      } else {
        print("❌ 삭제 실패: ${response.body}");
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("삭제에 실패했습니다.")));
      }
    } catch (e) {
      print("❌ 삭제 요청 오류: $e");
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("서버 오류가 발생했습니다.")));
    }
  }
}
