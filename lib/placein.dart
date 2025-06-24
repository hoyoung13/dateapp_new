import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'constants.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'theme_colors.dart';
import 'auth_helper.dart';

class PlaceInPage extends StatefulWidget {
  final Map<String, dynamic> payload; // 등록된 place 데이터

  const PlaceInPage({Key? key, required this.payload}) : super(key: key);

  @override
  _PlaceInPageState createState() => _PlaceInPageState();
}

class _PlaceInPageState extends State<PlaceInPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 지도에 표시할 좌표 (NLatLng). 초기엔 null
  NLatLng? _mapLatLng;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchCoordinates(); // 주소로부터 좌표 얻기
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// 주소를 기반으로 네이버 지오코딩 API를 호출하여 좌표를 얻는 함수
  Future<void> _fetchCoordinates() async {
    final address = widget.payload['address'] as String? ?? '';
    if (address.isEmpty) return;

    final clientId = dotenv.env['NAVER_MAP_CLIENT_ID'];
    final clientSecret = dotenv.env['NAVER_MAP_CLIENT_SECRET'];
    if (clientId == null || clientSecret == null) {
      debugPrint("❌ .env에 NAVER_MAP_CLIENT_ID / NAVER_MAP_CLIENT_SECRET 설정 필요");
      return;
    }

    final url = "https://naveropenapi.apigw.ntruss.com/map-geocode/v2/geocode"
        "?query=${Uri.encodeComponent(address)}";
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          "X-NCP-APIGW-API-KEY-ID": clientId,
          "X-NCP-APIGW-API-KEY": clientSecret,
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final addresses = data['addresses'] as List;
        if (addresses.isNotEmpty) {
          final lat = double.parse(addresses[0]['y']);
          final lng = double.parse(addresses[0]['x']);
          setState(() {
            _mapLatLng = NLatLng(lat, lng);
          });
        }
      } else {
        debugPrint("❌ 지오코딩 실패: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("❌ 지오코딩 오류: $e");
    }
  }

  /// DB에 장소 등록
  Future<void> _registerPlace() async {
    final String apiUrl = "$BASE_URL/places";

    // ① payload 복사
    final Map<String, dynamic> payload =
        Map<String, dynamic>.from(widget.payload);

    debugPrint(
        "▶️ [DEBUG] price_info.runtimeType = ${payload['price_info'].runtimeType}");
    debugPrint("▶️ [DEBUG] price_info = ${payload['price_info']}");
    debugPrint(
        "▶️ [DEBUG] operating_hours.runtimeType = ${payload['operating_hours'].runtimeType}");
    debugPrint("▶️ [DEBUG] operating_hours = ${payload['operating_hours']}");
    debugPrint("▶️ [DEBUG] 최종 payload = ${jsonEncode(payload)}");
    try {
      final headers = await AuthHelper.authHeaders();

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: headers,
        body: jsonEncode(payload),
      );
      if (response.statusCode == 201) {
        debugPrint("✅ 장소 정보 저장 완료: ${response.body}");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("장소가 제출되었습니다. 승인 대기 중입니다.")),
        );
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        debugPrint("❌ 저장 실패: ${response.statusCode} / ${response.body}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("저장 실패: ${response.statusCode}")),
        );
      }
    } catch (e) {
      debugPrint("❌ 서버 요청 오류: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("서버 오류가 발생했습니다.")),
      );
    }
  }

  void _onEdit() {
    debugPrint("수정 버튼 클릭됨!");
    // 수정 기능 구현 필요 시 작성
  }

  /// 상단 대표 이미지
  Widget _buildTopImage() {
    final images = widget.payload['images'] as List<dynamic>?;
    if (images != null && images.isNotEmpty) {
      final firstImage = images.first;
      return Container(
        width: double.infinity,
        height: 150,
        color: Colors.grey[300],
        child: Image.file(
          File(firstImage.toString()),
          fit: BoxFit.cover,
        ),
      );
    } else {
      return Container(
        width: double.infinity,
        height: 150,
        color: Colors.grey[300],
        child: const Center(
          child: Text("대표 이미지 없음", style: TextStyle(fontSize: 16)),
        ),
      );
    }
  }

  /// 가격정보 탭
  Widget _buildPriceTab(dynamic priceInfo) {
    if (priceInfo == null || (priceInfo is List && priceInfo.isEmpty)) {
      return const Center(
        child: Text("무료 혹은 가격정보가 없습니다.", style: TextStyle(fontSize: 16)),
      );
    }
    final List priceList = priceInfo;
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: priceList.length,
      itemBuilder: (context, index) {
        final item = priceList[index] as Map<String, String>;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(item["item"] ?? "상품명", style: const TextStyle(fontSize: 16)),
              Text("${item["price"]}원",
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
        );
      },
    );
  }

  /// 지도 위젯 (테두리 + 모서리 둥글게 적용)
  Widget _buildMapView(String address) {
    if (_mapLatLng == null) {
      return SizedBox(
        height: 200,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    // 실제 지도(NaverMap)를 감싸는 컨테이너에 데코레이션을 줘서 테두리/둥근 모서리 적용
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16), // 좌우 살짝 여백
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12), // 모서리 둥글게
        border: Border.all(
          color: AppColors.border, // 테두리 색상
          width: 2, // 테두리 두께
        ),
      ),
      // 내부에 지도 위젯 배치
      child: SizedBox(
        height: 200,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12), // 내부 지도를 모서리에 맞춰 잘라내기
          child: NaverMap(
            options: NaverMapViewOptions(
              initialCameraPosition: NCameraPosition(
                target: _mapLatLng!,
                zoom: 15,
              ),
            ),
            onMapReady: (NaverMapController controller) async {
              // 마커 생성
              final marker = NMarker(
                id: 'myMarker',
                position: _mapLatLng!,
                caption: NOverlayCaption(text: "주소: $address"),
              );
              await controller.addOverlay(marker);
            },
          ),
        ),
      ),
    );
  }

  /// 장소정보 탭
  Widget _buildPlaceInfoTab(
    String placeName,
    String category,
    String description,
    List<dynamic> hashtags,
    String phone,
    String address,
    Map<String, dynamic>? operatingHours,
    List<dynamic> withWho,
    List<dynamic> purpose,
    List<dynamic> mood,
  ) {
    final List<String> allTags = [
      ...hashtags.map((e) => e.toString()),
      ...withWho.map((e) => e.toString()),
      ...purpose.map((e) => e.toString()),
      ...mood.map((e) => e.toString()),
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(placeName,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(category,
              style: const TextStyle(fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 8),
          if (allTags.isNotEmpty)
            Wrap(
              spacing: 8,
              children: allTags.map((tag) => Chip(label: Text(tag))).toList(),
            ),
          Text(description, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 16),
          const Text("영업시간",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          if (operatingHours == null)
            const Text("영업시간 정보 없음", style: TextStyle(fontSize: 14))
          else
            ...operatingHours.entries.map((entry) {
              final day = entry.key;
              final dayVal = entry.value;
              if (dayVal is Map) {
                final start = dayVal["start"] ?? "??:??";
                final end = dayVal["end"] ?? "??:??";
                return Text("$day: $start ~ $end",
                    style: const TextStyle(fontSize: 14));
              } else if (dayVal is String && dayVal == "휴무") {
                return Text("$day: 휴무", style: const TextStyle(fontSize: 14));
              } else {
                return Text("$day: 알 수 없음",
                    style: const TextStyle(fontSize: 14));
              }
            }),
          const SizedBox(height: 16),
          const Text("매장 연락처",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text(phone, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 16),
          const Text("매장 위치",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text(address,
              style: const TextStyle(fontSize: 14, color: Colors.black54)),
          const SizedBox(height: 10),
          _buildMapView(address), // 지도 위젯
        ],
      ),
    );
  }

  /// 리뷰 탭
  Widget _buildReviewTab() {
    return const Center(
      child: Text("아직 리뷰가 없습니다.", style: TextStyle(fontSize: 16)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 상태표시줄 색상 설정
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: AppColors.appBar,
      statusBarIconBrightness: Brightness.dark,
    ));

    final payload = widget.payload;
    final placeName = payload['place_name'] as String? ?? "장소 이름";
    final description = payload['description'] as String? ?? "장소 소개글 없음";
    final priceInfo = payload['price_info'];
    final phone = payload['phone'] as String? ?? "연락처 없음";
    final address = payload['address'] as String? ?? "주소 없음";
    final operatingHours = payload['operating_hours'] as Map<String, dynamic>?;
    final mainCategory = payload['main_category'] as String? ?? "메인카테고리";
    final subCategory = payload['sub_category'] as String? ?? "세부카테고리";
    final category = "$mainCategory / $subCategory";
    final hashtags = payload['hashtags'] as List<dynamic>? ?? [];
    final withWho = payload['with_who'] as List<dynamic>? ?? [];
    final purpose = payload['purpose'] as List<dynamic>? ?? [];
    final mood = payload['mood'] as List<dynamic>? ?? [];

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        // 상단바
        body: Column(
          children: [
            // 상태표시줄 높이만큼 빈 컨테이너
            Container(
              height: MediaQuery.of(context).padding.top,
              color: AppColors.appBar,
            ),
            // 실제 상단바 영역
            Container(
              color: AppColors.appBar,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    placeName,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: _onEdit,
                        child: const Text(
                          "수정",
                          style: TextStyle(color: Colors.black),
                        ),
                      ),
                      TextButton(
                        onPressed: _registerPlace,
                        child: const Text(
                          "등록",
                          style: TextStyle(color: Colors.black),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // 탭 + 바디
            Expanded(
              child: Column(
                children: [
                  _buildTopImage(),
                  Container(
                    color: AppColors.accentLight,
                    child: TabBar(
                      controller: _tabController,
                      labelColor: Colors.black,
                      unselectedLabelColor: Colors.black54,
                      indicatorColor: Colors.red,
                      tabs: const [
                        Tab(text: "가격정보"),
                        Tab(text: "장소정보"),
                        Tab(text: "리뷰"),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildPriceTab(priceInfo),
                        _buildPlaceInfoTab(
                          placeName,
                          category,
                          description,
                          hashtags,
                          phone,
                          address,
                          operatingHours,
                          withWho,
                          purpose,
                          mood,
                        ),
                        _buildReviewTab(),
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
