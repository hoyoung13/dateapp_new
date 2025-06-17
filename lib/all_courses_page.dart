import 'package:flutter/material.dart';
import 'schedule_item.dart';
import 'constants.dart';
import 'user_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'dart:io';
import 'coursedetail.dart';

class AllCoursesPage extends StatefulWidget {
  const AllCoursesPage({Key? key}) : super(key: key);

  @override
  _AllCoursesPageState createState() => _AllCoursesPageState();
}

class _AllCoursesPageState extends State<AllCoursesPage> {
  // (1) 전체 코스 & 필터된 코스
  List<CourseModel> _allCourses = [];
  List<CourseModel> _filteredCourses = [];
  final Map<int, Map<String, String>> _userProfiles = {};
  Set<int> _myCourseIds = {}; // 내 코스 ID 목록

  // (2) 현재 로딩/에러 상태
  bool _isLoading = true;
  String? _errorMessage;

  // (3) 필터 상태
  String _placeFilter = "";
  final List<String> _withWhoOptions = [
    "연인과",
    "가족과",
    "친구와",
    "나홀로",
    "반려동물과",
    "아이와",
    "부모님과",
  ];
  late List<bool> _withWhoSelected;

  final List<String> _purposeOptions = [
    "놀러가기",
    "데이트",
    "맛집탐방",
    "소개팅",
    "기념일",
    "핫플탐방",
    "힐링",
    "로컬탐방",
    "쇼핑",
    "여행",
    "랜드마크",
    "인생샷찍기",
    "액티비티",
    "드라이빙",
    "공연/전시",
  ];
  late List<bool> _purposeSelected;

  @override
  void initState() {
    super.initState();
    _withWhoSelected = List<bool>.filled(_withWhoOptions.length, false);
    _purposeSelected = List<bool>.filled(_purposeOptions.length, false);
    _fetchAllCourses();
    _fetchMyCourses();
  }

