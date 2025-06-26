import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';
import 'constants.dart';
import 'courseplace.dart';
import 'theme_colors.dart';

class AllplacePage extends StatefulWidget {
  const AllplacePage({super.key});

  @override
  _AllplacePageState createState() => _AllplacePageState();
}

class _AllplacePageState extends State<AllplacePage> {
  String selectedMainCategory = '맛집';
  String? selectedCity;
  String? selectedDistrict;
  String? selectedNeighborhood;
  String? selectedRecommendation; // 선택된 추천 방식
  bool isLoading = false; // ← 로딩 플래그 추가

  Map<String, dynamic> regionData = {}; // 지역 데이터 저장
  final List<String> recommendationMethods = ['MBTI', '성향', '찜순', '평점순'];
  int totalPages = 5; // 전체 페이지 수 (필요시)
  int currentPage = 1; // 현재 선택된 페이지

  // DB에서 등록된 장소 데이터를 저장할 리스트
  List<Map<String, dynamic>> registeredPlaces = [];
  String searchKeyword = '';
  String? selectedSubCategory;
  final Map<String, List<String>> subCategoryMap = const {
    '맛집': ['밥', '고기', '면', '해산물', '길거리', '샐러드', '피자/버거'],
    '카페/술집': ['커피', '차/음료', '디저트', '맥주', '소주', '막걸리', '칵테일/와인'],
    '놀기': ['실외활동', '실내활동', '게임/오락', '힐링', 'VR/방탈출', '만들기'],
    '보기': ['영화', '전시', '공연', '박물관', '스포츠', '쇼핑'],
    '걷기': ['시장', '공원', '테마거리', '야경/풍경', '문화제'],
  };
  List<String> selectedWithWho = [];
  final List<String> withWhoOptions = [
    '혼자',
    '친구',
    '연인',
    '가족',
    '반려동물',
    '직장/동료',
    '동호회/모임',
    '아이와 함께',
  ];

  List<String> selectedPurpose = [];
  final List<String> purposeOptions = [
    '식사',
    '데이트',
    '힐링',
    '회식',
    '산책',
    '특별한 날',
    '놀기'
  ];
  List<String> selectedMood = [];
  final List<String> moodOptions = [
    '즐거운',
    '감성적인',
    '로맨틱한',
    '아늑한',
    '조용한',
    '몽환적인',
    '분위기 있는 조명',
    '잔잔한 음악',
    '활기찬',
    '사교적인',
    '트렌디한',
    '자유로운',
    '이벤트성',
    '핫플레이스',
    '사진 찍기 좋은',
    '자연 친화적',
    '햇살 좋은',
    '공기 좋은',
    '바다 근처',
    '산책하기 좋은',
    '힐링 공간',
    '집중하기 좋은',
    '혼자 있기 좋은'
  ];
  @override
  void initState() {
    super.initState();
    _loadRegions(); // JSON 데이터 불러오기
    _fetchRegisteredPlaces(); // 등록된 장소 불러오기
  }

