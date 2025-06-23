import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'review_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'review_write_page.dart';
import 'constants.dart';
import 'user_provider.dart';

const List<String> _reportCategories = [
  '폐업/휴업',
  '주소 오류',
  '카테고리 오류',
  '영업시간 오류',
  '전화번호 오류',
  '메뉴/가격 오류',
  '사진 오류',
  '기타',
];

class PlaceInPageUIOnly extends StatefulWidget {
  // 다른 화면에서 'place_name', 'images', 'description', 'operating_hours', 'phone', 'address', 'main_category', 'sub_category', 'hashtags' 등 UI에 필요한 데이터를 넘긴다고 가정
  final Map<String, dynamic> payload;
  final VoidCallback? onApprove;
  final VoidCallback? onDelete;
  const PlaceInPageUIOnly(
      {super.key, required this.payload, this.onApprove, this.onDelete});

  @override
  State<PlaceInPageUIOnly> createState() => _PlaceInPageUIOnlyState();
}

class _PlaceInPageUIOnlyState extends State<PlaceInPageUIOnly>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 지도에 표시할 좌표 (NLatLng). 초기엔 null
  NLatLng? _mapLatLng;

  @override
  void initState() {
    super.initState();
    // 탭: 가격정보 / 장소정보 / 리뷰
    _tabController = TabController(length: 3, vsync: this);
    _fetchCoordinates(); // 주소로부터 좌표 얻기
    final placeId = widget.payload['id'] as int;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReviewProvider>().fetchReviews(placeId);
    });
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

  /// 지도 위젯 (네이버 지도 API 사용, 테두리/둥근 모서리 적용)
  Widget _buildMapView(String address) {
    if (_mapLatLng == null) {
      return SizedBox(
        height: 200,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16), // 좌우 여백
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12), // 모서리 둥글게
        border: Border.all(
          color: Colors.grey, // 테두리 색상
          width: 2, // 테두리 두께
        ),
      ),
      child: SizedBox(
        height: 200,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12), // 내부 지도 모서리에 맞춤
          child: NaverMap(
            options: NaverMapViewOptions(
              initialCameraPosition: NCameraPosition(
                target: _mapLatLng!,
                zoom: 15,
              ),
            ),
            onMapReady: (NaverMapController controller) async {
              // 마커 생성 및 추가
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

  // 대표 이미지 위젯 (images 리스트 중 첫 번째만 표시, 없으면 "대표 이미지 없음")
  Widget _buildTopImage() {
    final images = widget.payload['images'] as List<dynamic>?;
    if (images != null && images.isNotEmpty) {
      final firstImage = images.first.toString();
      Widget imageWidget;
      if (firstImage.startsWith('http')) {
        imageWidget = Image.network(firstImage, fit: BoxFit.cover);
      } else if (firstImage.startsWith('/data/') ||
          firstImage.startsWith('file://')) {
        imageWidget = Image.file(File(firstImage), fit: BoxFit.cover);
      } else {
        final fullUrl = '$BASE_URL$firstImage';
        imageWidget = Image.network(fullUrl, fit: BoxFit.cover);
      }
      return Container(
        width: double.infinity,
        height: 150,
        color: Colors.grey[300],
        child: imageWidget,
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

  // 가격정보 탭 (UI 예시)
  // 가격정보 탭 (실제 payload['price_info']를 목록으로 렌더링)
  Widget _buildPriceTab() {
    // widget.payload['price_info']는 List<Map<String, String>> 형태여야 합니다.
    final List<dynamic>? priceList = widget.payload['price_info'];

    // 만약 데이터가 없거나 비어 있으면 안내 문구 표시
    if (priceList == null || priceList.isEmpty) {
      return const Center(
        child: Text("등록된 가격 정보가 없습니다.", style: TextStyle(fontSize: 16)),
      );
    }

    // ListView.builder로 각 항목(item, price)을 ListTile로 표시
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: priceList.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final entry = priceList[index] as Map<String, dynamic>;
        final String itemName = entry['item'] ?? "";
        final String priceValue = entry['price'] ?? "";

        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            itemName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          trailing: Text(
            // 가격 단위가 “원”이라 가정
            "$priceValue원",
            style: const TextStyle(fontSize: 14, color: Colors.black54),
          ),
        );
      },
    );
  }

  // 장소정보 탭 (UI 및 지도 기능 포함)
  Widget _buildPlaceInfoTab() {
    // payload에서 UI 표시용 데이터 가져오기
    final placeName = widget.payload['place_name'] ?? "장소 이름";
    final description = widget.payload['description'] ?? "장소 소개글 없음";
    final operatingHours =
        widget.payload['operating_hours'] as Map<String, dynamic>?;
    final phone = widget.payload['phone'] ?? "연락처 없음";
    final address = widget.payload['address'] ?? "주소 없음";
    final mainCategory = widget.payload['main_category'] ?? "메인카테고리";
    final subCategory = widget.payload['sub_category'] ?? "세부카테고리";
    final category = "$mainCategory / $subCategory";
    final hashtags = widget.payload['hashtags'] as List<dynamic>? ?? [];
    final List<dynamic> withWho =
        widget.payload['with_who'] as List<dynamic>? ?? [];
    final List<dynamic> purpose =
        widget.payload['purpose'] as List<dynamic>? ?? [];
    final List<dynamic> mood = widget.payload['mood'] as List<dynamic>? ?? [];
    final List<dynamic> allChips = [
      ...hashtags,
      ...withWho,
      ...purpose,
      ...mood,
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
          if (allChips.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              children: allChips
                  .map((tag) => Chip(label: Text(tag.toString())))
                  .toList(),
            ),
            const SizedBox(height: 16),
          ],
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
          const Text("연락처",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text(phone, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 16),
          const Text("주소",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text(address,
              style: const TextStyle(fontSize: 14, color: Colors.black54)),
          const SizedBox(height: 10),
          _buildMapView(address), // 실제 네이버 지도 위젯
        ],
      ),
    );
  }

  // 리뷰 탭 (UI 예시)

  Widget _buildReviewTab() {
    return Consumer<ReviewProvider>(
      builder: (context, prov, _) {
        final reviews = prov.reviews;
        final total = reviews.length;

        // 평균 평점 계산
        final avgRating = total > 0
            ? reviews.map((r) => r.rating).reduce((a, b) => a + b) / total
            : 0.0;

        // 별점별 카운트
        final counts = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
        for (var r in reviews) {
          counts[r.rating] = counts[r.rating]! + 1;
        }

        // 퍼센트 계산 (총이 0일 땐 모두 0)
        double pct(int star) => total > 0 ? counts[star]! / total : 0.0;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // —— 리뷰 작성 버튼
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ReviewWritePage(placeId: widget.payload['id']),
                    ),
                  );
                },
                icon: const Icon(Icons.edit, color: Colors.pink),
                label:
                    const Text('리뷰 작성', style: TextStyle(color: Colors.pink)),
              ),
            ),

            const SizedBox(height: 8),

            // —— 요약 카드
            Card(
              color: Colors.grey[100],
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // (이전과 동일)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            avgRating.toStringAsFixed(1),
                            style: const TextStyle(
                                fontSize: 32, fontWeight: FontWeight.bold),
                          ),
                          Row(
                            children: List.generate(
                                5,
                                (i) => Icon(
                                      i < avgRating.round()
                                          ? Icons.star
                                          : Icons.star_border,
                                      color: Colors.pink,
                                      size: 24,
                                    )),
                          ),
                          Text('($total)',
                              style: TextStyle(color: Colors.grey[600])),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 80, color: Colors.grey[300]),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: List.generate(5, (index) {
                          final star = 5 - index;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Text('$star점'),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Stack(
                                    children: [
                                      Container(
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[300],
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                      ),
                                      FractionallySizedBox(
                                        widthFactor: pct(star),
                                        child: Container(
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: Colors.pink,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text('${(pct(star) * 100).round()}%'),
                              ],
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // —— 리뷰가 없을 때
            if (total == 0) const Center(child: Text('등록된 리뷰가 없습니다.')),

            // —— 리뷰 목록
            if (total > 0)
              ...reviews.map((r) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.username,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (r.hashtags.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        children: r.hashtags.map((tag) {
                          return Chip(
                            label: Text('#$tag'),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          );
                        }).toList(),
                      ),

                    const SizedBox(height: 4),

                    // 이미지 썸네일
                    if (r.images.isNotEmpty)
                      SizedBox(
                        height: 80,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: r.images.length,
                          itemBuilder: (context, i) {
                            final imgUrl = r.images[i];
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  imgUrl,
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                      color: Colors.grey[300],
                                      width: 80,
                                      height: 80),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                    const SizedBox(height: 8),
                    Row(
                      children: List.generate(
                          5,
                          (i) => Icon(
                                i < r.rating ? Icons.star : Icons.star_border,
                                color: Colors.amber,
                                size: 20,
                              )),
                    ),
                    const SizedBox(height: 4),
                    Text(r.comment),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('yyyy.MM.dd').format(r.createdAt),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const Divider(height: 32),
                  ],
                );
              }).toList(),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final placeName = widget.payload['place_name'] ?? "장소 이름";

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        // ① AppBar를 사용해서 상태바 자동 처리
        appBar: AppBar(
          backgroundColor: const Color(0xFFB9FDF9),
          centerTitle: true, // 제목 중앙 정렬
          title: Text(
            placeName,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            if (widget.onApprove != null || widget.onDelete != null) ...[
              if (widget.onDelete != null)
                TextButton(
                  onPressed: widget.onDelete,
                  child: const Text('삭제', style: TextStyle(color: Colors.red)),
                ),
              if (widget.onApprove != null)
                TextButton(
                  onPressed: widget.onApprove,
                  child:
                      const Text('승인', style: TextStyle(color: Colors.white)),
                ),
            ] else ...[
              IconButton(
                icon: const Icon(Icons.flag, color: Colors.black),
                onPressed: () {
                  final TextEditingController reasonCtrl =
                      TextEditingController();
                  String selectedCategory = _reportCategories.first;
                  showDialog(
                    context: context,
                    builder: (ctx) {
                      return StatefulBuilder(
                        builder: (dialogCtx, setState) {
                          return AlertDialog(
                            title: const Text('장소 신고'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                DropdownButton<String>(
                                  isExpanded: true,
                                  value: selectedCategory,
                                  items: _reportCategories
                                      .map((c) => DropdownMenuItem(
                                            value: c,
                                            child: Text(c),
                                          ))
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => selectedCategory = val);
                                    }
                                  },
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: reasonCtrl,
                                  decoration: const InputDecoration(
                                    labelText: '추가 내용',
                                    border: OutlineInputBorder(),
                                  ),
                                  maxLines: 3,
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialogCtx),
                                child: const Text('취소'),
                              ),
                              ElevatedButton(
                                onPressed: () async {
                                  final userId =
                                      context.read<UserProvider>().userId;
                                  if (userId == null) {
                                    Navigator.pop(dialogCtx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text('로그인이 필요합니다.')));
                                    return;
                                  }
                                  final uri = Uri.parse(
                                      '$BASE_URL/places/${widget.payload['id']}/report');
                                  final resp = await http.post(
                                    uri,
                                    headers: {
                                      'Content-Type': 'application/json'
                                    },
                                    body: jsonEncode({
                                      'user_id': userId,
                                      'category': selectedCategory,
                                      'reason': reasonCtrl.text,
                                    }),
                                  );
                                  Navigator.pop(dialogCtx);
                                  if (resp.statusCode == 201) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text('신고가 접수되었습니다.')));
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                '신고 실패: ${resp.statusCode}')));
                                  }
                                },
                                child: const Text('신고'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ],
          ],
          elevation: 0, // 그림자 없애기
        ),

        body: Column(
          children: [
            // ② _buildTopImage 그대로
            _buildTopImage(),

            // ③ TabBar
            Container(
              color: Colors.cyan[50],
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

            // ④ TabBarView
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPriceTab(),
                  _buildPlaceInfoTab(),
                  _buildReviewTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