  /// (A) 백엔드에서 모든 코스 데이터 가져오기
  Future<void> _fetchAllCourses() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final uri = Uri.parse("$BASE_URL/course/allcourse?originalOnly=true");
      // 예시: GET /course/all 에서 { "courses": [...] } 형태로 내려온다고 가정
      final resp = await http.get(uri);
      if (resp.statusCode == 200) {
        final decoded = json.decode(resp.body) as Map<String, dynamic>;
        final rawList = decoded['courses'] as List<dynamic>? ?? [];

        _allCourses = rawList.map((e) {
          final map = e as Map<String, dynamic>;
          // API가 snake_case 또는 camelCase로 보낼 수 있으므로 둘 다 처리
          map['shareCount'] = map['shareCount'] ?? map['share_count'] ?? 0;
          map['favoriteCount'] =
              map['favoriteCount'] ?? map['favorite_count'] ?? 0;
          return CourseModel.fromJson(map);
        }).toList();
        // 최초에는 필터 없이 전체를 보여줌
        _filteredCourses = List.from(_allCourses);
        await _fetchUserProfiles(_allCourses.map((e) => e.userId).toSet());
      } else {
        _errorMessage = "코스 목록을 불러오지 못했습니다. (${resp.statusCode})";
      }
    } catch (e) {
      _errorMessage = "네트워크 오류가 발생했습니다: $e";
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _fetchUserProfiles(Set<int> ids) async {
    for (final id in ids) {
      if (_userProfiles.containsKey(id)) continue;
      try {
        final resp = await http.get(Uri.parse('$BASE_URL/profile/$id'));
        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body)['user'];
          String? img = data['profile_image'];
          if (img != null && img.isNotEmpty && !img.startsWith('http')) {
            img = '$BASE_URL$img';
          }
          _userProfiles[id] = {
            'nickname': data['nickname'] ?? '',
            'profileImage': img ?? ''
          };
        }
      } catch (e) {
        // ignore fetch errors
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _fetchMyCourses() async {
    final userId = Provider.of<UserProvider>(context, listen: false).userId;
    if (userId == null) return;
    try {
      final resp = await http.get(
        Uri.parse('$BASE_URL/course/user_courses/$userId'),
      );
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        final List<dynamic> courses = data['courses'] ?? [];
        setState(() {
          _myCourseIds = courses
              .map((e) => e['copied_from_id'] ?? e['id'])
              .map((id) => id is int ? id as int : int.parse(id.toString()))
              .toSet();
        });
      }
    } catch (e) {
      // ignore errors
    }
  }

  Future<void> _toggleFavorite(CourseModel course) async {
    final userId = Provider.of<UserProvider>(context, listen: false).userId;
    if (userId == null) return;
    if (_myCourseIds.contains(course.id)) return;
    final url = Uri.parse('$BASE_URL/course/courses');
    final body = {
      'user_id': userId,
      'course_name': course.courseName,
      'course_description': course.courseDescription,
      'hashtags': course.hashtags,
      'selected_date': course.selectedDate?.toIso8601String(),
      'with_who': course.withWho,
      'purpose': course.purpose,
      'copied_from_id': course.id,
      'favorite_from_course_id': course.id,
      'schedules': course.schedules
          .map((s) => s.toCourseJson()) // ScheduleItem → Map<String, dynamic>
          .toList(),
    };
    try {
      final resp = await http.post(url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(body));
      if (resp.statusCode == 201) {
        setState(() {
          _myCourseIds.add(course.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('내 코스에 저장되었습니다.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: ${resp.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류: $e')),
      );
    }
  }

  void _showShareDialog(int courseId, String courseName) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userId = userProvider.userId;
    final nickname = userProvider.nickname ?? '';
    if (userId == null) return;

    Future<List<dynamic>> fetchFriends() async {
      final resp = await http.get(Uri.parse('$BASE_URL/fri/friends/$userId'));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        return data['friends'] as List<dynamic>;
      }
      return [];
    }

    Future<List<dynamic>> fetchRooms() async {
      final resp =
          await http.get(Uri.parse('$BASE_URL/chat/rooms/user/$userId'));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        return data['rooms'] as List<dynamic>;
      }
      return [];
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return SizedBox(
          height: 400,
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                const TabBar(tabs: [Tab(text: '친구'), Tab(text: '채팅')]),
                Expanded(
                  child: TabBarView(
                    children: [
                      FutureBuilder<List<dynamic>>(
                        future: fetchFriends(),
                        builder: (c, snap) {
                          if (snap.connectionState != ConnectionState.done) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          final friends = snap.data ?? [];
                          if (friends.isEmpty) {
                            return const Center(child: Text('친구가 없습니다.'));
                          }
                          return ListView.builder(
                            itemCount: friends.length,
                            itemBuilder: (c, i) {
                              final f = friends[i];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundImage: f['profile_image'] != null &&
                                          f['profile_image']
                                              .toString()
                                              .isNotEmpty
                                      ? NetworkImage(f['profile_image'])
                                      : null,
                                  child: (f['profile_image'] == null ||
                                          f['profile_image'].toString().isEmpty)
                                      ? const Icon(Icons.person)
                                      : null,
                                ),
                                title: Text(f['nickname'] ?? ''),
                                onTap: () async {
                                  final createResp = await http.post(
                                    Uri.parse('$BASE_URL/chat/rooms/1on1'),
                                    headers: {
                                      'Content-Type': 'application/json'
                                    },
                                    body: json.encode(
                                        {'userA': userId, 'userB': f['id']}),
                                  );
                                  if (createResp.statusCode == 200) {
                                    final roomId =
                                        json.decode(createResp.body)['roomId'];
                                    final sendResp = await http.post(
                                      Uri.parse(
                                          '$BASE_URL/chat/rooms/$roomId/messages'),
                                      headers: {
                                        'Content-Type': 'application/json'
                                      },
                                      body: json.encode({
                                        'sender_id': userId,
                                        'type': 'course',
                                        'course_id': courseId,
                                        'content':
                                            '${nickname}님이 ${courseName} 코스를 공유했습니다.',
                                      }),
                                    );
                                    if (sendResp.statusCode == 200) {
                                      Navigator.of(ctx).pop();
                                    } else {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content: Text('코스를 공유하였습니다.')),
                                      );
                                      print(
                                          'Failed to send course: ${sendResp.statusCode} ${sendResp.body}');
                                    }
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('코스 공유 실패')),
                                    );
                                    print(
                                        'Failed to create room: ${createResp.statusCode} ${createResp.body}');
                                  }
                                },
                              );
                            },
                          );
                        },
                      ),
                      FutureBuilder<List<dynamic>>(
                        future: fetchRooms(),
                        builder: (c, snap) {
                          if (snap.connectionState != ConnectionState.done) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          final rooms = snap.data ?? [];
                          if (rooms.isEmpty) {
                            return const Center(child: Text('채팅방이 없습니다.'));
                          }
                          return ListView.builder(
                            itemCount: rooms.length,
                            itemBuilder: (c, i) {
                              final r = rooms[i];
                              return ListTile(
                                title: Text(r['room_name'] ?? ''),
                                onTap: () async {
                                  final roomId = r['room_id'];
                                  final resp = await http.post(
                                    Uri.parse(
                                        '$BASE_URL/chat/rooms/$roomId/messages'),
                                    headers: {
                                      'Content-Type': 'application/json'
                                    },
                                    body: json.encode({
                                      'sender_id': userId,
                                      'type': 'course',
                                      'course_id': courseId,
                                      'content':
                                          '${nickname}님이 ${courseName} 코스를 공유했습니다.',
                                    }),
                                  );
                                  if (resp.statusCode == 200) {
                                    Navigator.of(ctx).pop();
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('코스 공유 실패')),
                                    );
                                    print(
                                        'Failed to share course to room $roomId: ${resp.statusCode} ${resp.body}');
                                  }
                                },
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// (B) 필터링 로직: 장소, 누구와, 무엇을 필터
  void _applyFilters() {
    List<CourseModel> temp = List.from(_allCourses);

    // (1) 장소 이름 필터 (_placeFilter). CourseModel.schedules 의 placeName 기준
    final filter = _placeFilter.trim().toLowerCase();
    if (filter.isNotEmpty) {
      temp = temp.where((course) {
        return course.schedules.any((sch) {
          final name = sch.placeName;
          if (name == null) return false;
          return name.toLowerCase().contains(filter);
        });
      }).toList();
    }

    // (2) “누구와” 필터
    final selectedWithWhoLabels = <String>[];
    for (int i = 0; i < _withWhoOptions.length; i++) {
      if (_withWhoSelected[i]) selectedWithWhoLabels.add(_withWhoOptions[i]);
    }
    if (selectedWithWhoLabels.isNotEmpty) {
      temp = temp.where((course) {
        return course.withWho
            .any((label) => selectedWithWhoLabels.contains(label));
      }).toList();
    }

    // (3) “무엇을” 필터
    final selectedPurposeLabels = <String>[];
    for (int i = 0; i < _purposeOptions.length; i++) {
      if (_purposeSelected[i]) selectedPurposeLabels.add(_purposeOptions[i]);
    }
    if (selectedPurposeLabels.isNotEmpty) {
      temp = temp.where((course) {
        return course.purpose
            .any((label) => selectedPurposeLabels.contains(label));
      }).toList();
    }

    setState(() {
      _filteredCourses = temp;
    });
  }

  /// (C) 필터 리셋
  void _resetFilters() {
    setState(() {
      _placeFilter = "";
      _withWhoSelected = List<bool>.filled(_withWhoOptions.length, false);
      _purposeSelected = List<bool>.filled(_purposeOptions.length, false);
      _filteredCourses = List.from(_allCourses);
    });
  }

  /// (D) 코스 카드 UI: 이미지를 포함한 썸네일 형태로 렌더링
  Widget _buildCourseCard(CourseModel course) {
    final nickname = _userProfiles[course.userId]?['nickname'] ?? '';

    return InkWell(
      onTap: () {
        final schedules = List<ScheduleItem>.from(course.schedules);

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CourseDetailPage(
              courseId: course.id,
              courseOwnerId: course.userId,
              courseName: course.courseName,
              courseDescription: course.courseDescription,
              withWho: course.withWho,
              purpose: course.purpose,
              hashtags: course.hashtags,
              schedules: schedules,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (course.schedules.isNotEmpty)
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: course.schedules.length,
                  itemBuilder: (context, index) {
                    final sch = course.schedules[index];
                    final String? placeName = sch.placeName;
                    final String? placeImage = sch.placeImage;

                    Widget image;
                    if (placeImage != null && placeImage.isNotEmpty) {
                      if (placeImage.startsWith('http')) {
                        image = Image.network(
                          placeImage,
                          width: 200,
                          height: 200,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, stack) => Container(
                            width: 200,
                            height: 200,
                            color: Colors.grey.shade300,
                            alignment: Alignment.center,
                            child: const Icon(Icons.broken_image, size: 24),
                          ),
                        );
                      } else if (placeImage.startsWith('/data/') ||
                          placeImage.startsWith('file://')) {
                        image = Image.file(
                          File(placeImage),
                          width: 200,
                          height: 200,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, stack) => Container(
                            width: 200,
                            height: 200,
                            color: Colors.grey.shade300,
                            alignment: Alignment.center,
                            child: const Icon(Icons.broken_image, size: 24),
                          ),
                        );
                      } else {
                        final fullUrl = '$BASE_URL$placeImage';
                        image = Image.network(
                          fullUrl,
                          width: 200,
                          height: 200,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, stack) => Container(
                            width: 200,
                            height: 200,
                            color: Colors.grey.shade300,
                            alignment: Alignment.center,
                            child: const Icon(Icons.broken_image, size: 24),
                          ),
                        );
                      }
                    } else {
                      image = Container(
                        width: 200,
                        height: 200,
                        color: Colors.grey.shade300,
                        alignment: Alignment.center,
                        child: const Icon(Icons.image_not_supported, size: 24),
                      );
                    }

                    return Container(
                      width: 200,
                      margin: const EdgeInsets.only(right: 12),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: image,
                          ),
                          Positioned(
                            bottom: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              color: Colors.black54,
                              child: Text(
                                '${index + 1}. ${placeName ?? '장소명 없음'}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          )
                        ],
                      ),
                    );
                  },
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Text(
                  '대표 장소: 일정 없음',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    '$nickname님의 ${course.courseName}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.share),
                      onPressed: () =>
                          _showShareDialog(course.id, course.courseName),
                    ),
                    Text(
                      '${course.shareCount}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        _myCourseIds.contains(course.id)
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: _myCourseIds.contains(course.id)
                            ? Colors.red
                            : null,
                      ),
                      onPressed: () => _toggleFavorite(course),
                    ),
                    Text(
                      '${course.favoriteCount}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("전체 코스 보기"),
        backgroundColor: Colors.cyan[100],
        foregroundColor: Colors.black,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── (1) 필터 UI ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // (1-1) 장소 검색 TextField
                  TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: "장소 이름으로 검색 (예: 카페, 맛집 등)",
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (text) {
                      _placeFilter = text.trim();
                      _applyFilters();
                    },
                  ),
                  const SizedBox(height: 12),

                  // (1-2) “누구와” FilterChip
                  const Text("누구와 가는 코스인가요?  (필요 시)"),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: List.generate(_withWhoOptions.length, (idx) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: FilterChip(
                            label: Text(_withWhoOptions[idx]),
                            selected: _withWhoSelected[idx],
                            onSelected: (sel) {
                              setState(() {
                                _withWhoSelected[idx] = sel;
                                _applyFilters();
                              });
                            },
                          ),
                        );
                      }),
                    ),
                  ),

                  const SizedBox(height: 12),
                  // (1-3) “무엇을” FilterChip
                  const Text("무엇을 하러 가는 코스인가요?  (필요 시)"),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: List.generate(_purposeOptions.length, (idx) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: FilterChip(
                            label: Text(_purposeOptions[idx]),
                            selected: _purposeSelected[idx],
                            onSelected: (sel) {
                              setState(() {
                                _purposeSelected[idx] = sel;
                                _applyFilters();
                              });
                            },
                          ),
                        );
                      }),
                    ),
                  ),

                  const SizedBox(height: 8),
                  // (1-4) 필터 초기화 버튼
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _resetFilters,
                      icon: const Icon(Icons.clear),
                      label: const Text("필터 초기화"),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: Colors.grey),

            // ── (2) 로딩 / 오류 / 리스트 출력 ───────────────────────────
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : (_errorMessage != null)
                      ? Center(child: Text(_errorMessage!))
                      : _filteredCourses.isEmpty
                          ? const Center(child: Text("조건에 맞는 코스가 없습니다."))
                          : ListView.builder(
                              itemCount: _filteredCourses.length,
                              itemBuilder: (context, index) {
                                return _buildCourseCard(
                                    _filteredCourses[index]);
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