  // 지역 JSON 파일 로드
  Future<void> _loadRegions() async {
    String data = await rootBundle.loadString('assets/regions.json');
    setState(() {
      regionData = json.decode(data);
    });
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        String tempKeyword = searchKeyword;
        String tempMain = selectedMainCategory;
        String? tempSub = selectedSubCategory;
        List<String> tempWith = List.from(selectedWithWho);
        List<String> tempPur = List.from(selectedPurpose);
        List<String> tempMood = List.from(selectedMood);
        List<String> tempSubOptions = subCategoryMap[tempMain]!;

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return FractionallySizedBox(
              heightFactor: 0.8,
              child: Padding(
                padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                    left: 16,
                    right: 16,
                    top: 20),
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              decoration: const InputDecoration(
                                labelText: '검색어',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (v) => tempKeyword = v,
                              controller:
                                  TextEditingController(text: tempKeyword),
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                labelText: '메인 카테고리',
                                border: OutlineInputBorder(),
                              ),
                              value: tempMain,
                              items: subCategoryMap.keys
                                  .map((c) => DropdownMenuItem(
                                      value: c, child: Text(c)))
                                  .toList(),
                              onChanged: (v) {
                                if (v == null) return;
                                setModalState(() {
                                  tempMain = v;
                                  tempSub = null;
                                  tempSubOptions = subCategoryMap[tempMain]!;
                                });
                              },
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: '세부 카테고리',
                                border: OutlineInputBorder(),
                              ),
                              value: tempSub,
                              items: tempSubOptions
                                  .map((c) => DropdownMenuItem(
                                      value: c, child: Text(c)))
                                  .toList(),
                              onChanged: (v) =>
                                  setModalState(() => tempSub = v),
                            ),
                            const SizedBox(height: 24),
                            ExpansionTile(
                              title: const Text('누구와 함께?',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              children: [
                                SingleChildScrollView(
                                  child: Wrap(
                                    spacing: 8,
                                    children: withWhoOptions.map((o) {
                                      final sel = tempWith.contains(o);
                                      return ChoiceChip(
                                        label: Text(o),
                                        selected: sel,
                                        selectedColor: AppColors.accentLight,
                                        onSelected: (_) {
                                          setModalState(() {
                                            if (sel)
                                              tempWith.remove(o);
                                            else
                                              tempWith.add(o);
                                          });
                                        },
                                      );
                                    }).toList(),
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                            ),
                            ExpansionTile(
                              title: const Text('목적',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              children: [
                                SingleChildScrollView(
                                  child: Wrap(
                                    spacing: 8,
                                    children: purposeOptions.map((o) {
                                      final sel = tempPur.contains(o);
                                      return ChoiceChip(
                                        label: Text(o),
                                        selected: sel,
                                        selectedColor: AppColors.accentLight,
                                        onSelected: (_) {
                                          setModalState(() {
                                            if (sel)
                                              tempPur.remove(o);
                                            else
                                              tempPur.add(o);
                                          });
                                        },
                                      );
                                    }).toList(),
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                            ),
                            ExpansionTile(
                              title: const Text('분위기',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              children: [
                                SingleChildScrollView(
                                  child: Wrap(
                                    spacing: 8,
                                    children: moodOptions.map((o) {
                                      final sel = tempMood.contains(o);
                                      return ChoiceChip(
                                        label: Text(o),
                                        selected: sel,
                                        selectedColor: AppColors.accentLight,
                                        onSelected: (_) {
                                          setModalState(() {
                                            if (sel)
                                              tempMood.remove(o);
                                            else
                                              tempMood.add(o);
                                          });
                                        },
                                      );
                                    }).toList(),
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                            ),
                            const SizedBox(height: 32),
                            Center(
                              child: ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    searchKeyword = tempKeyword;
                                    selectedMainCategory = tempMain;
                                    selectedSubCategory = tempSub;
                                    selectedWithWho = tempWith;
                                    selectedPurpose = tempPur;
                                    selectedMood = tempMood;
                                  });
                                  Navigator.pop(context);
                                  _fetchRegisteredPlaces();
                                },
                                child: const Text('적용'),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _fetchRegisteredPlaces() async {
    setState(() => isLoading = true);

    try {
      final response = await http.get(Uri.parse("$BASE_URL/places"));
      if (response.statusCode == 200) {
        final List<dynamic> raw = json.decode(response.body);

        // --- 디버그: 첫 5개 아이템의 키와 'address' 필드 찍어 보기
        if (raw.isNotEmpty) {
          print("=== place[0] keys: ${(raw[0] as Map).keys.toList()}");
          raw.take(5).forEach((p) => print("address: ${p['address']}"));
        }

        // 기존 필터링 로직…
        var filtered = raw
            .where((place) {
              final p = place as Map<String, dynamic>;

              // 1) 카테고리 체크
              if (selectedMainCategory == '맛집' ||
                  selectedMainCategory == '먹기') {
                if (p['main_category'] != '맛집' && p['main_category'] != '먹기')
                  return false;
              } else {
                if (p['main_category'] != selectedMainCategory) return false;
              }
              // 2) city 키가 없다면 p['address'] 문자열로 대체
              final addr = (p['address'] ?? '') as String;
              if (selectedCity != null && !addr.contains(selectedCity!))
                return false;

              // 3) 필요하다면 district/neighborhood 도 마찬가지로 처리
              if (selectedDistrict != null && !addr.contains(selectedDistrict!))
                return false;
              if (selectedNeighborhood != null &&
                  !addr.contains(selectedNeighborhood!)) return false;

              return true;
            })
            .cast<Map<String, dynamic>>()
            .toList();
        if (searchKeyword.isNotEmpty) {
          filtered = filtered
              .where((p) =>
                  (p['place_name'] ?? '').toString().contains(searchKeyword))
              .toList();
        }

        if (selectedSubCategory != null) {
          filtered = filtered
              .where((p) => p['sub_category'] == selectedSubCategory)
              .toList();
        }

        filtered = filtered.where((p) {
          final wh = List<String>.from(p['with_who'] ?? <String>[]);
          final pu = List<String>.from(p['purpose'] ?? <String>[]);
          final mo = List<String>.from(p['mood'] ?? <String>[]);

          if (selectedWithWho.isNotEmpty &&
              !selectedWithWho.any((x) => wh.contains(x))) return false;
          if (selectedPurpose.isNotEmpty &&
              !selectedPurpose.any((x) => pu.contains(x))) return false;
          if (selectedMood.isNotEmpty &&
              !selectedMood.any((x) => mo.contains(x))) return false;
          return true;
        }).toList();

        if (selectedRecommendation == '찜순') {
          filtered.sort((a, b) {
            final ai = int.tryParse(a['favorite_count']?.toString() ?? '') ??
                (a['favorite_count'] is num
                    ? (a['favorite_count'] as num).toInt()
                    : 0);
            final bi = int.tryParse(b['favorite_count']?.toString() ?? '') ??
                (b['favorite_count'] is num
                    ? (b['favorite_count'] as num).toInt()
                    : 0);
            return bi.compareTo(ai);
          });
        } else if (selectedRecommendation == '평점순') {
          filtered.sort((a, b) {
            final ad = double.tryParse(a['rating_avg']?.toString() ?? '') ??
                (a['rating_avg'] is num
                    ? (a['rating_avg'] as num).toDouble()
                    : 0.0);
            final bd = double.tryParse(b['rating_avg']?.toString() ?? '') ??
                (b['rating_avg'] is num
                    ? (b['rating_avg'] as num).toDouble()
                    : 0.0);
            return bd.compareTo(ad);
          });
        }

        setState(() {
          registeredPlaces = filtered;
        });
      } else {
        print("등록된 장소 불러오기 실패: ${response.statusCode}");
      }
    } catch (e) {
      print("등록된 장소 불러오기 오류: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.accentLight,
        title: const Text('코스 제작'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // 지역 및 추천 방식 선택 영역
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: _showRegionSelectionDialog,
                      child: Text(
                        selectedCity != null
                            ? [
                                selectedCity,
                                if (selectedDistrict != null) selectedDistrict,
                                if (selectedNeighborhood != null)
                                  selectedNeighborhood,
                              ].join(' ')
                            : '지역 선택',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    _buildRecommendationDropdown(),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  "(선택된 방식)으로 추천되는 장소",
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
          // 등록된 맛집(먹기 카테고리) 표시 GridView
          Expanded(
            child: () {
              if (isLoading) {
                // 1) 요청 중
                return const Center(child: CircularProgressIndicator());
              } else if (registeredPlaces.isEmpty) {
                // 2) 로딩 완료 후 데이터 없음
                return const Center(child: Text("해당 조건에 맞는 장소가 없습니다."));
              } else {
                // 3) 데이터 있음
                return GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.9,
                  ),
                  itemCount: registeredPlaces.length,
                  itemBuilder: (c, idx) =>
                      _buildFoodCard(registeredPlaces[idx]),
                );
              }
            }(),
          ),
          // 페이지네이션 버튼 (필요시)
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              totalPages,
              (index) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      currentPage = index + 1;
                      // 페이지 변경 시 _fetchRegisteredPlaces() 재호출 가능
                    });
                  },
                  style: TextButton.styleFrom(
                    foregroundColor:
                        currentPage == index + 1 ? Colors.blue : Colors.grey,
                  ),
                  child: Text("${index + 1}"),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // 추천 방식 선택 드롭다운 UI
  Widget _buildRecommendationDropdown() {
    return DropdownButton<String>(
      hint: const Text("추천방식 선택"),
      value: selectedRecommendation,
      items: recommendationMethods.map((String method) {
        return DropdownMenuItem<String>(
          value: method,
          child: Text(method),
        );
      }).toList(),
      onChanged: (String? value) {
        setState(() {
          selectedRecommendation = value;
        });
      },
    );
  }

  // 지역 선택 다이얼로그 UI
  void _showRegionSelectionDialog() {
    String? tempCity = selectedCity;
    String? tempDistrict = selectedDistrict;
    String? tempNeighborhood = selectedNeighborhood;
    List<String> tempDistricts =
        tempCity != null ? List<String>.from(regionData[tempCity]!.keys) : [];
    List<String> tempNeighborhoods = (tempCity != null && tempDistrict != null)
        ? List<String>.from(regionData[tempCity]![tempDistrict]!)
        : [];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text("지역 선택"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 시/도 선택
                  DropdownButton<String>(
                    isExpanded: true,
                    hint: const Text("시/도 선택"),
                    value: tempCity,
                    items: regionData.keys.map((city) {
                      return DropdownMenuItem(
                        value: city,
                        child: Text(city),
                      );
                    }).toList(),
                    onChanged: (city) {
                      setDialogState(() {
                        tempCity = city;
                        tempDistrict = null;
                        tempNeighborhood = null;
                        tempDistricts = city != null
                            ? List<String>.from(regionData[city]!.keys)
                            : [];
                        tempNeighborhoods = [];
                      });
                      _fetchRegisteredPlaces(); // 재호출
                    },
                  ),
                  const SizedBox(height: 8),

                  // 구/군 선택
                  DropdownButton<String>(
                    isExpanded: true,
                    hint: const Text("구/군 선택"),
                    value: tempDistrict,
                    items: tempDistricts.map((district) {
                      return DropdownMenuItem(
                        value: district,
                        child: Text(district),
                      );
                    }).toList(),
                    onChanged: (district) {
                      setDialogState(() {
                        tempDistrict = district;
                        tempNeighborhood = null;
                        tempNeighborhoods =
                            (tempCity != null && district != null)
                                ? List<String>.from(
                                    regionData[tempCity]![district]!)
                                : [];
                      });
                      _fetchRegisteredPlaces(); // 재호출
                    },
                  ),
                  const SizedBox(height: 8),

                  // 동/읍/면 선택
                  DropdownButton<String>(
                    isExpanded: true,
                    hint: const Text("동/읍/면 선택"),
                    value: tempNeighborhood,
                    items: tempNeighborhoods.map((nbh) {
                      return DropdownMenuItem(
                        value: nbh,
                        child: Text(nbh),
                      );
                    }).toList(),
                    onChanged: (nbh) {
                      setDialogState(() {
                        tempNeighborhood = nbh;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: const Text("확인"),
                  onPressed: () {
                    setState(() {
                      selectedCity = tempCity;
                      selectedDistrict = tempDistrict;
                      selectedNeighborhood = tempNeighborhood;
                    });
                    _fetchRegisteredPlaces();

                    Navigator.pop(ctx);
                    _fetchRegisteredPlaces();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // FoodCard 위젯: 등록된 장소 데이터를 표시 (이미지와 장소 이름, 우측에 하트 아이콘)
  // FoodPage.dart 내 _buildFoodCard 함수
  // FoodCard 위젯: 등록된 장소 데이터를 표시 (이미지와 장소 이름, 우측에 FavoriteIcon)
  Widget _buildFoodCard(Map<String, dynamic> place) {
    String imageUrl = "";
    if (place['images'] != null &&
        place['images'] is List &&
        place['images'].isNotEmpty) {
      imageUrl = place['images'][0].toString();
    }
    return GestureDetector(
      onTap: () async {
        // CourseplacePage로 가서 “코스 등록하기” 누르면 payload로 돌아옵니다.
        final picked = await Navigator.of(context).push<Map<String, dynamic>>(
          MaterialPageRoute(
            builder: (_) => CourseplacePage(payload: place),
          ),
        );
        // 반환된 picked를 다시 한 번 위로 올려 줍니다.
        if (picked != null) Navigator.of(context).pop(picked);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 5)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 이미지 영역
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(10)),
                ),
                child: imageUrl.isNotEmpty
                    ? (imageUrl.startsWith("http")
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                          )
                        : Image.file(
                            File(imageUrl),
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ))
                    : const Center(
                        child: Text("이미지 없음", style: TextStyle(fontSize: 16)),
                      ),
              ),
            ),
            // 장소 이름 및 정보, 우측에 FavoriteIcon
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          place['place_name'] ?? "장소 이름",
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        const Text("추천수: 00  평점: 0.0",
                            style: TextStyle(fontSize: 12)),
                      ],
                    ),
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
