import 'package:flutter/material.dart';
import 'schedule_item.dart';
import 'constants.dart';
import 'user_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'dart:io';
import 'dart:convert';

class AllCoursesPage extends StatefulWidget {
  const AllCoursesPage({Key? key}) : super(key: key);

  @override
  _AllCoursesPageState createState() => _AllCoursesPageState();
}

class _AllCoursesPageState extends State<AllCoursesPage> {
  // (1) 전체 코스 & 필터된 코스
  List<CourseModel> _allCourses = [];
  List<CourseModel> _filteredCourses = [];

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
  }

  /// (A) 백엔드에서 모든 코스 데이터 가져오기
  Future<void> _fetchAllCourses() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final uri = Uri.parse("$BASE_URL/course/allcourse");
      // 예시: GET /course/all 에서 { "courses": [...] } 형태로 내려온다고 가정
      final resp = await http.get(uri);
      if (resp.statusCode == 200) {
        final decoded = json.decode(resp.body) as Map<String, dynamic>;
        final rawList = decoded['courses'] as List<dynamic>? ?? [];

        _allCourses = rawList
            .map((e) => CourseModel.fromJson(e as Map<String, dynamic>))
            .toList();
        // 최초에는 필터 없이 전체를 보여줌
        _filteredCourses = List.from(_allCourses);
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
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          // ── ★ 여기에서 mainAxisSize: MainAxisSize.min 을 추가 ──
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1) 코스명
            Text(
              course.courseName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),

            // 2) “누구와 / 무엇을” Chip
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ...course.withWho.map((label) => Chip(
                      label: Text(label),
                      backgroundColor: Colors.pink.shade50,
                      labelStyle: const TextStyle(fontSize: 12),
                    )),
                ...course.purpose.map((label) => Chip(
                      label: Text(label),
                      backgroundColor: Colors.yellow.shade50,
                      labelStyle: const TextStyle(fontSize: 12),
                    )),
              ],
            ),
            const SizedBox(height: 8),

            // 3) 해시태그 (있을 때만)
            if (course.hashtags.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: course.hashtags.map((tag) {
                  return Chip(
                    label: Text('#$tag'),
                    backgroundColor: Colors.green.shade50,
                    labelStyle: const TextStyle(fontSize: 12),
                  );
                }).toList(),
              ),
            if (course.hashtags.isNotEmpty) const SizedBox(height: 8),

            // 4) 일정(장소) 썸네일
            if (course.schedules.isNotEmpty)
              SizedBox(
                // ── 100 →  90 으로 살짝만 줄였습니다.
                //       높이를 조금만 줄여주면 아래 버튼과 겹치지 않습니다.
                height: 90,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: course.schedules.length,
                  itemBuilder: (context, index) {
                    final sch = course.schedules[index];
                    final String? placeName = sch.placeName;
                    final String? placeImage = sch.placeImage;

                    Widget thumbnail;
                    if (placeImage != null && placeImage.isNotEmpty) {
                      if (placeImage.startsWith('http')) {
                        thumbnail = Image.network(
                          placeImage,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, stack) => Container(
                            width: 80,
                            height: 80,
                            color: Colors.grey.shade300,
                            alignment: Alignment.center,
                            child: const Icon(Icons.broken_image, size: 24),
                          ),
                        );
                      } else if (placeImage.startsWith('/data/') ||
                          placeImage.startsWith('file://')) {
                        thumbnail = Image.file(
                          File(placeImage),
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, stack) => Container(
                            width: 80,
                            height: 80,
                            color: Colors.grey.shade300,
                            alignment: Alignment.center,
                            child: const Icon(Icons.broken_image, size: 24),
                          ),
                        );
                      } else {
                        // 상대 경로라면 BASE_URL 붙여서 네트워크로
                        final fullUrl = '$BASE_URL$placeImage';
                        thumbnail = Image.network(
                          fullUrl,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, stack) => Container(
                            width: 80,
                            height: 80,
                            color: Colors.grey.shade300,
                            alignment: Alignment.center,
                            child: const Icon(Icons.broken_image, size: 24),
                          ),
                        );
                      }
                    } else {
                      thumbnail = Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey.shade300,
                        alignment: Alignment.center,
                        child: const Icon(Icons.image_not_supported, size: 24),
                      );
                    }

                    return Container(
                      width: 80,
                      margin: const EdgeInsets.only(right: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: thumbnail,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            placeName ?? '장소명 없음',
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
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

            // 5) “상세보기 / 삭제” 버튼
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    // 상세보기 로직
                  },
                  child: const Text('상세보기'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    // 삭제 다이얼로그 띄우기 등
                  },
                  child: const Text(
                    '삭제',
                    style: TextStyle(color: Colors.red),
                  ),
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
