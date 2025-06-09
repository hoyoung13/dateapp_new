import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:url_launcher/url_launcher.dart';

import 'schedule_item.dart'; // ScheduleItem 클래스 정의
import 'user_provider.dart'; // UserProvider 정의
import 'constants.dart'; // BASE_URL 등

class AICourse2Page extends StatefulWidget {
  final String courseName; // AI 추천 시 넘어온(초기) 코스명(임시)
  final String courseDescription; // AI 추천 시 넘어온(초기) 설명
  final List<ScheduleItem> schedules; // AI가 추천해준 장소 목록

  const AICourse2Page({
    Key? key,
    required this.courseName,
    required this.courseDescription,
    required this.schedules,
  }) : super(key: key);

  @override
  _AICourse2PageState createState() => _AICourse2PageState();
}

class _AICourse2PageState extends State<AICourse2Page>
    with SingleTickerProviderStateMixin {
  // ─── (1) 지도 관련 변수 ─────────────────────────
  List<NMarker> _markers = [];
  NPolylineOverlay? _polylineOverlay;
  NLatLng? _centerLatLng;

  // ─── (2) “코스명 입력” 컨트롤러 + 공개 여부 체크박스 ────────────
  final TextEditingController _courseNameController = TextEditingController();
  bool _isCoursePublic = true;

  // ─── (3) “누구와” 옵션 (필수 1개 이상) ─────────────────────
  final List<String> withWhoOptions = [
    "연인과",
    "가족과",
    "친구와",
    "나홀로",
    "반려동물과",
    "아이와",
    "부모님과",
  ];
  late List<bool> _withWhoSelected;

  // ─── (4) “무엇을” 옵션 (필수 1개 이상) ─────────────────────────
  final List<String> purposeOptions = [
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

  // ─── (5) “코스등록하기” 버튼 활성화 여부 계산용 ───────────
  bool get _canSubmit {
    final name = _courseNameController.text.trim();
    final atLeastOneWithWho = _withWhoSelected.any((e) => e);
    final atLeastOnePurpose = _purposeSelected.any((e) => e);
    return name.isNotEmpty && atLeastOneWithWho && atLeastOnePurpose;
  }

  @override
  void initState() {
    super.initState();

    // 1) AI 추천 화면에서 넘겨준 초기 코스명을 TextField에 세팅
    _courseNameController.text = widget.courseName;

    // 2) “누구와”/“무엇을” 선택 배열 초기화
    _withWhoSelected = List<bool>.filled(withWhoOptions.length, false);
    _purposeSelected = List<bool>.filled(purposeOptions.length, false);

    // 3) AI가 추천해준 장소들( ScheduleItem )을 기반으로 지도에 마커/폴리라인 구성
    _fetchCoordinatesForSchedules();

    // 4) TextField 변경 시 setState() 해 주어야 ‘_canSubmit’ 재평가
    _courseNameController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _courseNameController.dispose();
    super.dispose();
  }

  // ─── (A) AI 추천 스케줄(장소) → 마커/폴리라인 만들기 ─────────────
  Future<void> _fetchCoordinatesForSchedules() async {
    List<NLatLng> polylineCoords = [];

    for (int i = 0; i < widget.schedules.length; i++) {
      final item = widget.schedules[i];
      if (item.placeAddress != null && item.placeAddress!.isNotEmpty) {
        final coord = await _fetchCoordinate(item.placeAddress!);
        if (coord != null) {
          final marker = NMarker(
            id: (item.placeId ?? i.toString()),
            position: coord,
            caption: NOverlayCaption(text: '${i + 1}'),
          );
          _markers.add(marker);
          polylineCoords.add(coord);
          _centerLatLng ??= coord;
        }
      }
    }

    if (polylineCoords.length >= 2) {
      _polylineOverlay = NPolylineOverlay(
        id: 'polyline',
        coords: polylineCoords,
        color: Colors.blue,
        width: 3,
        lineCap: NLineCap.round,
        lineJoin: NLineJoin.round,
        pattern: const [],
      );
    }

    setState(() {});
  }

  // ─── (B) 네이버 지오코딩 API 호출 ─────────────────────────
  Future<NLatLng?> _fetchCoordinate(String address) async {
    final clientId = dotenv.env['NAVER_MAP_CLIENT_ID'];
    final clientSecret = dotenv.env['NAVER_MAP_CLIENT_SECRET'];
    if (clientId == null || clientSecret == null) return null;

    final url = 'https://naveropenapi.apigw.ntruss.com/map-geocode/v2/geocode'
        '?query=${Uri.encodeComponent(address)}';
    try {
      final response = await http.get(Uri.parse(url), headers: {
        'X-NCP-APIGW-API-KEY-ID': clientId,
        'X-NCP-APIGW-API-KEY': clientSecret,
      });
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final List<dynamic> addresses = data['addresses'] as List<dynamic>;
        if (addresses.isNotEmpty) {
          final lat = double.parse(addresses[0]['y']);
          final lng = double.parse(addresses[0]['x']);
          return NLatLng(lat, lng);
        }
      }
    } catch (e) {
      debugPrint('지오코딩 오류: $e');
    }
    return null;
  }

  // ─── (C) 네이버 지도 뷰 ───────────────────────────────
  Widget _buildMapView() {
    if (_centerLatLng == null) {
      return const SizedBox(
        height: 300,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return SizedBox(
      height: 300,
      child: NaverMap(
        options: NaverMapViewOptions(
          initialCameraPosition: NCameraPosition(
            target: _centerLatLng!,
            zoom: 15,
          ),
        ),
        onMapReady: (controller) async {
          for (var marker in _markers) {
            await controller.addOverlay(marker);
          }
          if (_polylineOverlay != null) {
            await controller.addOverlay(_polylineOverlay!);
          }
        },
      ),
    );
  }

  // ─── (D) 추천 스케줄(장소) 카드 빌드 ─────────────────────
  Widget _buildScheduleCard(ScheduleItem item, int index) {
    return Container(
      width: 220,
      margin: const EdgeInsets.only(left: 12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.placeImage != null && item.placeImage!.isNotEmpty)
              item.placeImage!.startsWith('http')
                  ? Image.network(
                      item.placeImage!,
                      height: 140,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, stack) => Container(
                        height: 140,
                        width: double.infinity,
                        color: Colors.grey.shade300,
                        alignment: Alignment.center,
                        child: const Text("이미지 없음"),
                      ),
                    )
                  : Image.file(
                      File(item.placeImage!),
                      height: 140,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    )
            else
              Container(
                height: 140,
                width: double.infinity,
                color: Colors.grey.shade300,
                alignment: Alignment.center,
                child: const Text("이미지 없음"),
              ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${index + 1}. ${item.placeName ?? "장소명 없음"}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.placeAddress ?? "주소 정보 없음",
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 8),
                  if (item.travelInfo != null && item.travelInfo!.isNotEmpty)
                    Text(
                      '이동정보: ${item.travelInfo}',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── (E) “코스 등록하기” 버튼 누를 때 호출 ────────────────
  Future<void> _registerCourse() async {
    final userId = Provider.of<UserProvider>(context, listen: false).userId;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("로그인이 필요합니다.")),
      );
      return;
    }

    // (1) 선택된 “누구와”
    final selectedWithWho = <String>[];
    for (int i = 0; i < withWhoOptions.length; i++) {
      if (_withWhoSelected[i]) {
        selectedWithWho.add(withWhoOptions[i]);
      }
    }

    // (2) 선택된 “무엇을”
    final selectedPurpose = <String>[];
    for (int i = 0; i < purposeOptions.length; i++) {
      if (_purposeSelected[i]) {
        selectedPurpose.add(purposeOptions[i]);
      }
    }

    // (3) 코스명 + 공개여부
    final courseName = _courseNameController.text.trim();
    final isPublic = _isCoursePublic ? 1 : 0; // 예: DB에 1/0으로 저장한다고 가정

    // (4) “HashTags”는 여기 예시에서는 따로 쓰지 않았으므로 생략 (원한다면 TextField 추가)

    // (5) “스케줄(추천 장소들)” 배열 구성
    final schedulesJson = widget.schedules.map((s) {
      return {
        'place_id': s.placeId,
        'place_name': s.placeName,
        'place_address': s.placeAddress,
        'place_image': s.placeImage,
        'travel_info': s.travelInfo ?? '',
        'max_distance': s.maxDistance ?? '',
      };
    }).toList();

    // (6) 요청 payload 구성
    final payload = {
      'user_id': userId,
      'course_name': courseName,
      'is_public': isPublic,
      'with_who': selectedWithWho,
      'purpose': selectedPurpose,
      'schedules': schedulesJson,
    };

    final url = Uri.parse('$BASE_URL/aicourse/save');
    try {
      final resp = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );
      if (resp.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("코스 등록이 완료되었습니다.")),
        );
        Navigator.pushNamedAndRemoveUntil(context, '/home', (r) => false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("코스 등록 실패: ${resp.statusCode}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("코스 등록 중 오류 발생: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.courseName),
        backgroundColor: Colors.cyan[100],
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── (C) 지도 영역 ───────────────────────────
            _buildMapView(),

            // ─── (D) 코스 설명 영역 ─────────────────────────
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                widget.courseDescription,
                style: const TextStyle(fontSize: 16),
              ),
            ),

            // ─── (1) 코스명 입력 & 공개 여부 ─────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _courseNameController,
                decoration: InputDecoration(
                  labelText: '코스 제목을 입력해주세요.',
                  hintText: 'ex) 여의도 봄나들이',
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('코스명 공개'),
                      Checkbox(
                        value: _isCoursePublic,
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() {
                            _isCoursePublic = v;
                          });
                        },
                      ),
                    ],
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ─── (2) “누구와” 멀티셀렉트 (필수 1개 이상) ───────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: const Text(
                '누구랑 가는 코스인가요?  (1개 이상 필수)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: List.generate(withWhoOptions.length, (i) {
                  return FilterChip(
                    label: Text(withWhoOptions[i]),
                    selected: _withWhoSelected[i],
                    onSelected: (sel) {
                      setState(() {
                        _withWhoSelected[i] = sel;
                      });
                    },
                  );
                }),
              ),
            ),
            const SizedBox(height: 16),

            // ─── (3) “무엇을 하러 가는 코스인가요?” ─────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: const Text(
                '무엇을 하러 가는 코스인가요?  (1개 이상 필수)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: List.generate(purposeOptions.length, (i) {
                  return FilterChip(
                    label: Text(purposeOptions[i]),
                    selected: _purposeSelected[i],
                    onSelected: (sel) {
                      setState(() {
                        _purposeSelected[i] = sel;
                      });
                    },
                  );
                }),
              ),
            ),

            const SizedBox(height: 24),

            // ─── (4) 추천받은 장소 카드 가로 스크롤 ───────────────────
            if (widget.schedules.isNotEmpty)
              SizedBox(
                height: 250,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.schedules.length,
                  itemBuilder: (context, index) {
                    return _buildScheduleCard(widget.schedules[index], index);
                  },
                ),
              ),

            const SizedBox(height: 24),

            // ─── (5) “코스 만들기” 버튼 ────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyan[100],
                  ),
                  onPressed: _canSubmit ? _registerCourse : null,
                  child: const Text(
                    "코스 만들기",
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
