import 'package:date/AICourse.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show rootBundle;
import 'constants.dart';
import 'package:provider/provider.dart';
import 'user_provider.dart';
import 'dart:io';
import 'my.dart';
import 'food.dart';
import 'cafe.dart';
import 'play.dart';
import 'see.dart';
import 'walk.dart';
import 'board.dart';
import 'navermap.dart';
import 'zzim.dart';
import 'course.dart';
import 'AICourse.dart';
import 'all_courses_page.dart';
import 'chatrooms.dart';
import 'aichatscreen.dart';

void main() {
  runApp(const HomePage());
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0; // 🔹 현재 선택된 탭 인덱스

  // 🔹 페이지 목록
  List<Widget> get _pages {
    final me = Provider.of<UserProvider>(context, listen: false).userId!;
    return [
      const HomeContent(),
      const Center(child: Text('💬 커뮤니티 화면')),
      const ZzimPage(),
      // EVENT 탭에 채팅 목록 페이지를 넣습니다
      ChatRoomsPage(userId: me),
      const MyPage(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.cyan[100], // 🔹 상단바 색상 설정
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'DATE IT',
              style: TextStyle(
                fontSize: 20, // 글자 크기
                fontWeight: FontWeight.bold, // Bold
                fontStyle: FontStyle.italic, // Italic
              ),
            ), // 🔹 앱 이름
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {}, // 🔹 검색 버튼
                ),
                IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () {}, // 🔹 메뉴 버튼
                ),
              ],
            ),
          ],
        ),
      ),
      body: _pages[_selectedIndex], // 🔹 선택된 페이지 표시

      // 🔹 하단 네비게이션 바
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: (index) {
          final me = Provider.of<UserProvider>(context, listen: false).userId!;

          if (index == 4) {
            Navigator.of(context)
                .pushReplacement(_noAnimationRoute(const MyPage()));
          } else if (index == 1) {
            Navigator.of(context)
                .pushReplacement(_noAnimationRoute(const BoardPage()));
          } else if (index == 2) {
            Navigator.of(context)
                .pushReplacement(_noAnimationRoute(const ZzimPage()));
          } else if (index == 3) {
            Navigator.of(context).push(
              _noAnimationRoute(ChatRoomsPage(userId: me)),
            );
          } else {
            setState(() {
              _selectedIndex = index;
            });
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
}

Route _noAnimationRoute(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return child; // 애니메이션 효과 제거
    },
  );
}

