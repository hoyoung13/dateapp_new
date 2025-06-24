import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'foodplace.dart';
import 'dart:io';
import 'constants.dart';
import 'package:provider/provider.dart';
import 'constants.dart';
import 'user_provider.dart';
import 'theme_colors.dart';

/// FavoriteIcon 위젯: 하트 아이콘을 토글하는 상태
import 'package:flutter/material.dart';
import 'theme_colors.dart';

/// 즐겨찾기(하트) 버튼을 누르면 바텀시트가 열리는 위젯
class FavoriteIcon extends StatelessWidget {
  final Map<String, dynamic> place; // 어떤 장소인지 전달

  const FavoriteIcon({Key? key, required this.place}) : super(key: key);

  void _showCollectionSelectSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // 키보드 대응
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (BuildContext context) {
        return CollectionSelectSheet(place: place);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.favorite_border, color: Colors.grey),
      onPressed: () {
        _showCollectionSelectSheet(context);
      },
    );
  }
}

/// 콜렉션 선택 바텀시트 – 실제 서버에서 콜렉션 목록을 불러올 수 있도록 추후 API 호출로 대체 가능
class CollectionSelectSheet extends StatefulWidget {
  final Map<String, dynamic> place; // 어떤 장소를 콜렉션에 추가할지

  const CollectionSelectSheet({Key? key, required this.place})
      : super(key: key);

  @override
  _CollectionSelectSheetState createState() => _CollectionSelectSheetState();
}

class _CollectionSelectSheetState extends State<CollectionSelectSheet> {
  Future<List<dynamic>>? _collectionsFuture;
  String? selectedCollection; // 선택한 콜렉션의 id

  @override
  void initState() {
    super.initState();

    // userProvider에서 userId를 가져와서 서버에서 콜렉션 목록 불러오기
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final userId = userProvider.userId;
      if (userId != null) {
        setState(() {
          _collectionsFuture = fetchCollections(userId);
        });
      }
    });
  }

  Future<List<dynamic>> fetchCollections(int userId) async {
    final url = Uri.parse('$BASE_URL/zzim/collections/$userId');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["collections"] as List<dynamic>;
      } else {
        print(
            'Failed to fetch collections: ${response.statusCode} ${response.body}');
        return [];
      }
    } catch (error) {
      print('Error fetching collections: $error');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 상단 구분선
            Container(
              height: 6,
              width: 40,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const Text(
              "콜렉션에 추가",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            // "새 콜렉션 만들기" 버튼 (테두리만 있는 버튼, 내부 채우지 않음)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.appBar,
                  side: const BorderSide(color: AppColors.appBar),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  // TODO: "새 콜렉션 만들기" 기능 구현
                },
                child: const Text("새 콜렉션 만들기"),
              ),
            ),
            const SizedBox(height: 16),
            // 콜렉션 목록 표시 (여기서는 FutureBuilder로 불러옴)
            FutureBuilder<List<dynamic>>(
              future: _collectionsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text("오류 발생: ${snapshot.error}"));
                } else {
                  final collections = snapshot.data ?? [];
                  if (collections.isEmpty) {
                    return const Text("등록된 콜렉션이 없습니다.");
                  }
                  return Column(
                    children: [
                      for (var coll in collections) _buildCollectionRow(coll),
                    ],
                  );
                }
              },
            ),
            const SizedBox(height: 16),
            // 저장 버튼 (전체 가로)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.appBar,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () async {
                  if (selectedCollection == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('콜렉션을 선택해주세요.')),
                    );
                    return;
                  }
                  // selectedCollection은 문자열 형태의 collection id
                  int collectionId = int.parse(selectedCollection!);
                  // widget.place에서 place id 추출 (필드명이 'id'라고 가정)
                  int placeId = widget.place['id'];
                  // API 호출 함수 (추후 addPlaceToCollection 함수와 연동)
                  bool success =
                      await addPlaceToCollection(collectionId, placeId);
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('장소가 콜렉션에 추가되었습니다.')),
                    );
                    Navigator.pop(context);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('장소 추가에 실패했습니다.')),
                    );
                  }
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                  child: Text("저장", style: TextStyle(color: Colors.black)),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // 각 콜렉션 항목 UI
  Widget _buildCollectionRow(dynamic collection) {
    final String collName = collection['collection_name'] ?? '제목 없음';
    final String collId = collection['id'].toString();
    return InkWell(
      onTap: () {
        setState(() {
          selectedCollection = collId;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(collName,
                  style: const TextStyle(fontSize: 14, color: Colors.black)),
            ),
            if (selectedCollection == collId)
              const Icon(Icons.check, color: AppColors.appBar),
          ],
        ),
      ),
    );
  }
}

