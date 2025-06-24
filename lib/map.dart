import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart'; // 패키지에서 제공하는 NLatLng, NaverMap 등 사용
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'package:intl/intl.dart'; // 천단위 구분자 포맷팅용
import 'schedule_item.dart';
import 'theme_colors.dart';

/// Naver 지오코딩 API로부터 좌표(NLatLng)를 받아오는 함수
Future<NLatLng?> getCoordinateFromAddress(String address) async {
  final clientId = dotenv.env['NAVER_MAP_CLIENT_ID'];
  final clientSecret = dotenv.env['NAVER_MAP_CLIENT_SECRET'];
  final url =
      "https://naveropenapi.apigw.ntruss.com/map-geocode/v2/geocode?query=$address";
  final response = await http.get(Uri.parse(url), headers: {
    "X-NCP-APIGW-API-KEY-ID": clientId!,
    "X-NCP-APIGW-API-KEY": clientSecret!,
  });
  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    final addresses = data['addresses'] as List;
    if (addresses.isNotEmpty) {
      final lat = double.parse(addresses[0]['y']);
      final lng = double.parse(addresses[0]['x']);
      return NLatLng(lat, lng); // flutter_naver_map의 NLatLng
    }
  }
  return null;
}

/// 현재 위치 가져오기
Future<Map<String, dynamic>> getCurrentLocation() async {
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    throw Exception('위치 서비스가 비활성화되어 있습니다.');
  }
  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      throw Exception('위치 권한이 거부되었습니다.');
    }
  }
  if (permission == LocationPermission.deniedForever) {
    throw Exception('위치 권한이 영구적으로 거부되었습니다.');
  }
  Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high);
  return {
    'lat': position.latitude,
    'lng': position.longitude,
  };
}

/// 역 지오코딩: 좌표 -> 주소
Future<String> getAddressFromCoordinates(double lat, double lng) async {
  final clientId = dotenv.env['NAVER_MAP_CLIENT_ID'];
  final clientSecret = dotenv.env['NAVER_MAP_CLIENT_SECRET'];
  final url =
      "https://naveropenapi.apigw.ntruss.com/map-reversegeocode/v2/gc?coords=$lng,$lat&output=json&orders=roadaddr";
  final response = await http.get(Uri.parse(url), headers: {
    "X-NCP-APIGW-API-KEY-ID": clientId!,
    "X-NCP-APIGW-API-KEY": clientSecret!,
  });
  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    if (data["results"] != null && (data["results"] as List).isNotEmpty) {
      final firstResult = data["results"][0];
      final region = firstResult["region"];
      final land = firstResult["land"];
      String area1 = region?["area1"]?["name"] ?? "";
      String area2 = region?["area2"]?["name"] ?? "";
      String roadName = land?["name"] ?? "";
      String number1 = land?["number1"] ?? "";
      return "$area1 $area2 $roadName $number1".trim();
    } else {
      throw Exception("주소 결과가 없습니다.");
    }
  } else {
    throw Exception("역 지오코딩 실패: ${response.statusCode}");
  }
}

/// 장소 검색을 위한 함수
Future<List<Map<String, dynamic>>> fetchLocationSuggestions(
    String query) async {
  final clientId = dotenv.env['NAVER_MAP_CLIENT_ID'];
  final clientSecret = dotenv.env['NAVER_MAP_CLIENT_SECRET'];
  final url =
      "https://naveropenapi.apigw.ntruss.com/map-geocode/v2/geocode?query=$query";
  try {
    final response = await http.get(Uri.parse(url), headers: {
      "X-NCP-APIGW-API-KEY-ID": clientId!,
      "X-NCP-APIGW-API-KEY": clientSecret!,
    });
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final addresses = data['addresses'] as List;
      return addresses.map((e) {
        return {
          'name': e['roadAddress'] ?? e['address'] ?? '',
          'address': e['jibunAddress'] ?? '',
          'lat': e['y'],
          'lng': e['x'],
        };
      }).toList();
    } else {
      debugPrint("❌ 장소 검색 실패: ${response.statusCode} ${response.body}");
    }
  } catch (e) {
    debugPrint("❌ 장소 검색 오류: $e");
  }
  return [];
}