// 📌 홈 화면 콘텐츠 (HOME 탭)
class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  _HomeContentState createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  // ─────────── 지역 선택 상태 ───────────
  String? selectedCity;
  String? selectedDistrict;
  String? selectedNeighborhood;
  Map<String, dynamic> regionData = {};

  // ─────────── 랭킹 상태 변수 ───────────
  List<Map<String, dynamic>>? weeklyRanking; // 전체 카테고리 이번주 조회순
  List<Map<String, dynamic>>? foodRanking; // main_category = '먹기'
  List<Map<String, dynamic>>? cafeRanking; // main_category = '카페'
  List<Map<String, dynamic>>? spotRanking; // main_category = '장소'
  List<Map<String, dynamic>>? playRanking; // main_category = '놀거리'

  // ─────────── 배너 슬라이더 상태 ───────────
  int _currentBannerIndex = 0;
  final PageController _bannerController = PageController();

  // ─────────── 배너 이미지 리스트 ───────────
  final List<String> _bannerImages = [
    'img/banner1.png',
    'img/banner2.png',
    'img/banner3.png',
    'img/banner4.png',
    'img/banner5.png',
    'img/banner6.png',
    'img/banner7.png',
  ];

  @override
  void initState() {
    super.initState();
    _loadRegions();
    _fetchWeeklyRanking();
    _fetchCategoryRanking('먹기'); // 맛집
    _fetchCategoryRanking('카페'); // 카페
    _fetchCategoryRanking('장소'); // 장소
    _fetchCategoryRanking('놀거리'); // 놀거리
  }

  // ─────────── 지역 JSON 불러오기 ───────────
  Future<void> _loadRegions() async {
    String data = await rootBundle.loadString('assets/regions.json');
    setState(() {
      regionData = json.decode(data);
    });
  }

  // ─────────── 이번주 랭킹(전체 카테고리) API 호출 ───────────
  Future<void> _fetchWeeklyRanking() async {
    setState(() => weeklyRanking = null); // 로딩 상태
    try {
      final response = await http
          .get(Uri.parse('$BASE_URL/places/places/top/week?limit=10'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // { places: [ { id, place_name, images: [...], weekly_views, … }, … ] }
        setState(() {
          weeklyRanking = List<Map<String, dynamic>>.from(data['places']);
        });
      } else {
        setState(() {
          weeklyRanking = [];
        });
        debugPrint("Weekly ranking load failed: ${response.statusCode}");
      }
    } catch (e) {
      setState(() {
        weeklyRanking = [];
      });
      debugPrint("Error fetching weekly ranking: $e");
    }
  }

  // ─────────── 카테고리별 랭킹 API 호출 ───────────
  Future<void> _fetchCategoryRanking(String category) async {
    // category 예: '먹기', '카페', '장소', '놀거리'
    late void Function(List<Map<String, dynamic>>) setter;
    switch (category) {
      case '먹기':
        setter = (v) => setState(() => foodRanking = v);
        setState(() => foodRanking = null);
        break;
      case '카페':
        setter = (v) => setState(() => cafeRanking = v);
        setState(() => cafeRanking = null);
        break;
      case '장소':
        setter = (v) => setState(() => spotRanking = v);
        setState(() => spotRanking = null);
        break;
      case '놀거리':
        setter = (v) => setState(() => playRanking = v);
        setState(() => playRanking = null);
        break;
      default:
        return;
    }

    try {
      final uri = Uri.parse(
          '$BASE_URL/places/places/top/week?limit=10&category=$category');
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setter(List<Map<String, dynamic>>.from(data['places']));
      } else {
        setter([]);
        debugPrint("$category ranking load failed: ${response.statusCode}");
      }
    } catch (e) {
      setter([]);
      debugPrint("Error fetching $category ranking: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildBannerSlider(),
          const SizedBox(height: 10),
          _buildCategoryButtons(),
          const SizedBox(height: 10),
          Container(
              width: double.infinity, height: 8, color: Colors.grey.shade300),
          const SizedBox(height: 10),
          _buildRegionSelector(),
          const SizedBox(height: 10),

          // ─────────────────── 이번주 랭킹 섹션 ───────────────────
          _buildRankingSection(
            title: _getRankingTitle("이번주 랭킹"),
            data: weeklyRanking,
          ),
          const SizedBox(height: 20),

          // ─────────────────── 맛집(먹기) 랭킹 섹션 ───────────────────
          _buildRankingSection(
            title: _getRankingTitle("데이트 맛집 랭킹"),
            data: foodRanking,
          ),
          const SizedBox(height: 20),

          // ─────────────────── 카페 랭킹 섹션 ───────────────────
          _buildRankingSection(
            title: _getRankingTitle("데이트 카페 랭킹"),
            data: cafeRanking,
          ),
          const SizedBox(height: 20),

          // ─────────────────── 장소 랭킹 섹션 ───────────────────
          _buildRankingSection(
            title: _getRankingTitle("데이트 장소 랭킹"),
            data: spotRanking,
          ),
          const SizedBox(height: 20),

          // ─────────────────── 놀거리 랭킹 섹션 ───────────────────
          _buildRankingSection(
            title: _getRankingTitle("데이트 놀거리 랭킹"),
            data: playRanking,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ─────────── 배너 슬라이더 ───────────
  Widget _buildBannerSlider() {
    return SizedBox(
      height: 150,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          PageView.builder(
            controller: _bannerController,
            itemCount: _bannerImages.length,
            onPageChanged: (index) {
              setState(() {
                _currentBannerIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return Image.asset(
                _bannerImages[index],
                fit: BoxFit.cover,
                width: double.infinity,
              );
            },
          ),
          Positioned(
            bottom: 10,
            right: 15,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                "${_currentBannerIndex + 1}/${_bannerImages.length}",
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────── 카테고리 버튼 그룹 ───────────
  Widget _buildCategoryButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _categoryButton('맛집', 'assets/icons/food.png', () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const FoodPage()));
              }),
              _categoryButton('카페', 'assets/icons/cafe.png', () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const CafePage()));
              }),
              _categoryButton('장소', 'assets/icons/place.png', () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const WalkPage()));
              }),
              _categoryButton('놀거리', 'assets/icons/play.png', () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const PlayPage()));
              }),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _categoryButton('코스 제작', 'assets/icons/course.png', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CourseCreationPage()),
                );
              }),
              _categoryButton('AI 코스', 'assets/icons/ai.png', () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ChatScreen())); //여기 ai수정
              }),
              _categoryButton('사용자 코스', 'assets/icons/user_course.png', () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AllCoursesPage()));
              }),
              _categoryButton('축제 행사', 'assets/icons/festival.png', () {}),
            ],
          ),
        ],
      ),
    );
  }

  Widget _categoryButton(String text, String imagePath, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Image.asset(
            imagePath,
            width: 65,
            height: 55,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 3),
          Text(
            text,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // ─────────── 지역 선택 ───────────
  Widget _buildRegionSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: GestureDetector(
        onTap: _showRegionSelectionDialog,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            selectedCity ?? '지역 선택',
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black),
          ),
        ),
      ),
    );
  }

  void _showRegionSelectionDialog() {
    String? tempCity;
    String? tempDistrict;
    String? tempNeighborhood;
    List<String> tempDistricts = [];
    List<String> tempNeighborhoods = [];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("지역 선택"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<String>(
                    hint: const Text("시/도 선택"),
                    value: tempCity,
                    items: regionData.keys.map((String city) {
                      return DropdownMenuItem<String>(
                        value: city,
                        child: Text(city),
                      );
                    }).toList(),
                    onChanged: (String? value) {
                      if (value != null) {
                        setDialogState(() {
                          tempCity = value;
                          tempDistricts = regionData[value]!.keys.toList();
                          tempDistrict = null;
                          tempNeighborhood = null;
                          tempNeighborhoods = [];
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  DropdownButton<String>(
                    hint: const Text("구/군 선택"),
                    value: tempDistrict,
                    items: tempDistricts.map((String district) {
                      return DropdownMenuItem<String>(
                        value: district,
                        child: Text(district),
                      );
                    }).toList(),
                    onChanged: (String? value) {
                      if (value != null) {
                        setDialogState(() {
                          tempDistrict = value;
                          tempNeighborhoods = regionData[tempCity]![value]!;
                          tempNeighborhood = null;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  DropdownButton<String>(
                    hint: const Text("동 선택"),
                    value: tempNeighborhood,
                    items: tempNeighborhoods.map((String neighborhood) {
                      return DropdownMenuItem<String>(
                        value: neighborhood,
                        child: Text(neighborhood),
                      );
                    }).toList(),
                    onChanged: (String? value) {
                      if (value != null) {
                        setDialogState(() {
                          tempNeighborhood = value;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      selectedCity = tempCity;
                      selectedDistrict = tempDistrict;
                      selectedNeighborhood = tempNeighborhood;
                    });
                    Navigator.pop(context);
                  },
                  child: const Text("확인"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ─────────── 랭킹 섹션 공통 위젯 ───────────
  Widget _buildRankingSection({
    required String title,
    required List<Map<String, dynamic>>? data,
  }) {
    if (data == null) {
      // 로딩 중
      return const Center(child: CircularProgressIndicator());
    }
    if (data.isEmpty) {
      // 데이터가 없는 경우
      return Center(
        child: Text(
          "$title 데이터가 없습니다.",
          style: const TextStyle(fontSize: 16),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 제목 + 더보기 버튼
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              TextButton(
                  onPressed: () {
                    // TODO: “더보기” 눌렀을 때 전체 랭킹 페이지로 이동
                  },
                  child: const Text("더보기")),
            ],
          ),
        ),

        // 가로 스크롤 카드
        SizedBox(
          height: 140, // 이미지(80) + 텍스트 + 여유
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            scrollDirection: Axis.horizontal,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemCount: data.length,
            itemBuilder: (context, index) {
              final place = data[index];

              // 1) images 필드가 List 형태인지 확인
              final List<dynamic> images = place['images'] is List
                  ? List<dynamic>.from(place['images'])
                  : [];

              // 2) 첫 번째 이미지 URL(또는 로컬 경로) 꺼내기
              String imageUrl = "";
              if (images.isNotEmpty) {
                imageUrl = images.first.toString();
              }

              // 3) place_name
              final String placeName = place['place_name'] ?? '이름 없음';

              return GestureDetector(
                onTap: () {
                  // 상세 페이지로 이동 (place['id']를 이용)
                  Navigator.pushNamed(
                    context,
                    '/placeDetail',
                    arguments: {"id": place['id']},
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ──────── 이미지 보여주는 로직 ────────
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: imageUrl.isNotEmpty
                          ? (imageUrl.startsWith("http")
                              // ① HTTP/HTTPS URL 이면 네트워크에서 불러오기
                              ? Image.network(
                                  imageUrl,
                                  width: 100,
                                  height: 80,
                                  fit: BoxFit.cover,
                                )
                              // ② 그 외엔 로컬 파일 경로로 간주
                              : Image.file(
                                  File(imageUrl),
                                  width: 100,
                                  height: 80,
                                  fit: BoxFit.cover,
                                ))
                          // ③ imageUrl 자체가 빈 문자열이라면 로컬 placeholder 에셋(또는 “이미지 없음”)
                          : Image.asset(
                              'assets/images/placeholder.png',
                              width: 100,
                              height: 80,
                              fit: BoxFit.cover,
                            ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 100,
                      child: Text(
                        placeName,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ─────────── 랭킹 제목 생성 ───────────
  String _getRankingTitle(String baseTitle) {
    if (selectedCity == null) {
      return baseTitle;
    }
    return "$baseTitle ( ${selectedCity} ${selectedDistrict ?? ''} ${selectedNeighborhood ?? ''} )";
  }
}

// ✅ 카테고리 버튼
Widget _categoryRow(List<String> categories) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: categories.map((text) => _categoryText(text)).toList(),
  );
}

Widget _categoryText(String text) {
  return Expanded(
    child: Center(
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    ),
  );
}

// ✅ 랭킹 섹션
Widget _rankingSection(String title, List<String> imagePaths) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            TextButton(onPressed: () {}, child: const Text('더보기')),
          ],
        ),
      ),
      SizedBox(
        height: 120,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: imagePaths.map((path) => _imageCard(path)).toList(),
        ),
      ),
    ],
  );
}

// ✅ 배너 이미지
Widget _bannerImage() {
  return Container(
    width: double.infinity,
    height: 150,
    decoration: const BoxDecoration(
      image: DecorationImage(
        image: AssetImage('img/banner1.png'),
        fit: BoxFit.cover,
      ),
    ),
  );
}

// ✅ 이미지 카드
Widget _imageCard(String imagePath) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 5),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.asset(imagePath, width: 150, height: 100, fit: BoxFit.cover),
    ),
  );
}