/// API 요청 함수: collection_places에 장소 추가
Future<bool> addPlaceToCollection(int collectionId, int placeId) async {
  final url = Uri.parse('$BASE_URL/zzim/collection_places');
  try {
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'collection_id': collectionId,
        'place_id': placeId,
      }),
    );
    if (response.statusCode == 201) {
      print('Place added to collection successfully: ${response.body}');
      return true;
    } else {
      print(
          'Failed to add place to collection: ${response.statusCode} ${response.body}');
      return false;
    }
  } catch (e) {
    print('Error adding place to collection: $e');
    return false;
  }
}

class FoodPage extends StatefulWidget {
  const FoodPage({super.key});

  @override
  _FoodPageState createState() => _FoodPageState();
}

class _FoodPageState extends State<FoodPage> {
  String selectedMainCategory = '맛집';
  String? selectedCity;
  String? selectedDistrict;
  String? selectedNeighborhood;
  String? selectedRecommendation; // 선택된 추천 방식
  bool isLoading = false; // ← 로딩 플래그 추가

  Map<String, dynamic> regionData = {}; // 지역 데이터 저장
  final List<String> recommendationMethods = ['성향', '찜순', '평점순'];
  int totalPages = 5; // 전체 페이지 수 (필요시)
  int currentPage = 1; // 현재 선택된 페이지