class MapPage extends StatefulWidget {
  // CourseDetailPage에서 전달받은 장소 목록
  final List<ScheduleItem> places;
  const MapPage({Key? key, required this.places}) : super(key: key);
  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();

  // 현재 선택된 이동수단: "차" 또는 "대중교통"
  String _selectedTransport = '차';

  // "차" 모드일 때 지도에 표시할 경로 좌표
  List<NLatLng> _routeCoords = [];
  // "대중교통" 모드일 때 ODsay API에서 받아온 경로 정보 리스트
  List<dynamic> _transitPaths = [];

  late NaverMapController _mapController;

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text("확인")),
        ],
      ),
    );
  }

  /// 경로 검색 수행 함수
  /// 경로 검색
  Future<void> findRoute() async {
    final startAddress = _startController.text.trim();
    final endAddress = _endController.text.trim();
    if (startAddress.isEmpty || endAddress.isEmpty) {
      _showErrorDialog("출발지와 도착지를 모두 입력해주세요.");
      return;
    }

    final startCoord = await getCoordinateFromAddress(startAddress);
    final endCoord = await getCoordinateFromAddress(endAddress);
    if (startCoord == null || endCoord == null) {
      _showErrorDialog("주소에 해당하는 좌표를 찾을 수 없습니다.");
      return;
    }

    // 대중교통 vs 자동차
    if (_selectedTransport == '대중교통') {
      // ODsay API
      final odsayKey = dotenv.env['ODSAY_API_KEY'];
      if (odsayKey == null) {
        _showErrorDialog("ODSAY API 키가 설정되어 있지 않습니다.");
        return;
      }
      final baseUrl = "https://api.odsay.com/v1/api/searchPubTransPathT";
      final odsayUrl = "$baseUrl?"
          "apiKey=${Uri.encodeComponent(odsayKey)}"
          "&SX=${startCoord.longitude}&SY=${startCoord.latitude}"
          "&EX=${endCoord.longitude}&EY=${endCoord.latitude}"
          "&lang=0"; // 한국어
      final response = await http.get(Uri.parse(odsayUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final result = data["result"];
        if (result != null && result["path"] != null) {
          final paths = result["path"];
          if (paths is List && paths.isNotEmpty) {
            setState(() {
              _transitPaths = paths;
              // 자동차 경로 초기화
              _routeCoords = [];
            });
          } else {
            setState(() {
              _transitPaths = [];
            });
            _showErrorDialog("대중교통 경로 정보가 존재하지 않습니다.");
          }
        } else {
          setState(() {
            _transitPaths = [];
          });
          _showErrorDialog("대중교통 경로 정보가 존재하지 않습니다.");
        }
      } else {
        setState(() {
          _transitPaths = [];
        });
        _showErrorDialog("대중교통 경로 검색 실패: ${response.statusCode}");
      }
    } else {
      // "차" 모드: 네이버 지도 경로
      final baseUrl = "https://naveropenapi.apigw.ntruss.com/map-direction/v1/";
      final endpoint = "driving";
      final drivingUrl =
          "$baseUrl$endpoint?goal=${endCoord.longitude},${endCoord.latitude}"
          "&start=${startCoord.longitude},${startCoord.latitude}";
      final clientId2 = dotenv.env['NAVER_MAP_CLIENT_ID'];
      final clientSecret2 = dotenv.env['NAVER_MAP_CLIENT_SECRET'];
      final response = await http.get(Uri.parse(drivingUrl), headers: {
        "x-ncp-apigw-api-key-id": clientId2!,
        "x-ncp-apigw-api-key": clientSecret2!,
      });
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final routeData = data["route"];
        if (routeData != null &&
            routeData["traoptimal"] != null &&
            (routeData["traoptimal"] as List).isNotEmpty) {
          final traoptimal = routeData["traoptimal"] as List;
          final route = traoptimal[0];
          if (route != null && route["path"] != null) {
            final path = route["path"] as List;
            List<NLatLng> coords = path.map((pt) {
              final lng = (pt as List)[0] as double;
              final lat = (pt as List)[1] as double;
              return NLatLng(lat, lng);
            }).toList();
            setState(() {
              _routeCoords = coords;
              // 대중교통 경로 초기화
              _transitPaths = [];
            });
            // 지도에 폴리라인 추가
            await _mapController.clearOverlays();
            final routePolyline = NPolylineOverlay(
              id: 'routeLine',
              coords: _routeCoords,
              color: Colors.blue,
              width: 5,
              lineCap: NLineCap.round,
              lineJoin: NLineJoin.round,
            );
            await _mapController.addOverlay(routePolyline);
            await _mapController.updateCamera(
              NCameraUpdate.withParams(
                target: _routeCoords.first,
                zoom: 14,
              ),
            );
          } else {
            _showErrorDialog("경로 정보가 존재하지 않습니다.");
          }
        } else {
          _showErrorDialog("경로 정보가 존재하지 않습니다.");
        }
      } else {
        _showErrorDialog("경로 검색 실패: ${response.statusCode}");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("길찾기"),
        backgroundColor: AppColors.appBar,
        elevation: 0,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            // (1) 검색 영역
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // 출발지
                  TypeAheadField<Map<String, dynamic>>(
                    suggestionsCallback: (pattern) async {
                      if (pattern.isEmpty) {
                        // "내위치" + 기존 스케줄
                        final scheduleSuggestions =
                            widget.places.asMap().entries.map((entry) {
                          final index = entry.key;
                          final place = entry.value;
                          return {
                            'name': place.placeName ?? "",
                            'address': place.placeAddress ?? "",
                            'order': index + 1,
                            'isScheduleItem': true,
                          };
                        }).toList();
                        return [
                          {
                            'name': '내위치',
                            'address': '현재 위치',
                            'isCurrentLocation': true,
                          },
                          ...scheduleSuggestions,
                        ];
                      } else {
                        // API + 스케줄
                        final fetchedSuggestions =
                            await fetchLocationSuggestions(pattern);
                        final scheduleSuggestions =
                            widget.places.asMap().entries.where((entry) {
                          final place = entry.value;
                          return place.placeName
                                  ?.toLowerCase()
                                  .contains(pattern.toLowerCase()) ??
                              false;
                        }).map((entry) {
                          final index = entry.key;
                          final place = entry.value;
                          return {
                            'name': place.placeName ?? "",
                            'address': place.placeAddress ?? "",
                            'order': index + 1,
                            'isScheduleItem': true,
                          };
                        }).toList();
                        return [
                          ...scheduleSuggestions,
                          ...fetchedSuggestions,
                        ];
                      }
                    },
                    builder: (context, controller, focusNode) {
                      return TextField(
                        controller: _startController,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          labelText: '출발지 검색',
                          border: OutlineInputBorder(),
                        ),
                      );
                    },
                    itemBuilder: (context, suggestion) {
                      if (suggestion['isCurrentLocation'] == true) {
                        return ListTile(
                          leading: const Icon(Icons.my_location),
                          title: Text(suggestion['name']),
                          subtitle: Text(suggestion['address']),
                        );
                      } else if (suggestion['isScheduleItem'] == true) {
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text('${suggestion['order']}'),
                          ),
                          title: Text(suggestion['name']),
                          subtitle: Text(suggestion['address']),
                        );
                      } else {
                        return ListTile(
                          title: Text(suggestion['name']),
                          subtitle: Text(suggestion['address']),
                        );
                      }
                    },
                    onSelected: (suggestion) async {
                      if (suggestion['isCurrentLocation'] == true) {
                        try {
                          final currentLocation = await getCurrentLocation();
                          final lat = currentLocation['lat'];
                          final lng = currentLocation['lng'];
                          final address =
                              await getAddressFromCoordinates(lat, lng);
                          setState(() {
                            _startController.text = address;
                          });
                        } catch (e) {
                          print("현재 위치 정보를 가져올 수 없습니다: $e");
                        }
                      } else {
                        setState(() {
                          _startController.text = suggestion['address'];
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  // 도착지
                  TypeAheadField<Map<String, dynamic>>(
                    suggestionsCallback: (pattern) async {
                      if (pattern.isEmpty) {
                        final scheduleSuggestions =
                            widget.places.asMap().entries.map((entry) {
                          final index = entry.key;
                          final place = entry.value;
                          return {
                            'name': place.placeName ?? "",
                            'address': place.placeAddress ?? "",
                            'order': index + 1,
                            'isScheduleItem': true,
                          };
                        }).toList();
                        return [
                          {
                            'name': '내위치',
                            'address': '현재 위치',
                            'isCurrentLocation': true,
                          },
                          ...scheduleSuggestions,
                        ];
                      } else {
                        final fetched = await fetchLocationSuggestions(pattern);
                        final scheduleSuggestions =
                            widget.places.asMap().entries.where((entry) {
                          final place = entry.value;
                          return place.placeName
                                  ?.toLowerCase()
                                  .contains(pattern.toLowerCase()) ??
                              false;
                        }).map((entry) {
                          final index = entry.key;
                          final place = entry.value;
                          return {
                            'name': place.placeName ?? "",
                            'address': place.placeAddress ?? "",
                            'order': index + 1,
                            'isScheduleItem': true,
                          };
                        }).toList();
                        return [
                          ...scheduleSuggestions,
                          ...fetched,
                        ];
                      }
                    },
                    builder: (context, controller, focusNode) {
                      return TextField(
                        controller: _endController,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          labelText: '도착지 검색',
                          border: OutlineInputBorder(),
                        ),
                      );
                    },
                    itemBuilder: (context, suggestion) {
                      if (suggestion['isCurrentLocation'] == true) {
                        return ListTile(
                          leading: const Icon(Icons.my_location),
                          title: Text(suggestion['name']),
                          subtitle: Text(suggestion['address']),
                        );
                      } else if (suggestion['isScheduleItem'] == true) {
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text('${suggestion['order']}'),
                          ),
                          title: Text(suggestion['name']),
                          subtitle: Text(suggestion['address']),
                        );
                      } else {
                        return ListTile(
                          title: Text(suggestion['name']),
                          subtitle: Text(suggestion['address']),
                        );
                      }
                    },
                    onSelected: (suggestion) async {
                      if (suggestion['isCurrentLocation'] == true) {
                        try {
                          final currentLocation = await getCurrentLocation();
                          final lat = currentLocation['lat'];
                          final lng = currentLocation['lng'];
                          final address =
                              await getAddressFromCoordinates(lat, lng);
                          setState(() {
                            _endController.text = address;
                          });
                        } catch (e) {
                          print("현재 위치 정보를 가져올 수 없습니다: $e");
                        }
                      } else {
                        setState(() {
                          _endController.text = suggestion['address'];
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  // 이동수단 선택 버튼
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildTransportButton('차'),
                      _buildTransportButton('대중교통'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // 경로 검색 버튼
                  ElevatedButton(
                    onPressed: () async {
                      await findRoute();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyan,
                      minimumSize: const Size.fromHeight(50),
                    ),
                    child: const Text("경로 검색"),
                  ),
                ],
              ),
            ),

            // (2) 지도 + 대중교통 리스트
            Expanded(
              child: _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  /// 이동수단 선택 버튼 위젯 (차, 대중교통)
  Widget _buildTransportButton(String label) {
    final bool isSelected = (_selectedTransport == label);
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _selectedTransport = label;
          if (label == '차') {
            _transitPaths = [];
          }
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? AppColors.appBar : Colors.grey[300],
        foregroundColor: isSelected ? Colors.white : Colors.black,
      ),
      child: Text(label),
    );
  }

  Widget _buildContent() {
    if (_selectedTransport == '대중교통' && _transitPaths.isNotEmpty) {
      // 대중교통 모드이면 지도는 안보이고 리스트만 전체 영역을 차지하도록 함
      return Container(
        color: Colors.grey[100],
        child: _buildTransitListView(),
      );
    } else {
      // 차 모드이면 기존 지도 위젯을 표시
      return NaverMap(
        options: NaverMapViewOptions(
          initialCameraPosition: _routeCoords.isNotEmpty
              ? NCameraPosition(target: _routeCoords.first, zoom: 14)
              : const NCameraPosition(
                  target: NLatLng(37.5666102, 126.9783881),
                  zoom: 10,
                ),
        ),
        onMapReady: (controller) async {
          _mapController = controller;
          if (_routeCoords.isNotEmpty) {
            final routePolyline = NPolylineOverlay(
              id: 'routeLine',
              coords: _routeCoords,
              color: Colors.blue,
              width: 5,
              lineCap: NLineCap.round,
              lineJoin: NLineJoin.round,
            );
            await controller.addOverlay(routePolyline);
          }
        },
      );
    }
  }

  /// 한 줄에 구간들을 배치하되, 화면 너비에 맞춰 FittedBox로 축소
  Widget _buildSubPathRowScaled(
      BuildContext context, List<dynamic> subPathList) {
    // 1) 총 소요시간 계산
    int totalTime = 0;
    for (var sp in subPathList) {
      int st = sp["sectionTime"] ?? 0;
      if (st < 1) st = 1; // 0분 보호
      totalTime += st;
    }

    // 2) 화면 너비에서 좌우 여백 32 정도 빼고(상황에 맞게 조정)
    final screenWidth = MediaQuery.of(context).size.width - 32;

    // 3) 구간들을 Row의 children으로 만들기
    List<Widget> segments = [];
    for (int i = 0; i < subPathList.length; i++) {
      final sp = subPathList[i];
      int st = sp["sectionTime"] ?? 0;
      if (st < 1) st = 1;

      // 비율
      double ratio = st / totalTime;
      // 실제 너비
      double segWidth = ratio * screenWidth;

      // 도보 연속 아이콘 표시 여부
      bool showIcon = true;
      if (sp["trafficType"] == 3 && i > 0) {
        // 이전 구간도 도보라면 아이콘 생략
        var prev = subPathList[i - 1];
        if (prev["trafficType"] == 3) {
          showIcon = false;
        }
      }

      segments.add(_buildSegmentBox(sp, segWidth, showIcon));
    }

    // 4) Row를 FittedBox로 감싸기 -> 화면 너비보다 커지면 내부가 축소됨
    return Container(
      // 여기서 width 고정
      width: screenWidth,
      // FittedBox로 축소 허용
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          children: segments,
        ),
      ),
    );
  }

  /// 구간 하나의 SizedBox(너비=segWidth)에 아이콘/텍스트 표시
  Widget _buildSegmentBox(
      Map<String, dynamic> subPath, double segWidth, bool showIcon) {
    int trafficType = subPath["trafficType"] ?? 3;
    int sectionTime = subPath["sectionTime"] ?? 0;
    if (sectionTime < 1) sectionTime = 1;

    // 교통수단별 아이콘/색상
    IconData icon;
    Color color;
    String label;

    if (trafficType == 1) {
      // 지하철
      icon = Icons.directions_subway;
      // 호선
      String lineName = "";
      if (subPath["lane"] is List && (subPath["lane"] as List).isNotEmpty) {
        lineName = (subPath["lane"] as List)[0]["name"] ?? "";
      }
      color = getSubwayLineColor(lineName); // 호선별 색상
      label = "$sectionTime분";
    } else if (trafficType == 2) {
      // 버스
      icon = Icons.directions_bus;
      int? busType;
      if (subPath["lane"] is List && (subPath["lane"] as List).isNotEmpty) {
        busType = (subPath["lane"] as List)[0]["type"] as int?;
      }
      color = getBusTypeColor(busType);
      label = "$sectionTime분";
    } else {
      // 도보
      icon = Icons.directions_walk;
      color = Colors.grey;
      label = "$sectionTime분";
    }

    // 도보 아이콘 표시 여부
    final iconWidget = (trafficType == 3 && !showIcon)
        ? const SizedBox() // 도보 연속 -> 아이콘 없음
        : Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 2),
            ],
          );

    return SizedBox(
      width: segWidth,
      child: Container(
        alignment: Alignment.center,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            children: [
              iconWidget,
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNaverTransitTile(BuildContext context, Map path) {
    final info = path["info"];
    final totalTime = info?["totalTime"] ?? 0;
    final payment = info?["payment"] ?? 0;
    final subPaths = path["subPath"] as List<dynamic>? ?? [];

    // 시작/도착 지점 이름 추출
    String startName = '';
    String endName = '';
    if (subPaths.isNotEmpty) {
      startName = subPaths.first["startName"] ?? '';
      endName = subPaths.last["endName"] ?? '';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 5)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$totalTime분',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              Text('${NumberFormat('#,###').format(payment)}원',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          _buildTransitBar(subPaths),
          const SizedBox(height: 4),
          _buildStationRow(startName, subPaths, endName),
        ],
      ),
    );
  }

  Widget _buildTransitBar(List<dynamic> subPaths) {
    List<Widget> widgets = [];
    for (int i = 0; i < subPaths.length; i++) {
      final sp = subPaths[i];
      int type = sp["trafficType"] ?? 3;
      IconData icon;
      Color color;
      if (type == 1) {
        String lineName = '';
        if (sp["lane"] is List && (sp["lane"] as List).isNotEmpty) {
          lineName = (sp["lane"] as List)[0]["name"] ?? '';
        }
        icon = Icons.directions_subway;
        color = getSubwayLineColor(lineName);
      } else if (type == 2) {
        int? busType;
        if (sp["lane"] is List && (sp["lane"] as List).isNotEmpty) {
          busType = (sp["lane"] as List)[0]["type"] as int?;
        }
        icon = Icons.directions_bus;
        color = getBusTypeColor(busType);
      } else {
        icon = Icons.directions_walk;
        color = Colors.grey;
      }

      widgets.add(Icon(icon, size: 16, color: color));
      if (i != subPaths.length - 1) {
        widgets.add(Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            height: 2,
            color: color.withOpacity(0.6),
          ),
        ));
      }
    }
    return Row(children: widgets);
  }

  Widget _buildStationRow(
      String startName, List<dynamic> subPaths, String endName) {
    List<String> names = [startName];
    for (var sp in subPaths) {
      names.add(sp["endName"] ?? '');
    }
    List<Widget> widgets = [];
    for (int i = 0; i < names.length; i++) {
      widgets.add(Expanded(
        child: Text(
          names[i],
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12),
        ),
      ));
      if (i != names.length - 1) {
        widgets.add(const Icon(Icons.chevron_right, size: 16));
      }
    }
    return Row(children: widgets);
  }

  Widget _buildTransitListView() {
    return ListView.builder(
      itemCount: _transitPaths.length,
      itemBuilder: (context, index) {
        final path = _transitPaths[index];
        return _buildNaverTransitTile(context, path);
      },
    );
  }

  /// 버스/지하철 구간만 골라서 아래쪽에 상세 정보를 표시
  Widget _buildSubPathDetails(List<dynamic> subPathList) {
    // (1) 버스/지하철 구간만 추출
    final filtered = subPathList.where((sp) {
      int type = sp["trafficType"] ?? 3; // 기본 도보
      return type == 1 || type == 2; // 지하철(1) or 버스(2) 만
    }).toList();

    // (2) 만약 버스/지하철 구간이 없다면 빈 컨테이너
    if (filtered.isEmpty) {
      return const SizedBox();
    }

    // (3) 구간마다 정보를 뽑아 Row/Column 으로 구성
    List<Widget> detailWidgets = [];
    for (var sp in filtered) {
      int trafficType = sp["trafficType"] ?? 3;
      int sectionTime = sp["sectionTime"] ?? 0;
      if (sectionTime < 0) sectionTime = 0; // 보호

      if (trafficType == 1) {
        // 지하철
        // lane[0]["name"] => "3호선" 등
        String lineName = "";
        if (sp["lane"] is List && (sp["lane"] as List).isNotEmpty) {
          lineName = (sp["lane"] as List)[0]["name"] ?? "";
        }
        // 역 수, 환승역 수 등도 sp["lane"][0]이나 passStopList에서 구할 수 있음
        // 예) final stationCount = sp["passStopList"]["stations"].length;
        // 예) final stationCount = sp["lane"][0]["stationCount"]; (필드명 확인 필요)

        detailWidgets.add(
          Row(
            children: [
              Icon(Icons.directions_subway,
                  size: 20, color: getSubwayLineColor(lineName)),
              const SizedBox(width: 8),
              Text(
                "$lineName, $sectionTime분 소요",
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        );
      } else if (trafficType == 2) {
        // 버스
        // lane[0]["busNo"] => 버스 번호
        // lane[0]["busLocalBlah"] => 간선/마을/직행 등
        String busNo = "";
        String busTypeLabel = "";
        if (sp["lane"] is List && (sp["lane"] as List).isNotEmpty) {
          final laneObj = (sp["lane"] as List)[0];
          busNo = laneObj["busNo"]?.toString() ?? "";
          // 예) busType : 1=공항, 2=마을, 3=간선, ...
          // ODsay 문서 참고하여 busType 에 따른 라벨
          int? busType = laneObj["type"];
          if (busType == 3) {
            busTypeLabel = "간선";
          } else if (busType == 4) {
            busTypeLabel = "지선";
          } else if (busType == 5) {
            busTypeLabel = "광역";
          } else {
            busTypeLabel = ""; // 기본
          }
        }
        Color busColor = getBusTypeColor(busType);

        detailWidgets.add(
          Row(
            children: [
              Icon(Icons.directions_bus, size: 20, color: busColor),
              const SizedBox(width: 8),
              Text(
                // 예) "간선 36번, 13분 소요"
                "$busTypeLabel $busNo번, $sectionTime분 소요",
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        );
      }
      // 도보는 제외
    }

    // (4) 위젯 리스트를 Column으로 묶어 반환
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: detailWidgets,
    );
  }

  /// 구간 전체를 Row로 구성하여 각 구간의 너비를 소요시간에 비례하도록 Expanded로 감싸는 함수
  Widget _buildSubPathRow(List<dynamic> subPathList) {
    List<Widget> segments = [];
    for (int i = 0; i < subPathList.length; i++) {
      var subPath = subPathList[i];
      bool showIcon = true;
      // 만약 현재 구간이 도보(trafficType==3)이고, 이전 구간도 도보라면 아이콘 표시하지 않음.
      if (subPath["trafficType"] == 3 && i > 0) {
        var prevSubPath = subPathList[i - 1];
        if (prevSubPath["trafficType"] == 3) {
          showIcon = false;
        }
      }
      // 각 구간의 flex 값 (소요시간, 0분은 1로 처리)
      int flexValue = subPath["sectionTime"] ?? 0;
      if (flexValue <= 0) flexValue = 1;
      segments.add(
        Expanded(
          flex: flexValue,
          child: _buildSegmentWidget(subPath, showIcon: showIcon),
        ),
      );
    }
    return Row(children: segments);
  }

  /// 호선별 색상을 리턴하는 함수
  Color getSubwayLineColor(String lineName) {
    // lineName(예: "1호선", "2호선")에 따라 특정 색상을 반환
    if (lineName.contains("1호선")) return const Color(0xFF0032A0);
    if (lineName.contains("2호선")) return const Color(0xFF00B140);
    if (lineName.contains("3호선")) return const Color(0xFFFC4C02);
    if (lineName.contains("4호선")) return const Color(0xFF00A9E0);
    if (lineName.contains("5호선")) return const Color(0xFFA05EB5);
    if (lineName.contains("6호선")) return const Color(0xFFA9431E);
    if (lineName.contains("7호선")) return const Color(0xFF67823A);
    if (lineName.contains("8호선")) return const Color(0xFFE31C79);
    if (lineName.contains("9호선")) return const Color(0xFF8C8279);
    return Colors.grey; // 기본값 (호선 정보가 없을 때 등)
  }

  Color getBusTypeColor(int? type) {
    switch (type) {
      case 1:
        return const Color(0xFF0090D2); // 공항
      case 2:
        return const Color(0xFF33CC33); // 마을
      case 3:
        return const Color(0xFF0072BC); // 간선
      case 4:
        return const Color(0xFF6CBF47); // 지선
      case 5:
        return const Color(0xFFFF0000); // 광역
      case 6:
        return const Color(0xFFFFA200); // 순환
      default:
        return Colors.blueGrey;
    }
  }

  /// (1) subPath 각각을 위젯으로 변환
  /// 구간 하나의 위젯을 반환하는 함수
  /// 구간 하나의 위젯을 반환하는 함수
  /// [showIcon] : true이면 아이콘을 표시, false이면 아이콘 없이 시간만 표시
  Widget _buildSegmentWidget(Map<String, dynamic> subPath,
      {bool showIcon = true}) {
    // 교통수단 타입과 소요시간 추출 (기본값 설정)
    int sectionTime = subPath["sectionTime"] ?? 0;
    // 0분인 경우 최소 flex 1로 처리하여 너비가 아예 0이 되지 않도록 함
    if (sectionTime <= 0) sectionTime = 1;

    int trafficType = subPath["trafficType"] as int? ?? 3;

    IconData icon;
    Color color;
    String label;

    // 교통수단 타입별 아이콘과 라벨 처리
    if (trafficType == 1) {
      // 지하철
      // 지하철인 경우 lane에서 호선 정보를 가져와서 색상 결정
      String lineName = "";
      if (subPath["lane"] is List && (subPath["lane"] as List).isNotEmpty) {
        lineName = (subPath["lane"] as List)[0]["name"] ?? "";
      }
      color = getSubwayLineColor(lineName);
      icon = Icons.directions_subway;
      label = "$sectionTime분";
    } else if (trafficType == 2) {
      // 버스
      int? busType;
      if (subPath["lane"] is List && (subPath["lane"] as List).isNotEmpty) {
        busType = (subPath["lane"] as List)[0]["type"] as int?;
      }
      color = getBusTypeColor(busType);
      icon = Icons.directions_bus;
      label = "$sectionTime분";
    } else {
      // 도보
      color = Colors.grey;
      icon = Icons.directions_walk;
      label = "$sectionTime분";
    }

    return Container(
      // 내부 여백 및 배경색 (색상 투명도 조절)
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 도보의 경우, showIcon가 true일 때만 아이콘 표시
          if (trafficType != 3 || (trafficType == 3 && showIcon))
            Icon(icon, size: 16, color: color),
          if (trafficType != 3 || (trafficType == 3 && showIcon))
            const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// 구간 하나의 아이콘 + "X분" + 색상
  Widget _buildSegment(int trafficType, int sectionTime) {
    IconData icon;
    Color color;
    String label;
    // trafficType: 1=지하철, 2=버스, 3=도보
    switch (trafficType) {
      case 1: // 지하철
        icon = Icons.directions_subway;
        color = getSubwayLineColor('');
        label = "$sectionTime분 지하철";
        break;
      case 2: // 버스
        icon = Icons.directions_bus;
        color = getBusTypeColor(null);
        label = "$sectionTime분 버스";
        break;
      case 3: // 도보
      default:
        icon = Icons.directions_walk;
        color = Colors.grey;
        label = "$sectionTime분 도보";
        break;
    }
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
                fontSize: 14, color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
