import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'schedule_item.dart';
import 'constants.dart';
import 'dart:convert';
import 'map.dart' hide NLatLng;
import 'foodplace.dart';
import 'package:provider/provider.dart';
import 'user_provider.dart';
import 'course_edit_page.dart';

class CourseDetailPage extends StatefulWidget {
  final int courseId;
  final int courseOwnerId;
  final String courseName; // 코스 이름
  final String courseDescription; // 코스 설명
  final List<String> withWho; // 누구랑
  final List<String> purpose; // 무엇을
  final List<String> hashtags; // 해시태그
  final List<ScheduleItem> schedules;

  const CourseDetailPage({
    Key? key,
    required this.courseId,
    required this.courseOwnerId,
    required this.courseName,
    required this.courseDescription,
    required this.withWho,
    required this.purpose,
    required this.hashtags,
    required this.schedules,
  }) : super(key: key);

  @override
  _CourseDetailPageState createState() => _CourseDetailPageState();
}

class _CourseDetailPageState extends State<CourseDetailPage>
    with SingleTickerProviderStateMixin {
  // 지도 관련 변수
  List<NMarker> _markers = [];
  NPolylineOverlay? _polylineOverlay;
  NLatLng? _centerLatLng;

  @override
  void initState() {
    super.initState();
    print(widget.schedules);

    _fetchCoordinatesForSchedules();
  }

  /// (1) 스케줄(장소) 주소들을 지오코딩해서 마커 / 폴리라인 세팅
  Future<void> _fetchCoordinatesForSchedules() async {
    final List<NLatLng> polylineCoords = [];

    for (int i = 0; i < widget.schedules.length; i++) {
      final schedule = widget.schedules[i];
      final address = schedule.placeAddress;

      if (address != null && address.isNotEmpty) {
        final coord = await _fetchCoordinate(address);
        if (coord != null) {
          // i+1 을 마커 캡션으로
          final marker = NMarker(
            id: schedule.placeId ?? schedule.placeName ?? 'marker_$i',
            position: coord,
            caption: NOverlayCaption(text: '${i + 1}'),
          );
          _markers.add(marker);
          polylineCoords.add(coord);

          // 첫 좌표를 지도의 centerLatLng로
          _centerLatLng ??= coord;
        }
      }
    }

    // 2개 이상 좌표가 있으면 폴리라인 추가
    if (polylineCoords.length >= 2) {
      _polylineOverlay = NPolylineOverlay(
        id: 'polyline',
        coords: polylineCoords,
        color: Colors.blue,
        width: 3,
        lineCap: NLineCap.round,
        lineJoin: NLineJoin.round,
      );
    }

    setState(() {});
  }

  /// (2) 주소 -> 좌표 변환
  Future<NLatLng?> _fetchCoordinate(String address) async {
    final clientId = dotenv.env['NAVER_MAP_CLIENT_ID'];
    final clientSecret = dotenv.env['NAVER_MAP_CLIENT_SECRET'];

    if (clientId == null || clientSecret == null) {
      debugPrint("❌ NAVER_MAP_CLIENT_ID / NAVER_MAP_CLIENT_SECRET 가 필요합니다.");
      return null;
    }

    final url =
        "https://naveropenapi.apigw.ntruss.com/map-geocode/v2/geocode?query=$address";

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

  Future<void> _openPlaceDetail(String placeId) async {
    print('▶ 장소 디테일 이동 시도: $placeId');

    try {
      final resp = await http.get(Uri.parse('$BASE_URL/places/$placeId'));
      print('▶ 응답 코드: ${resp.statusCode}');
      print('▶ 응답 본문: ${resp.body}');

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        if (!mounted) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlaceInPageUIOnly(payload: data),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('장소 정보를 불러오지 못했습니다. (${resp.statusCode})')),
        );
      }
    } catch (e) {
      print("❌ 예외 발생: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('장소 정보 로드 중 오류가 발생했습니다.')),
      );
    }
  }

  /// (3) 지도 위젯
  Widget _buildMapView() {
    if (_centerLatLng == null) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
    }

    return Container(
      height: 200,
      width: double.infinity,
      color: Colors.grey.shade200,
      child: NaverMap(
        options: NaverMapViewOptions(
          initialCameraPosition: NCameraPosition(
            target: _centerLatLng!,
            zoom: 14,
          ),
        ),
        onMapReady: (controller) async {
          // 마커 추가
          for (var marker in _markers) {
            await controller.addOverlay(marker);
          }
          // 폴리라인 추가
          if (_polylineOverlay != null) {
            await controller.addOverlay(_polylineOverlay!);
          }
        },
      ),
    );
  }

  /// (4) 스케줄(장소) 카드를 가로 스크롤로
  Widget _buildScheduleCard(ScheduleItem item) {
    final placeName = item.placeName ?? "장소 이름 없음";
    final placeAddress = item.placeAddress ?? "주소 정보 없음";
    final placeImage = item.placeImage;

    Widget imageWidget;
    if (placeImage != null && placeImage.isNotEmpty) {
      if (placeImage.startsWith('http')) {
        // 네트워크 이미지
        imageWidget = Image.network(
          placeImage,
          fit: BoxFit.cover,
          width: 80,
        );
      } else if (placeImage.startsWith('/data/') ||
          placeImage.startsWith('file://')) {
        // 로컬 파일 경로
        imageWidget = Image.file(
          File(placeImage),
          fit: BoxFit.cover,
          width: 80,
        );
      } else {
        // 그 외 상대 경로인 경우 BASE_URL을 붙여서 네트워크 이미지로 처리
        final fullImageUrl = '$BASE_URL$placeImage';
        imageWidget = Image.network(
          fullImageUrl,
          fit: BoxFit.cover,
          width: 80,
        );
      }
    } else {
      imageWidget = Container(
        width: 80,
        color: Colors.grey.shade300,
        child: const Icon(Icons.image_not_supported),
      );
    }

    return GestureDetector(
      onTap: () {
        final pid = item.placeId;
        print("▶ placeId 눌림: $pid");

        if (pid != null && pid.isNotEmpty) {
          _openPlaceDetail(pid);
        }
      },
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 8),
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          clipBehavior: Clip.antiAlias,
          elevation: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 이미지
              SizedBox(
                height: 120,
                width: double.infinity,
                child: imageWidget,
              ),
              // 텍스트 정보
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      placeName,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      placeAddress,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 간단한 Chip 위젯
  Widget _buildChip(String label, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // "누구랑" / "무엇을" / "해시태그"
    final whoChips =
        widget.withWho.map((w) => _buildChip(w, Colors.pink.shade50)).toList();
    final purposeChips = widget.purpose
        .map((p) => _buildChip(p, Colors.yellow.shade50))
        .toList();
    final hashtagChips = widget.hashtags
        .map((tag) => _buildChip('#$tag', Colors.green.shade50))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.courseName),
        backgroundColor: Colors.cyan[100],
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // (1) 지도
            _buildMapView(),

            // (2) "누구랑" / "무엇을" / 해시태그
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // "누구랑", "무엇을" 칩들
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ...whoChips,
                      ...purposeChips,
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 해시태그
                  if (hashtagChips.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: hashtagChips,
                    ),
                  const SizedBox(height: 16),
                  // 코스 설명
                  Text(
                    widget.courseDescription,
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),

            // (3) 일정(장소) 가로 스크롤
            Container(
              height: 220,
              padding: const EdgeInsets.only(left: 16),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: widget.schedules.length,
                itemBuilder: (context, index) {
                  final item = widget.schedules[index];
                  return _buildScheduleCard(item);
                },
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: ElevatedButton(
                onPressed: () {
                  // 길찾기 페이지로 이동
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MapPage(places: widget.schedules),
                    ),
                  );
                },
                child: const Text("길찾기"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyan, // 버튼 색상을 cyan으로 설정
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
            ),
            if (Provider.of<UserProvider>(context).userId ==
                widget.courseOwnerId)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: ElevatedButton(
                  onPressed: () {
                    final model = CourseModel(
                      id: widget.courseId,
                      userId: widget.courseOwnerId,
                      courseName: widget.courseName,
                      courseDescription: widget.courseDescription,
                      hashtags: widget.hashtags,
                      selectedDate: null,
                      withWho: widget.withWho,
                      purpose: widget.purpose,
                      schedules: widget.schedules,
                    );
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CourseEditPage(course: model),
                      ),
                    );
                  },
                  child: const Text('수정하기'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyan[100],
                    foregroundColor: Colors.black,
                    minimumSize: const Size.fromHeight(50),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            // 등록 버튼 등은 제거
          ],
        ),
      ),
    );
  }
}