  // DB에서 등록된 장소 데이터를 저장할 리스트
  List<Map<String, dynamic>> registeredPlaces = [];
  String searchKeyword = '';
  String? selectedSubCategory;
  final List<String> subCategoryOptions = [
    '밥',
    '고기',
    '면',
    '해산물',
    '길거리',
    '샐러드',
    '피자/버거'
  ];
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
        // 1) 메인 화면 상태를 복사한 로컬 변수들
        String tempKeyword = searchKeyword;
        String? tempSub = selectedSubCategory;
        List<String> tempWith = List.from(selectedWithWho);
        List<String> tempPur = List.from(selectedPurpose);
        List<String> tempMood = List.from(selectedMood);

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  left: 16,
                  right: 16,
                  top: 20),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 검색어 입력 ──
                    TextField(
                      decoration: const InputDecoration(
                        labelText: '검색어',
                        hintText: '장소 이름, 메뉴 등',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => tempKeyword = v,
                      controller: TextEditingController(text: tempKeyword),
                    ),
                    const SizedBox(height: 16),

                    // ── 세부 카테고리 드롭다운 ──
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: '세부 카테고리',
                        border: OutlineInputBorder(),
                      ),
                      value: tempSub,
                      items: subCategoryOptions
                          .map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) => setModalState(() => tempSub = v),
                    ),
                    const SizedBox(height: 24),

                    // ── 누구와 함께? ChoiceChips ──
                    const Text('누구와 함께?',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
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
                    const SizedBox(height: 24),

                    // ── 목적 ChoiceChips ──
                    const Text('목적',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
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
                    const SizedBox(height: 24),

                    // ── 분위기 ChoiceChips ──
                    const Text('분위기',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
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
                    const SizedBox(height: 32),

                    // ── 적용 버튼 ──
                    Center(
                      child: ElevatedButton(
                        onPressed: () {
                          // 로컬 변수들을 실제 화면 상태로 반영
                          setState(() {
                            searchKeyword = tempKeyword;
                            selectedSubCategory = tempSub;
                            selectedWithWho = tempWith;
                            selectedPurpose = tempPur;
                            selectedMood = tempMood;
                          });
                          Navigator.pop(context);
                          _fetchRegisteredPlaces(); // 필터 적용
                        },
                        child: const Text('적용'),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // DB에서 장소 데이터를 불러오고, "먹기" 카테고리만 필터링
  Future<void> _fetchRegisteredPlaces() async {
    setState(() => isLoading = true);

    try {
      final response = await http.get(Uri.parse("$BASE_URL/places"));
      if (response.statusCode == 200) {
        final List<dynamic> raw = json.decode(response.body);

        var filtered = raw
            .where((place) {
              final p = place as Map<String, dynamic>;
              if (p['main_category'] != '맛집' && p['main_category'] != '먹기')
                return false;
              final addr = (p['address'] ?? '') as String;
              if (selectedCity != null && !addr.contains(selectedCity!))
                return false;
              if (selectedDistrict != null && !addr.contains(selectedDistrict!))
                return false;
              if (selectedNeighborhood != null &&
                  !addr.contains(selectedNeighborhood!)) return false;
              return true;
            })
            .cast<Map<String, dynamic>>()
            .toList();
// 2) 검색어 필터
        if (searchKeyword.isNotEmpty) {
          filtered = filtered.where((p) {
            final name = (p['place_name'] ?? '').toString();
            return name.contains(searchKeyword);
          }).toList();
        }

        // 3) 서브 카테고리 필터
        if (selectedSubCategory != null) {
          filtered = filtered.where((p) {
            return p['sub_category'] == selectedSubCategory;
          }).toList();
        }

        // 4) withWho / purpose / mood 필터
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
        // 찜순 정렬
        if (selectedRecommendation == '찜순') {
          filtered.sort((a, b) {
            // ① String 이든 int 이든 안전하게 숫자로 변환
            final ai = int.tryParse(a['favorite_count']?.toString() ?? '') ??
                (a['favorite_count'] is num
                    ? (a['favorite_count'] as num).toInt()
                    : 0);
            final bi = int.tryParse(b['favorite_count']?.toString() ?? '') ??
                (b['favorite_count'] is num
                    ? (b['favorite_count'] as num).toInt()
                    : 0);

            return bi.compareTo(ai); // 내림차순
          });
        }

// 평점순 정렬
        else if (selectedRecommendation == '평점순') {
          filtered.sort((a, b) {
            final ad = double.tryParse(a['rating_avg']?.toString() ?? '') ??
                (a['rating_avg'] is num
                    ? (a['rating_avg'] as num).toDouble()
                    : 0.0);
            final bd = double.tryParse(b['rating_avg']?.toString() ?? '') ??
                (b['rating_avg'] is num
                    ? (b['rating_avg'] as num).toDouble()
                    : 0.0);

            return bd.compareTo(ad); // 내림차순
          });
        }

        print(
            "DEBUG: rec=$selectedRecommendation, favs=${filtered.map((p) => p['favorite_count'])}, avgs=${filtered.map((p) => p['rating_avg'])}");

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
        title: const Text('맛집 추천'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showFilterDialog, // 여길 채워줍니다
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
      items: recommendationMethods.map((method) {
        return DropdownMenuItem(value: method, child: Text(method));
      }).toList(),
      onChanged: (value) {
        setState(() {
          selectedRecommendation = value;
        });
        _fetchRegisteredPlaces(); // 정렬 적용 위해 재호출
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
    double avgRating = 0.0;
    if (place.containsKey('rating_avg') && place['rating_avg'] != null) {
      avgRating = double.tryParse(place['rating_avg'].toString()) ?? 0.0;
    }
    int reviewCount = 0;
    if (place['review_count'] != null) {
      reviewCount = int.tryParse(place['review_count'].toString()) ?? 0;
    }
    int favoriteCount = 0;
    if (place['favorite_count'] != null) {
      favoriteCount = int.tryParse(place['favorite_count'].toString()) ?? 0;
    }
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PlaceInPageUIOnly(payload: place),
          ),
        );
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
                        Text(
                            "평점: ${avgRating.toStringAsFixed(1)} ($reviewCount)",
                            style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      // 이 두 설정만 바꿔주세요!
                      mainAxisSize: MainAxisSize.min, // Row가 필요한 만큼만 폭을 차지
                      mainAxisAlignment: MainAxisAlignment.end, // 맨 오른쪽에 붙이기
                      children: [
                        FavoriteIcon(place: place),
                        const SizedBox(width: 2), // 간격을 2로 줄임
                        Text(
                          '$favoriteCount',
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
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
