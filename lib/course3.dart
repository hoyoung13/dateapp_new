import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:http/http.dart' as http;
import 'schedule_item.dart';
import 'constants.dart';
import 'user_provider.dart';
import 'package:provider/provider.dart';
import 'home.dart';
import 'package:url_launcher/url_launcher.dart';

class CourseCreationStep3Page extends StatefulWidget {
  final String courseName;
  final String courseDescription;
  final List<String> withWho; // 2단계 선택 결과 (표시하지 않아도 됨)
  final List<String> purpose; // 2단계 선택 결과 (표시하지 않아도 됨)
  final List<ScheduleItem> schedules;

  const CourseCreationStep3Page({
    Key? key,
    required this.courseName,
    required this.courseDescription,
    required this.withWho,
    required this.purpose,
    required this.schedules,
  }) : super(key: key);

  @override
  _CourseCreationStep3PageState createState() =>
      _CourseCreationStep3PageState();
}

class _CourseCreationStep3PageState extends State<CourseCreationStep3Page>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  // 지도 관련 변수
  List<NMarker> _markers = [];
  NPolylineOverlay? _polylineOverlay;
  NLatLng? _centerLatLng;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchCoordinatesForSchedules();
  }

  Future<void> _registerCourse() async {
    // UserProvider에서 로그인한 사용자의 ID를 가져옴
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userId = userProvider.userId;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("로그인이 필요합니다.")),
      );
      return;
    }
    // 코스 정보를 payload로 구성
    final payload = {
      'user_id': userId, // 실제 로그인한 사용자 id로 대체하세요.
      'course_name': widget.courseName,
      'course_description': widget.courseDescription,
      'selected_date': DateTime.now().toIso8601String(), // 선택된 날짜가 있다면 사용
      'hashtags': [], // 필요 시 hashtags 리스트 추가
      'with_who': widget.withWho,
      'purpose': widget.purpose,
      'schedules': widget.schedules.map((s) => s.toCourseJson()).toList(),
    };

    final url = Uri.parse(
        "$BASE_URL/course/courses"); // 예: http://yourserver.com/courses
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("코스 등록 완료!")),
        );
        // HomePage로 이동 (이전 스택 모두 제거)
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("코스 등록 실패: ${response.statusCode}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("코스 등록 중 오류 발생: $e")),
      );
    }
  }

  /// 각 일정의 주소를 기반으로 좌표를 가져와서 마커를 추가하고, 폴리라인을 생성하는 함수
  Future<void> _fetchCoordinatesForSchedules() async {
    List<NLatLng> polylineCoords = [];
    for (int i = 0; i < widget.schedules.length; i++) {
      var schedule = widget.schedules[i];
      if (schedule.placeAddress != null && schedule.placeAddress!.isNotEmpty) {
        final coord = await _fetchCoordinate(schedule.placeAddress!);
        if (coord != null) {
          // 마커에 i+1 값을 캡션으로 설정 (문자열로 변환)
          final marker = NMarker(
            id: schedule.placeId ??
                schedule.placeName ??
                UniqueKey().toString(),
            position: coord,
            caption: NOverlayCaption(text: '${i + 1}'),
          );
          _markers.add(marker);
          polylineCoords.add(coord);
          // 첫 번째 좌표를 중심 좌표로 설정
          _centerLatLng ??= coord;
        }
      }
    }
    // 폴리라인 생성 (좌표가 2개 이상 있어야 함)
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

  Future<void> openNaverMap(String address) async {
    final encodedAddress = Uri.encodeComponent(address);
    final url = 'https://map.naver.com/v5/search/$encodedAddress';

    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch $url';
    }
  }

  /// 주어진 주소를 네이버 지오코딩 API로부터 좌표(NLatLng)로 변환하는 함수
  Future<NLatLng?> _fetchCoordinate(String address) async {
    final clientId = dotenv.env['NAVER_MAP_CLIENT_ID'];
    final clientSecret = dotenv.env['NAVER_MAP_CLIENT_SECRET'];
    if (clientId == null || clientSecret == null) {
      debugPrint("❌ .env에 NAVER_MAP_CLIENT_ID / NAVER_MAP_CLIENT_SECRET 설정 필요");
      return null;
    }
    final url =
        "https://naveropenapi.apigw.ntruss.com/map-geocode/v2/geocode?query=${Uri.encodeComponent(address)}";
    try {
      final response = await http.get(Uri.parse(url), headers: {
        "X-NCP-APIGW-API-KEY-ID": clientId,
        "X-NCP-APIGW-API-KEY": clientSecret,
      });
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final addresses = data['addresses'] as List;
        if (addresses.isNotEmpty) {
          final lat = double.parse(addresses[0]['y']);
          final lng = double.parse(addresses[0]['x']);
          return NLatLng(lat, lng);
        }
      } else {
        debugPrint("❌ 지오코딩 실패: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("❌ 지오코딩 오류: $e");
    }
    return null;
  }

  /// 지도 위젯을 빌드하는 함수 (네이버 지도 사용)
  Widget _buildMapView() {
    if (_centerLatLng == null) {
      return SizedBox(
        height: 300,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    return Container(
      width: double.infinity,
      height: 300,
      // 테두리 없게 (여백 제거)
      child: ClipRRect(
        borderRadius: BorderRadius.zero,
        child: NaverMap(
          options: NaverMapViewOptions(
            initialCameraPosition: NCameraPosition(
              target: _centerLatLng!,
              zoom: 15,
            ),
          ),
          onMapReady: (NaverMapController controller) async {
            // 저장된 모든 마커 추가
            for (var marker in _markers) {
              await controller.addOverlay(marker);
            }
            // 폴리라인 추가 (존재할 경우)
            if (_polylineOverlay != null) {
              await controller.addOverlay(_polylineOverlay!);
            }
          },
        ),
      ),
    );
  }

  /// 선택된 장소 정보를 가로 스크롤 카드로 표시하는 함수
  Widget _buildScheduleCard(ScheduleItem item) {
    return Container(
      width: 220,
      margin: const EdgeInsets.only(left: 0),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.placeImage != null)
              item.placeImage!.startsWith('http')
                  ? Image.network(
                      item.placeImage!,
                      height: 140,
                      width: double.infinity,
                      fit: BoxFit.cover,
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
                    item.placeName ?? "장소 이름 없음",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
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
                  // TextButton 스타일을 최소화하여 오버플로우 방지
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 최종 3단계 화면:
    // - 상단바에 코스 이름
    // - 지도 영역 (마커와 폴리라인 포함)
    // - 코스 설명 (좌우 여백 적용)
    // - 선택된 장소 카드들을 가로 스크롤로 배치
    // - "코스 등록하기" 버튼
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.courseName),
        backgroundColor: Colors.cyan[100],
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.zero, // 여백 없이
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 지도 영역 (상단바 바로 아래, 테두리 없음)
            _buildMapView(),
            // 코스 설명 (좌우 패딩 적용)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                widget.courseDescription,
                style: const TextStyle(fontSize: 16),
              ),
            ),
            // 선택된 장소 카드들을 가로 스크롤로 배치
            Container(
              height: 250,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: widget.schedules.length,
                itemBuilder: (context, index) {
                  final item = widget.schedules[index];
                  if (item.placeName == null) return const SizedBox();
                  return _buildScheduleCard(item);
                },
              ),
            ),
            const SizedBox(height: 24),
            // 코스 등록하기 버튼 (맨 아래)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyan[100],
                  ),
                  onPressed: _registerCourse,
                  child: const Text(
                    "코스 등록하기",
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
