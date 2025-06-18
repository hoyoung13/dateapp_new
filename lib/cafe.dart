import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'foodplace.dart';
import 'dart:io';
import 'constants.dart';

class CafePage extends StatefulWidget {
  const CafePage({super.key});

  @override
  _CafePageState createState() => _CafePageState();
}

class _CafePageState extends State<CafePage> {
  String? selectedCity;
  String? selectedDistrict;
  String? selectedNeighborhood;
  String? selectedRecommendation; // 선택된 추천 방식
  Map<String, dynamic> regionData = {}; // 지역 데이터 저장
  final List<String> recommendationMethods = ['MBTI', '성향', '찜순', '평점순'];
  int totalPages = 5; // 전체 페이지 수 (필요시)
  int currentPage = 1; // 현재 선택된 페이지

  // DB에서 등록된 장소 데이터를 저장할 리스트
  List<Map<String, dynamic>> registeredPlaces = [];

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

  // DB에서 장소 데이터를 불러오고, "먹기" 카테고리만 필터링
  Future<void> _fetchRegisteredPlaces() async {
    final String apiUrl = "$BASE_URL/places";

    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        setState(() {
          registeredPlaces = data
              .where((place) =>
                  place['main_category'] != null &&
                  place['main_category'] == "카페/술집")
              .map((e) => e as Map<String, dynamic>)
              .toList();
        });
      } else {
        print("등록된 장소 불러오기 실패: ${response.statusCode}");
      }
    } catch (e) {
      print("등록된 장소 불러오기 오류: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.cyan[100],
        title: const Text('카페 추천'),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          // 지역 및 추천 방식 선택 하는거임
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
                        selectedCity ?? '지역 선택',
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
                  "(선택된 방식)으로 추천되는 맛집",
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
          // 등록된 맛집(먹기 카테고리) 표시 GridView
          Expanded(
            child: registeredPlaces.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, // 2열
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.9,
                    ),
                    itemCount: registeredPlaces.length,
                    itemBuilder: (context, index) {
                      final place = registeredPlaces[index];
                      return _buildcafeCard(place);
                    },
                  ),
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

  // FoodCard 위젯: 등록된 장소 데이터를 표시 (이미지와 장소 이름)
  Widget _buildcafeCard(Map<String, dynamic> place) {
    String imageUrl = "";
    if (place['images'] != null &&
        place['images'] is List &&
        place['images'].isNotEmpty) {
      imageUrl = place['images'][0].toString();
    }
    return GestureDetector(
      onTap: () {
        // 카드 클릭 시 PlaceInPageUIOnly 화면으로 이동하며 place 데이터를 payload로 전달합니다.
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
            // 장소 이름 및 기타 정보
            Padding(
              padding: const EdgeInsets.all(8.0),
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
    );
  }
}
